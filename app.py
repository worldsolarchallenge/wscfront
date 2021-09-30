import os

import flask

from influxdb_client import InfluxDBClient

app = flask.Flask(__name__)

INFLUX_URL = os.environ.get(
    "INFLUX_URL", "https://eastus-1.azure.cloud2.influxdata.com"
)
INFLUX_ORG = os.environ.get("INFLUX_ORG", "BWSC")
INFLUX_TOKEN = os.environ.get("INFLUX_TOKEN", None)

INFLUX_BUCKET = os.environ.get("INFLUX_BUCKET", "sample")

QUERY_TIME = os.environ.get("QUERY_TIME", "-2d")

if not INFLUX_TOKEN:
    raise ValueError("No InfluxDB token set using INFLUX_TOKEN "
                     "environment variable")

client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN,
                        org=INFLUX_ORG, debug=True)


@app.route("/")
def hello():
    query_api = client.query_api()

    query = f"""
        from(bucket: "{INFLUX_BUCKET}")
            |> range(start: {QUERY_TIME})
            |> filter(fn: (r) => r._measurement == "telemetry"
                                 and (r._field == "distance"
                                 or r._field == "solarEnergy"
                                 or r._field == "batteryEnergy"))
            |> last()
            |> keep(columns: ["shortname", "_field", "_value"])
            |> pivot(rowKey: ["shortname"],
                              columnKey: ["_field"],
                              valueColumn: "_value")
            |> map(fn: (r) => ({{r with consumption:
                              (r.solarEnergy +  r.batteryEnergy)/r.distance}}))
            |> group()
            |> keep(columns: ["shortname", "distance", "consumption"])
            |> sort(columns: ["distance", "consumption", "shortname"])"""

    stream = query_api.query_stream(query)

    return flask.render_template("front.html", rows=stream)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
