import unittest
from unittest.mock import patch, mock_open
from elyrii_ai.prompt import system_prompt


class TestSystemPrompt(unittest.TestCase):

    def test_get_file_from_version_basic(self):
        """Test basic filename generation without subversion."""
        filename = system_prompt.get_file_from_version("json", 1, name="base")
        self.assertEqual(filename, "basev1.json")

    def test_get_file_from_version_with_subversion(self):
        """Test filename generation with subversion."""
        filename = system_prompt.get_file_from_version(
            "json", 1, name="base", subversion=5
        )
        self.assertEqual(filename, "basev1.5.json")

    def test_get_file_from_version_no_name(self):
        """Test filename generation without a name prefix."""
        filename = system_prompt.get_file_from_version("json", 2)
        self.assertEqual(filename, "v2.json")

    @patch("elyrii_ai.prompt.system_prompt.logger")
    def test_get_file_from_version_negative_version(self, mock_logger):
        """Test that negative version returns empty string and logs error."""
        filename = system_prompt.get_file_from_version("json", -1)
        self.assertEqual(filename, "")
        mock_logger.error.assert_called_with("Version can't be negative")

    @patch("elyrii_ai.prompt.system_prompt.json.load")
    @patch("builtins.open", new_callable=mock_open)
    def test_get_system_prompt_success(self, mock_file, mock_json_load):
        """Test successful retrieval of system prompt."""
        # Mock json.load to return a list with a string element for persona and policy
        # First call is persona, second is policy
        mock_json_load.side_effect = [["Persona Content"], ["Policy Content"]]

        result = system_prompt.get_system_prompt(1)

        self.assertEqual(result, "Persona Content Policy Content")

        # Verify files were opened with correct paths (paths depend on get_file_from_version logic)
        # Expected paths: persona/v1.json and policy/v1.json (since default name is empty)
        expected_calls = [
            unittest.mock.call("persona/v1.json"),
            unittest.mock.call("policy/v1.json"),
        ]
        mock_file.assert_has_calls(expected_calls, any_order=False)

    @patch("builtins.open", side_effect=FileNotFoundError("File not found"))
    @patch("elyrii_ai.prompt.system_prompt.logger")
    def test_get_system_prompt_file_error(self, mock_logger, mock_file):
        """Test that RuntimeError is raised when file loading fails."""
        with self.assertRaises(RuntimeError):
            system_prompt.get_system_prompt(1)

        # Verify logging occurred
        self.assertTrue(mock_logger.error.called)


if __name__ == "__main__":
    unittest.main()
