#!/usr/bin/env python3

from flask import Flask, Response, abort, request

import os
import requests

KUBECTL = os.environ["KUBECTL"]
app = Flask(__name__)


def get_app_port(namespace, app):
    if app == "www-origin":
        if namespace == "live":
            app = "fake-router"
        elif namespace == "govuk":
            app = "router"
        else:
            return None

    try:
        r = subprocess.run(
            [KUBECTL, f"--namespace={namespace}", "describe", "service", app],
            stdout=subprocess.PIPE,
        )
        for line in r.stdout.decode("utf-8").splitlines():
            bits = line.split()
            if bits[0] == "NodePort":
                return bits[2].split("/")[0]
    except:
        pass
    return None


@app.route(
    "/", defaults={"path": ""}, methods=["GET", "POST", "DELETE", "PUT", "PATCH"]
)
@app.route("/<path>", methods=["GET", "POST", "DELETE", "PUT", "PATCH"])
def proxy(**kwargs):
    bits = request.host.split(".")
    try:
        app = bits[0]
        namespace = bits[1]
    except:
        abort(400)

    if namespace not in ["live", "govuk"]:
        abort(400)

    port = get_app_port(namespace, app)
    if port is None:
        print(f"failed to find port for app: {namespace}/{app}")
        abort(500)

    resp = requests.request(
        method=request.method,
        url=request.url.replace(request.host_url, f"localhost:{port}"),
        headers=request.headers,
        data=request.get_data(),
        cookies=request.cookies,
        allow_redirects=False,
    )

    excluded_headers = [
        "content-encoding",
        "content-length",
        "transfer-encoding",
        "connection",
    ]
    headers = [
        (name, value)
        for (name, value) in resp.raw.headers.items()
        if name.lower() not in excluded_headers
    ]

    return Response(
        resp.iter_content(chunk_size=10 * 1024),
        resp.status_code,
        headers,
        content_type=resp.headers["Content-Type"],
    )

# sudo iptables -t nat -I OUTPUT -p tcp -d 127.0.0.1 --dport 80 -j REDIRECT --to-ports 9999
if __name__ == "__main__":
    app.run(host="0.0.0.0", port="9999")
