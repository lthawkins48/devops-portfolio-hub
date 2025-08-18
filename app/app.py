from flask import Flask, render_template
import os

app = Flask(__name__)

@app.route("/")
def home():
    config = {
        "github":   os.getenv("PORTFOLIO_GITHUB",   "https://github.com/lthawkins48"),
        "dockerhub":os.getenv("PORTFOLIO_DOCKERHUB","https://hub.docker.com/u/lthawkins48"),
        "linkedin": os.getenv("PORTFOLIO_LINKEDIN", "https://www.linkedin.com/in/YOUR-LINKEDIN/"),
        "title":    os.getenv("PORTFOLIO_TITLE",    "DevOps Portfolio Hub")
    }
    return render_template("index.html", config=config)

if __name__ == "__main__":
    # Flask dev server for container (gunicorn optional later)
    app.run(host="0.0.0.0", port=5000)
