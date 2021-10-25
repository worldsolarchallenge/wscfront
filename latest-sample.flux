from(bucket: "sample")
  |> range(start: -2d)
  |> filter(fn: (r) => r._measurement == "telemetry"
                         and (r._field == "distance" 
                              or r._field == "solarEnergy" 
                              or r._field == "batteryEnergy"))
  |> last()
  |> keep(columns: ["shortname", "_field", "_value"])
  |> pivot(rowKey: ["shortname"], columnKey: ["_field"], valueColumn: "_value")
  |> map(fn: (r) => ({r with consumption: (r.solarEnergy +  r.batteryEnergy)/r.distance}))
  |> group()
  |> keep(columns: ["shortname", "distance", "consumption"])