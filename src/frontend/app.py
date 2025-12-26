import os
import requests
from flask import Flask, jsonify

app = Flask(__name__)

PRODUCT_URL = os.environ.get('PRODUCT_URL', 'http://product:5000/products')

@app.route('/')
def index():
    try:
        r = requests.get(PRODUCT_URL, timeout=2)
        return jsonify({"frontend": "ok", "products": r.json()})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
