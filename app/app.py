from flask import Flask, request
import os
from prometheus_flask_exporter import PrometheusMetrics
metrics = PrometheusMetrics(app)

app = Flask(__name__)

@app.route("/")
def home():
    #get headers sent by nginx
    client_ip = request.headers.get('X-Real-IP','Not set')
    forwarded_for = request.headers.get('Host','Not set')
    host = request.headers.get('Host', 'Not set')

    return f"""
    <h1>Welcome to CICD App!</h1>
    <p>This request is being forwarded through <b>Nginx Reverse Proxy</b>.</p>
    <p><b>Host:</b> {host}</p>
    <p><b>Client IP:</b> {client_ip}</p>
    <p><b>X-Forwarded-For:</b> {forwarded_for}</p>
    <p>Docker container port: 5000</p>
    """

@app.route("/health")
def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

