#!/bin/bash
# Elyrii Full Training Pipeline
# This script runs the data preparation, training, and evaluation steps in sequence.

set -e # Exit immediately if a command exits with a non-zero status

# Add the current directory to PYTHONPATH so that 'elyrii_ai' can be imported
export PYTHONPATH="$(pwd):$PYTHONPATH"

# Default configuration.
#
# Override these on the VM when needed, for example:
#   MODEL_PATH=/mnt/models/mistral_7B_instruct_v0.3 bash elyrii_ai/training/run_pipeline.sh
# If MODEL_PATH is a Hugging Face ID, export HF_TOKEN first for gated models.
MODEL_PATH="${MODEL_PATH:-mistralai/Mistral-7B-Instruct-v0.3}"
DATA_BASE_DIR="${DATA_BASE_DIR:-./datasets}"
PROCESSED_DATA_DIR="${PROCESSED_DATA_DIR:-./data}"
OUTPUT_DIR="${OUTPUT_DIR:-./output}"
EVAL_RESULTS_FILE="${EVAL_RESULTS_FILE:-./evaluation_results.csv}"
EPOCHS="${EPOCHS:-1}"
LR="${LR:-5e-5}"
LORA_ALPHA="${LORA_ALPHA:-4}"
LORA_DROPOUT="${LORA_DROPOUT:-0.10}"
TARGET_PRESET="${TARGET_PRESET:-all-linear}"
BATCH="${BATCH:-1}"
GRAD_ACC="${GRAD_ACC:-16}"

echo "========================================"
echo "🚀 Starting Elyrii Training Pipeline"
echo "========================================"
echo "Model Path: $MODEL_PATH"
echo "Raw Datasets: $DATA_BASE_DIR"
echo "Processed Data: $PROCESSED_DATA_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo "========================================"

# Step 1: Data Preparation
echo ""
echo "==== [1/3] Data Preparation ===="
if [ ! -d "$DATA_BASE_DIR" ]; then
    echo "❌ Error: Raw datasets directory '$DATA_BASE_DIR' not found."
    exit 1
fi

python elyrii_ai/training/prepare_data.py \
    --model_path "$MODEL_PATH" \
    --data_base_dir "$DATA_BASE_DIR" \
    --output_dir "$PROCESSED_DATA_DIR"

if [ ! -d "$PROCESSED_DATA_DIR/train" ]; then
    echo "❌ Error: Data preparation failed to produce training data in $PROCESSED_DATA_DIR/train"
    exit 1
fi
echo "✅ Data preparation successful!"


# Step 2: Model Training
echo ""
echo "==== [2/3] Model Training ===="
# Force setuptools to use the standard library's distutils to avoid Conda/Torch conflicts
export SETUPTOOLS_USE_DISTUTILS=stdlib

python elyrii_ai/training/train.py \
    --data_dir "$PROCESSED_DATA_DIR" \
    --output_dir "$OUTPUT_DIR" \
    --model_id "$MODEL_PATH" \
    --epochs "$EPOCHS" \
    --lr "$LR" \
    --lora_alpha "$LORA_ALPHA" \
    --lora_dropout "$LORA_DROPOUT" \
    --target_preset "$TARGET_PRESET" \
    --batch "$BATCH" \
    --grad_acc "$GRAD_ACC"

ADAPTER_PATH="$OUTPUT_DIR/final_lora"
if [ ! -d "$ADAPTER_PATH" ]; then
    echo "❌ Error: Training failed to produce LoRA adapter in $ADAPTER_PATH"
    exit 1
fi
echo "✅ Model training successful!"


# Step 3: Evaluation
echo ""
echo "==== [3/3] Model Evaluation ===="
echo "Note: If GEMINI_API_KEY is exported, LLM-as-a-Judge will run."
python elyrii_ai/training/evaluate.py \
    --adapter_path "$ADAPTER_PATH" \
    --model_path "$MODEL_PATH" \
    --output_file "$EVAL_RESULTS_FILE"

if [ ! -f "$EVAL_RESULTS_FILE" ]; then
    echo "❌ Error: Evaluation failed to produce results file '$EVAL_RESULTS_FILE'"
    exit 1
fi

echo ""
echo "🎉 Pipeline Completed Successfully!"
echo "💾 Final LoRA Adapter is saved at: $ADAPTER_PATH"
echo "📊 Evaluation results are saved at: $EVAL_RESULTS_FILE"
echo "========================================"
