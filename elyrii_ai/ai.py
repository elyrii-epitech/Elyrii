import requests
from typing import Optional, List, Dict, Generator
import json


class AI:
    """
    AI class using vLLM OpenAI-compatible API for local model inference.
    Supports high-throughput inference with efficient batching.
    """

    def __init__(
            self,
            base_url: str = "http://localhost:8000/v1",
            model: str = "mistralai/Mistral-7B-Instruct-v0.2",
            timeout: int = 300
    ):
        """
        Initialize the AI with vLLM backend.

        Args:
            base_url: vLLM OpenAI-compatible API endpoint
            model: Model name/path (HuggingFace format)
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.timeout = timeout
        self.conversation_history: List[Dict[str, str]] = []

    def send_message(
            self,
            message: str,
            temperature: float = 0.7,
            max_tokens: int = 2048,
            stream: bool = False
    ) -> str:
        """
        Send a message to the AI model.

        Args:
            message: User message
            temperature: Sampling temperature (0.0 to 2.0)
            max_tokens: Maximum tokens to generate
            stream: Whether to stream the response

        Returns:
            AI response as string
        """
        # Add user message to history
        self.conversation_history.append({"role": "user", "content": message})

        url = f"{self.base_url}/chat/completions"
        payload = {
            "model": self.model,
            "messages": self.conversation_history,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream
        }

        try:
            if stream:
                return self._stream_response(url, payload)
            else:
                response = requests.post(url, json=payload, timeout=self.timeout)
                response.raise_for_status()

                result = response.json()
                assistant_message = result["choices"][0]["message"]["content"]

                # Add assistant response to history
                self.conversation_history.append({
                    "role": "assistant",
                    "content": assistant_message
                })

                return assistant_message

        except requests.exceptions.RequestException as e:
            error_msg = f"Error communicating with AI model: {str(e)}"
            print(error_msg)
            return error_msg

    def _stream_response(self, url: str, payload: dict) -> Generator[str, None, None]:
        """
        Stream response from vLLM.

        Args:
            url: API endpoint
            payload: Request payload

        Yields:
            Chunks of the response
        """
        full_response = ""

        try:
            with requests.post(url, json=payload, stream=True, timeout=self.timeout) as response:
                response.raise_for_status()

                for line in response.iter_lines():
                    if line:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            data = line[6:]  # Remove 'data: ' prefix
                            if data == '[DONE]':
                                break

                            try:
                                chunk = json.loads(data)
                                delta = chunk["choices"][0]["delta"].get("content", "")
                                if delta:
                                    full_response += delta
                                    yield delta
                            except json.JSONDecodeError:
                                continue

            # Add complete response to history
            if full_response:
                self.conversation_history.append({
                    "role": "assistant",
                    "content": full_response
                })

        except requests.exceptions.RequestException as e:
            yield f"Error streaming response: {str(e)}"

    def generate_completion(
            self,
            prompt: str,
            temperature: float = 0.7,
            max_tokens: int = 2048,
            top_p: float = 0.95,
            frequency_penalty: float = 0.0,
            presence_penalty: float = 0.0
    ) -> str:
        """
        Generate a completion without conversation history (useful for one-off prompts).

        Args:
            prompt: The prompt text
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate
            top_p: Nucleus sampling parameter
            frequency_penalty: Frequency penalty
            presence_penalty: Presence penalty

        Returns:
            Generated text
        """
        url = f"{self.base_url}/completions"
        payload = {
            "model": self.model,
            "prompt": prompt,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "top_p": top_p,
            "frequency_penalty": frequency_penalty,
            "presence_penalty": presence_penalty
        }

        try:
            response = requests.post(url, json=payload, timeout=self.timeout)
            response.raise_for_status()

            result = response.json()
            return result["choices"][0]["text"]

        except requests.exceptions.RequestException as e:
            return f"Error generating completion: {str(e)}"

    def reset_conversation(self):
        """Clear conversation history."""
        self.conversation_history = []

    def get_models(self) -> List[str]:
        """Get list of available models."""
        try:
            response = requests.get(f"{self.base_url}/models", timeout=10)
            response.raise_for_status()
            result = response.json()
            return [model["id"] for model in result.get("data", [])]
        except:
            return []

    def check_health(self) -> bool:
        """Check if vLLM service is available."""
        try:
            response = requests.get(f"{self.base_url}/models", timeout=5)
            return response.status_code == 200
        except:
            return False
