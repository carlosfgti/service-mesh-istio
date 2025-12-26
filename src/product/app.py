from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/products')
def products():
    return jsonify([
        {"id": 1, "name": "Widget"},
        {"id": 2, "name": "Gadget"}
    ])

@app.route('/')
def root():
    return jsonify({"service":"product","status":"ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
