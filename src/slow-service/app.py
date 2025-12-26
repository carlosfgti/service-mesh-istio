from flask import Flask, jsonify
import time
import random
import os

app = Flask(__name__)

# Configurações
SLOW_RATE = float(os.getenv('SLOW_RATE', '0.5'))  # 50% de requests lentas
SLOW_DURATION = int(os.getenv('SLOW_DURATION', '5'))  # 5 segundos de delay
ERROR_RATE = float(os.getenv('ERROR_RATE', '0.2'))  # 20% de erros

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/api/data')
def get_data():
    # Simula erros aleatórios
    if random.random() < ERROR_RATE:
        return jsonify({"error": "Internal server error"}), 503
    
    # Simula lentidão aleatória
    if random.random() < SLOW_RATE:
        time.sleep(SLOW_DURATION)
    
    return jsonify({
        "message": "Success",
        "data": [
            {"id": 1, "name": "Item 1"},
            {"id": 2, "name": "Item 2"},
            {"id": 3, "name": "Item 3"}
        ]
    }), 200

@app.route('/api/fast')
def fast_endpoint():
    return jsonify({"message": "Fast response"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
