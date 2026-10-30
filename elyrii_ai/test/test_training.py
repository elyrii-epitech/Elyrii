"""Offline regressions and a small CPU LoRA training smoke test.

Run from the repository root with the training dependencies installed:
    python -m unittest elyrii_ai.test.test_training -v

Uses the local elyrii_lora tokenizer (override with ELYRII_TEST_TOKENIZER).
No base-model weights are downloaded or production adapters modified.
"""

import math
import os
import tempfile
import unittest
from pathlib import Path

import torch
from datasets import Dataset
from peft import LoraConfig, get_peft_model, get_peft_model_state_dict
from safetensors.torch import load_file
from transformers import (
    AutoTokenizer, MistralConfig, MistralForCausalLM,
    Trainer, TrainerCallback, TrainingArguments, set_seed,
)

from elyrii_ai.training.prepare_data import tokenize_function
from elyrii_ai.training.train import AssistantOnlyDataCollator, LORA_TARGET_PRESETS


class TrainingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(os.getenv("ELYRII_TEST_TOKENIZER", "elyrii_lora"))
        if not (path / "tokenizer_config.json").exists():
            raise unittest.SkipTest("Set ELYRII_TEST_TOKENIZER to a local Mistral tokenizer")
        cls.tokenizer = AutoTokenizer.from_pretrained(
            path, use_fast=False, local_files_only=True,
        )
        cls.tokenizer.pad_token = cls.tokenizer.eos_token

    def setUp(self):
        self.tokenizer.padding_side = "right"
        self.collator = AssistantOnlyDataCollator(self.tokenizer)

    def feature(self, messages):
        text = self.tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=False,
        )
        batch = tokenize_function({"text": [text]}, self.tokenizer)
        return {key: value[0] for key, value in batch.items()}

    def conversation(self, answer="Hi there."):
        return self.feature([
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": answer},
        ])

    def test_single_turn_and_no_duplicate_bos(self):
        feature = self.conversation()
        self.assertEqual(feature["input_ids"][0], self.tokenizer.bos_token_id)
        self.assertNotEqual(feature["input_ids"][1], self.tokenizer.bos_token_id)
        labels = self.collator([feature])["labels"][0]
        self.assertEqual(
            self.tokenizer.decode(labels[labels != -100]), "Hi there.</s>",
        )

    def test_multiturn_masks_users_and_keeps_both_answers(self):
        feature = self.feature([
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there."},
            {"role": "user", "content": "How are you?"},
            {"role": "assistant", "content": "I am here to listen."},
        ])
        labels = self.collator([feature])["labels"][0]
        self.assertEqual(
            self.tokenizer.decode(labels[labels != -100]),
            "Hi there.</s> I am here to listen.</s>",
        )

    def test_padding_is_masked_but_real_eos_is_supervised(self):
        for side in ("left", "right"):
            with self.subTest(side=side):
                self.tokenizer.padding_side = side
                batch = self.collator([
                    self.conversation(),
                    self.conversation("Tell me more about how you feel today."),
                ])
                self.assertTrue(torch.all(batch["labels"][batch["attention_mask"] == 0] == -100))
                for labels in batch["labels"]:
                    self.assertEqual(int(labels[labels != -100][-1]), self.tokenizer.eos_token_id)

    def test_user_only_is_rejected_even_in_mixed_batch(self):
        prompt = self.feature([{"role": "user", "content": "Hello"}])
        with self.assertRaisesRegex(ValueError, "no supervised tokens"):
            self.collator([self.conversation(), prompt])

    def test_truncated_answer_is_rejected(self):
        feature = self.conversation()
        marker = self.tokenizer.convert_tokens_to_ids("[/INST]")
        end = feature["input_ids"].index(marker) + 1
        with self.assertRaisesRegex(ValueError, "no supervised tokens"):
            self.collator([{key: value[:end] for key, value in feature.items()}])

    def test_missing_marker_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "no supervised tokens"):
            self.collator([{"input_ids": [1, 42, 2], "attention_mask": [1, 1, 1]}])

    def test_cpu_lora_training_updates_and_save(self):
        set_seed(42)
        # Small random model, real Mistral tokenizer and production collator.
        model = MistralForCausalLM(MistralConfig(
            vocab_size=len(self.tokenizer), hidden_size=32, intermediate_size=64,
            num_hidden_layers=1, num_attention_heads=4, num_key_value_heads=2,
            max_position_embeddings=256, use_cache=False,
            attn_implementation="eager",
        ))
        model = get_peft_model(model, LoraConfig(
            r=16, lora_alpha=4, lora_dropout=0.10,
            target_modules=LORA_TARGET_PRESETS["all-linear"],
            bias="none", task_type="CAUSAL_LM",
        ))
        before = {k: v.detach().clone() for k, v in get_peft_model_state_dict(model).items()}
        self.assertTrue(all(torch.count_nonzero(v) == 0 for k, v in before.items() if "lora_B" in k))
        examples = [self.conversation(), self.conversation("I am here to listen.")]
        batch = self.collator(examples)
        model.eval()
        with torch.no_grad():
            initial_loss = model(**batch).loss.item()
        self.assertTrue(math.isfinite(initial_loss))

        gradient_norms = []

        class CheckGradients(TrainerCallback):
            def on_pre_optimizer_step(callback_self, args, state, control, **kwargs):
                gradients = [p.grad for p in kwargs["model"].parameters() if p.requires_grad and p.grad is not None]
                if not gradients or not all(torch.isfinite(g).all() for g in gradients):
                    raise AssertionError("Missing or nonfinite adapter gradients")
                norm = sum(g.float().square().sum().item() for g in gradients) ** 0.5
                if norm == 0:
                    raise AssertionError("All adapter gradients are zero")
                gradient_norms.append(norm)

        with tempfile.TemporaryDirectory(prefix="elyrii-training-smoke-", dir="/mnt/workspace/tmp") as output:
            trainer = Trainer(
                model=model,
                args=TrainingArguments(
                    output_dir=output, use_cpu=True, max_steps=5,
                    per_device_train_batch_size=2, learning_rate=5e-5,
                    max_grad_norm=0.3, lr_scheduler_type="cosine", warmup_ratio=0.03,
                    logging_steps=1, logging_nan_inf_filter=False,
                    save_strategy="no", report_to="none", disable_tqdm=True,
                ),
                train_dataset=Dataset.from_list(examples),
                data_collator=self.collator, callbacks=[CheckGradients()],
            )
            result = trainer.train()
            self.assertTrue(math.isfinite(result.training_loss))
            losses = [row["loss"] for row in trainer.state.log_history if "loss" in row]
            self.assertEqual(len(losses), 5)
            self.assertTrue(all(math.isfinite(loss) for loss in losses))
            self.assertEqual(len(gradient_norms), 5)
            model.eval()
            with torch.no_grad():
                final_loss = model(**batch).loss.item()
            self.assertTrue(math.isfinite(final_loss))
            trainer.save_model(output)
            saved = load_file(str(Path(output) / "adapter_model.safetensors"))
            changed = [key for key in before if not torch.equal(before[key], saved[key])]
            b_keys = [key for key in saved if "lora_B" in key]
            self.assertTrue(changed)
            self.assertTrue(all(torch.count_nonzero(saved[key]) > 0 for key in b_keys))
            self.assertTrue(all(torch.isfinite(value).all() for value in saved.values()))
            print(f"SMOKE: initial_loss={initial_loss:.6f}, final_loss={final_loss:.6f}, "
                  f"finite_steps={len(losses)}, changed_tensors={len(changed)}/{len(before)}, "
                  f"nonzero_B={len(b_keys)}/{len(b_keys)}")


if __name__ == "__main__":
    unittest.main()
