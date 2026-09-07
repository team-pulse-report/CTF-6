"""Minimal JWT-authenticated API for the CTF web tier.

The authentication is deliberately weak: tokens are HS256 and the signing key is
a single dictionary word. A low-privilege token is handed out to the demo
account, and the admin area trusts the "role" claim without any server-side
session state. Cracking the key offline and forging an admin token is the
intended first step.
"""

import os

import jwt
from flask import Flask, jsonify, request, send_from_directory

# The signing key is a common dictionary word. Rotating it to a high-entropy
# value is the fix; leaving it here is the vulnerability the challenge exercises.
JWT_SECRET = "trustno1"
JWT_ALG = "HS256"

FLAG_PATH = "/flags/admin.txt"
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

# The one interactive account exposed to the public. Its token carries the
# non-privileged "user" role.
DEMO_ACCOUNTS = {"guest": "guest"}

# Password store surfaced by the admin console. Hashes are unsalted MD5, which
# is the second weakness: mallory's hash reverses to her real SSH password. This
# MD5 MUST stay in sync with the chpasswd value in app.Dockerfile; it is the MD5
# of mallory's SSH password.
USER_RECORDS = [
    {
        "username": "mallory",
        "hash": "15cf0ae3726fdf8505b199e968106d68",
        "algo": "md5",
        "note": "legacy operator account, unsalted import from the old panel",
    },
    {
        "username": "admin",
        "hash": "0ba39df27e5d9d51fda824234838d0f1",
        "algo": "md5",
        "note": "key rotated after the last audit",
    },
]

app = Flask(__name__, static_folder=None)


def read_flag():
    try:
        with open(FLAG_PATH, "r", encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return "FLAG{unavailable}"


def bearer_token():
    header = request.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        return header[len("Bearer "):].strip()
    return request.args.get("token", "").strip()


def decode_token(token):
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])


@app.get("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")


@app.post("/api/login")
def login():
    payload = request.get_json(silent=True) or request.form
    username = (payload.get("username") or "").strip()
    password = (payload.get("password") or "").strip()

    if DEMO_ACCOUNTS.get(username) == password:
        token = jwt.encode(
            {"sub": username, "role": "user"}, JWT_SECRET, algorithm=JWT_ALG
        )
        return jsonify({"token": token, "role": "user"})

    return jsonify({"error": "invalid credentials"}), 401


@app.get("/api/whoami")
def whoami():
    token = bearer_token()
    if not token:
        return jsonify({"error": "missing token"}), 401
    try:
        claims = decode_token(token)
    except jwt.InvalidTokenError:
        return jsonify({"error": "invalid token"}), 401
    return jsonify({"claims": claims})


@app.get("/api/admin")
def admin():
    token = bearer_token()
    if not token:
        return jsonify({"error": "missing token"}), 401
    try:
        claims = decode_token(token)
    except jwt.InvalidTokenError:
        return jsonify({"error": "invalid token"}), 401

    if claims.get("role") != "admin":
        return jsonify({"error": "admin role required"}), 403

    return jsonify(
        {
            "flag": read_flag(),
            "message": "admin console: user password store",
            "hint": "hashes are unsalted MD5, reverse them at crackstation.net",
            "users": USER_RECORDS,
        }
    )


@app.get("/api/health")
def health():
    return jsonify({"status": "ok", "alg": JWT_ALG})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
