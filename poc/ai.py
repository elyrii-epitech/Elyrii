from http.client import responses

from mistralai import Mistral
from emotion import EmotionDetector


class AI:
    def __init__(self, api_key):
        self.detector = EmotionDetector()
        self.client = Mistral(api_key=api_key)
        self.model = "mistral-small-latest"

    def set_context(self):
        response = self.client.chat.complete(
            model=self.model,
            messages=[{"role": "user", "content": "Dans le cadre de cet échange, tu es un assistant émotionel, agis de façon à apporter un soutien au question"}],
        )
        return response.choices[0].message.content

    def send_message(self, message):
        response = self.client.chat.complete(
            model=self.model,
            messages=[{"role": "user", "content": message}],
        )
        return response.choices[0].message.content
