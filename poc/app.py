from flask import Flask, request, jsonify, render_template
from ai import AI
from dotenv import load_dotenv
import os
app = Flask(__name__)

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/elyrii', methods=['POST'])
def elyrii():
    try:
        data = request.get_json()
        message = data.get('message', '')

        if not message:
            return jsonify({'error': 'Message content is required'}), 400

        reply = ai.send_message(message)

        return jsonify({'reply': reply}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500



if __name__ == '__main__':
    load_dotenv()
    ai = AI(os.getenv("API_KEY"))
    ai.set_context()
    app.run(host='0.0.0.0', port=5000)
