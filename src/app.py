import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def index():
    return jsonify(
        app="cloudfin-demo",
        env=os.getenv("APP_ENV", "local"),
        version=os.getenv("APP_VERSION", "dev"),
    )

@app.get("/health")
def health():
    return {"status": "ok"}
