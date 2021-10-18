import os

import flask
import flask_caching
from flask.helpers import send_file

import subprocess

app = flask.Flask(__name__)

config = {
    "DEBUG": True,          # some Flask specific configs
    "CACHE_TYPE": "SimpleCache",  # Flask-Caching related configs
    "CACHE_DEFAULT_TIMEOUT": 300
}
app.config.from_mapping(config)
cache = flask_caching.Cache(app)

INFLUX_HOST = os.environ.get(
    "INFLUX_HOST", "https://eastus-1.azure.cloud2.influxdata.com"
)
INFLUX_ORG = os.environ.get("INFLUX_ORG", "BWSC")
INFLUX_TOKEN = os.environ.get("INFLUX_TOKEN", None)

#INFLUX_BUCKET = os.environ.get("INFLUX_BUCKET", "sample")

if not INFLUX_TOKEN:
    raise ValueError("No InfluxDB token set using INFLUX_TOKEN "
                     "environment variable")

if not INFLUX_HOST:
    raise ValueError("No InfluxDB host set using INFLUX_HOST "
                     "environment variable")

if not INFLUX_ORG:
    raise ValueError("No InfluxDB org set using INFLUX_ORG "
                     "environment variable")

@app.route("/")
def root():
    return app.send_static_file('front.html')

@cache.cached(timeout=60, key_prefix="run_front")
def run_front():
    # Run "Front" here. 
    return subprocess.call(['Front'])

@app.route('/front.svg')
@app.route('/front_graph.svg')
@app.route('/cars.kml')
def myfiles():
    run_front()

    print(f"Sending {flask.request.path}")
    if flask.request.path.endswith(".svg"):
        return flask.send_file(f"results/{flask.request.path}", mimetype='image/svg+xml')
    elif flask.request.path.endswith(".kml"):
        return flask.send_file(f"results/{flask.request.path}", mimetype="application/vnd.google-earth.kml+xml")

    raise ValueError("Un-routed file detected.")

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
