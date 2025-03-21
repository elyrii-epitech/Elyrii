from mistralai import Mistral
from emotion import EmotionDetector


class AI:
    def __init__(self, api_key):
        self.detector = EmotionDetector()
        self.client = Mistral(api_key=api_key)
        self.model = "mistral-small-latest"

    def send_message(self, message):
        response = self.client.chat.complete(
            model=self.model,
            messages=[{"role": "user", "content": message}],
        )
        return response.choices[0].message.content
