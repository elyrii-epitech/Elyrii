from flask import Flask, request, jsonify, render_template

app = Flask(__name__)

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/elyrii', methods=['POST'])
def elyrii():
    data = request.get_json()
    if not data or 'message' not in data:
        return jsonify({'error': 'Aucun message fourni'}), 400

    message = data['message']
    response = f"Vous avez envoyé : {message}"
    
    return jsonify({'response': response}), 200

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
