"""Tiny App Store Connect API client (key R8FBS6AHU4, App Manager role).

Needs PyJWT + cryptography + requests (e.g. a venv). The private key is read
from ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 and never printed.
    import asc; asc.get('/v1/apps/6824252110')
"""
import os, sys, time
import jwt, requests

KEY_ID = os.environ.get("ASC_KEY_ID", "R8FBS6AHU4")
ISSUER = os.environ.get("ASC_ISSUER_ID", "174378ae-c14b-45e2-a860-e56724989612")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
BASE = "https://api.appstoreconnect.apple.com"
APP_ID = "6824252110"   # Pasal Sort
_tok = None


def token():
    global _tok
    if _tok and _tok[1] > time.time() + 60:
        return _tok[0]
    with open(KEY_PATH) as f:
        key = f.read()
    exp = int(time.time()) + 1100
    _tok = (jwt.encode({"iss": ISSUER, "exp": exp, "aud": "appstoreconnect-v1"}, key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"}), exp)
    return _tok[0]


def req(method, path, body=None, params=None):
    url = path if path.startswith("http") else BASE + path
    r = requests.request(method, url, headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"}, json=body, params=params, timeout=60)
    if r.status_code >= 400:
        print("HTTP", r.status_code, method, path, r.text[:1500], file=sys.stderr)
        r.raise_for_status()
    return r.json() if r.text else {}


def get(p, **k):
    return req("GET", p, params=k or None)


def post(p, b):
    return req("POST", p, b)


def patch(p, b):
    return req("PATCH", p, b)
