import logging
import os
import sys

from flask import Flask, jsonify

# Configure logging
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Validate SECRET_KEY is set and not the insecure default
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    logger.error("SECRET_KEY environment variable is not set. Exiting.")
    sys.exit(1)
if SECRET_KEY == "supersecret123":
    logger.warning("SECRET_KEY is set to the insecure default value. Please change it.")

@app.route('/')
def home():
    logger.info("GET / called")
    return jsonify({"status": "ok", "service": "service-a", "message": "Hello from Service A!"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/data')
def data():
    logger.info("GET /data called")
    return jsonify({"records": [1, 2, 3, 4, 5], "source": "service-a"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
