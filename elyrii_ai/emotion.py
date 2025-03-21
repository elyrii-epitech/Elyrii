from transformers import pipeline


class EmotionDetector:
    def __init__(self):
        self.emotion_model = pipeline("text-classification", model="j-hartmann/emotion-english-distilroberta-base")

    def detect_emotion_and_respond(self, text):
        emotion = self.emotion_model(text)[0]['label']
        return emotion
