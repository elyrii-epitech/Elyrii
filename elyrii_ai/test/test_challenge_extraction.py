import unittest

from elyrii_ai.challenge_extraction import (
    extract_challenge_payload,
    strip_challenge_blocks,
)


class TestChallengeExtraction(unittest.TestCase):
    def test_regex_extraction(self):
        ai_response = "I've noticed you've been feeling a bit overwhelmed lately. How about we try a small challenge to help you stay mindful?\n\n<challenge>\n{\n  \"title\": \"Mindful Moments\",\n  \"description\": \"Log your mood 3 times this week to build mindfulness.\",\n  \"conditions\": [\n    { \"type\": \"mood_count\", \"target\": 3, \"period\": \"week\" }\n  ],\n  \"aggregator\": \"ALL\"\n}\n</challenge>\n\nLet me know what you think!"

        challenge_data = extract_challenge_payload(ai_response)
        self.assertIsNotNone(challenge_data)

        self.assertEqual(challenge_data["title"], "Mindful Moments")
        self.assertEqual(len(challenge_data["conditions"]), 1)
        self.assertEqual(challenge_data["conditions"][0]["type"], "mood_count")

        clean_response = strip_challenge_blocks(ai_response)
        self.assertNotIn("<challenge>", clean_response)
        self.assertNotIn("Mindful Moments", clean_response)
        self.assertIn("Let me know what you think!", clean_response)
        self.assertIn("overwhelmed lately", clean_response)

    def test_regex_multiple_lines(self):
        ai_response = "Here is a challenge:\n<challenge>{\"title\": \"Test\"}</challenge>\nHope you like it."
        challenge_data = extract_challenge_payload(ai_response)
        self.assertIsNotNone(challenge_data)
        self.assertEqual(challenge_data["title"], "Test")

        clean = strip_challenge_blocks(ai_response)
        self.assertEqual(clean, "Here is a challenge:\n\nHope you like it.")

    def test_invalid_challenge_is_ignored(self):
        self.assertIsNone(extract_challenge_payload("<challenge>[]</challenge>"))
        self.assertIsNone(extract_challenge_payload("<challenge>{}</challenge>"))
        self.assertIsNone(extract_challenge_payload("<challenge>{nope}</challenge>"))


if __name__ == "__main__":
    unittest.main()
