from flask import Flask, abort, redirect

import os
import requests

FAKE_ROUTER_HTTPS = os.getenv("FAKE_ROUTER_HTTPS", default="false") == "true"
FAKE_ROUTER_DOMAIN = os.environ["FAKE_ROUTER_DOMAIN"]
PLEK_SERVICE_CONTENT_STORE_URI = os.getenv(
    "PLEK_SERVICE_CONTENT_STORE_URI", default="https://www.gov.uk/api"
)

app = Flask(__name__)


def url_for(rendering_app, path):
    protocol = "https" if FAKE_ROUTER_HTTPS else "http"
    return f"{protocol}://{rendering_app}.{FAKE_ROUTER_DOMAIN}/{path}"


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def redirect_to_backend(path):
    r = requests.get(f"{PLEK_SERVICE_CONTENT_STORE_URI}/content/{path}")
    if r.status_code == 404:
        abort(404)
    try:
        rendering_app = r.json()["rendering_app"]
        return redirect(url_for(rendering_app, path))
    except:
        abort(500)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port="3000")
