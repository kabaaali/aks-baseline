from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello from the Legacy App! I am running as root!"

if __name__ == "__main__":
    # BAD PRACTICE: Hardcoded port and debug mode enabled
    app.run(host="0.0.0.0", port=5000, debug=True)
