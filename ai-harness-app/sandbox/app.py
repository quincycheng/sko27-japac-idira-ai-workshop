"""A tiny web handler. (Planted demo file -- intentionally vulnerable.)"""

import os
import subprocess

from flask import Flask, request

from config import DEBUG

app = Flask(__name__)


@app.route("/ping")
def ping():
    host = request.args.get("host", "localhost")
    # FINDING BAIT: command injection -- user input into a shell string.
    return subprocess.check_output(f"ping -c 1 {host}", shell=True)


@app.route("/calc")
def calc():
    expr = request.args.get("expr", "0")
    # FINDING BAIT: eval on untrusted input -> remote code execution.
    return str(eval(expr))


@app.route("/read")
def read():
    name = request.args.get("name", "")
    # FINDING BAIT: path traversal -- no sanitization of the filename.
    with open(os.path.join("/var/data", name)) as f:
        return f.read()


if __name__ == "__main__":
    # FINDING BAIT: debug server bound to all interfaces.
    app.run(host="0.0.0.0", debug=DEBUG)
