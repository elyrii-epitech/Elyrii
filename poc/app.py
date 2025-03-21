from flask import Flask, request, jsonify, render_template
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

journal_entries = []

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

@app.route('/journal', methods=['GET', 'POST'])
def journal():
    if request.method == 'POST':
        data = request.get_json()
        if not data or 'content' not in data:
            return jsonify({'error': 'Aucun contenu fourni'}), 400
        content = data['content']
        journal_entries.append(content)
        return jsonify({'message': 'Entrée ajoutée avec succès'}), 201
    else:
        return jsonify({'journal': journal_entries}), 200

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
