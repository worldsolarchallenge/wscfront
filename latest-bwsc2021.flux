from(bucket: "bwsc2021")
  |> range(start: 2021-10-26T09:00:00+10:30)
  |> filter(fn: (r) => r._measurement == "telemetry"
                         and (r._field == "distance" 
                              or r._field == "solarEnergy" 
                              or r._field == "batteryEnergy"))
  |> drop(columns: ["_measurement", "_start", "_stop", "car", "team", "class", "event"])
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> elapsed()
  |> duplicate(column: "distance", as: "dx")
  |> difference(columns: ["dx"])
  |> map(fn: (r) => ({r with drivingElapsed: if r.dx > 3*r.elapsed then r.elapsed else 0}))
  |> cumulativeSum(columns: ["drivingElapsed"])
  |> last(column: "shortname")
  |> map(fn: (r) => ({r with consumption: (r.solarEnergy +  r.batteryEnergy)/r.distance}))
  |> map(fn: (r) => ({r with drivingSpeed: r.distance/float(v: r.drivingElapsed)}))
  |> keep(columns: ["shortname", "distance", "drivingSpeed", "consumption"])
  