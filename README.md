# Front

This [Haskell](https://www.haskell.org) script fetchs the latest car positions from an Influx database and produces:

* a scatter plot `front.svg` showing distance and consumption for each of the cars
* a graph `front_graph.svg` showing which cars are dominated by which other cars
* a KML map showing car distances as distances from Adelaide along the Stuart Highway.

Change the query script `latest.flux` to change which data bucket is used.
