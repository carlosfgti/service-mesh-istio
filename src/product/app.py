import os
import random
from flask import Flask, jsonify

app = Flask(__name__)

# Simula falhas aleatórias (30% de chance de erro 500)
FAILURE_RATE = float(os.environ.get('FAILURE_RATE', '0.3'))

@app.route('/flaky')
def flaky():
    if random.random() < FAILURE_RATE:
        return jsonify({"error": "Service temporarily unavailable"}), 500
    return jsonify({"status": "ok", "message": "Request succeeded"})

@app.route('/products')
def products():
    # Pode falhar aleatoriamente
    if random.random() < FAILURE_RATE:
        return jsonify({"error": "Database connection failed"}), 503
    
    return jsonify([
        {"id": 1, "name": "Widget"},
        {"id": 2, "name": "Gadget"}
    ])

@app.route('/')
def root():
    return jsonify({"service": "product", "status": "ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
