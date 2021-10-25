module Main where

import Data.Functor
import Data.List
import Data.List.Split
import Data.Ord
import System.Process
import Text.Printf
import Text.XML.Light


type Distance    = Double 
type Longitude   = Double
type Latitude    = Double
type Consumption = Double

data Car
  = Car {
      name        :: String,
      distance    :: Distance,
      longitude   :: Longitude,
      latitude    :: Latitude,
      consumption :: Consumption }
    deriving Show


{- 

Car data is read from the Influx Cloud database using the influx CLI. 

-}

getCars :: IO [Car]
getCars
  = readCreateProcess (shell "influx query -f latest-$INFLUX_BUCKET.flux --raw") ""
      <&> map (readCar . filter ('\r' /=)) . init . drop 4 . lines


{- 

Columns are comma separated. 

  ,result,table,consumption,distance,shortname

-}

readCar :: String -> Car
readCar s
  = Car name (read sx) 0 0 (read sc)
  where
    [sc, sx, name] = take 3 . drop 3 . splitOn "," $ s

showCar :: Car -> String
showCar (Car name x long lat c)
  = printf "%s\t%0.1f\t%0.6f\t%0.6f\t%0.1f" name (x/1000) long lat c


{- Pareto front -}

dominates :: Car -> Car -> Bool
c1 `dominates` c2
  = and (zipWith (>=) v1s v2s) && or (zipWith (>) v1s v2s)
    where
    v1s = [distance c1, -consumption c1]
    v2s = [distance c2, -consumption c2]

showDominationLinks :: [Car] -> String
showDominationLinks cars
  = intercalate "\n\n" . map showLink $ [(c1, c2) | c1 <- cars, c2 <- cars, c1 `dominates` c2]
  where
    showLink (c1, c2) = printf "%0.1f\t%0.1f\n%0.1f\t%0.1f" 
                          (distance c1/1000) (consumption c1)
                          (distance c2/1000) (consumption c2)


createDominationGraph :: [Car] -> IO ()
createDominationGraph cars
  = do 
      writeFile "results/front_graph.dot" . unlines $ [
        "digraph {",
        "node [shape=none, fontname=\"helvetica\", fontsize=\"10pt\"]",
        "edge [color=grey]",
        unlines . map (show . name) $ cars,
        intercalate "\n" [show (name c1) ++ " -> " ++ show (name c2)
          | c1 <- cars, c2 <- cars, c1 `dominates` c2],
        "}"]
      procHandle <- runCommand "dot results/front_graph.dot -Tsvg -o results/front_graph.svg"
      waitForProcess(procHandle)
      return ()

{- 
The score for car C is w - l, where w is the number of cars that car C dominates, and l is the number of cars that dominate C.
-}

carScores :: [Car] -> [(Int, Car)]
carScores cars
  = sortOn (Down . fst) $ [(score c, c) | c <- cars]
  where
    score c0 =   length [c | c <- cars, c0 `dominates` c] 
               - length [c | c <- cars, c `dominates` c0]

showScore :: (Int, Car) -> String
showScore (n, car)
  = printf "%d\t%s" n (name car)


{- Google Earth 

We create a KML file that shows car positions as distance from Adelaide along the Stuart Highway.

We get longitude and latitude from the route data.

-}

type Altitude  = Double

data Waypoint
  = Waypoint {
      wpDistance  :: Distance,
      wpLongitude :: Longitude,
      wpLatitude  :: Latitude,
      wpAltitude  :: Altitude }
    deriving Show

getRoute :: IO [Waypoint]
getRoute 
  = map readWaypoint . drop 1 . lines <$> readFile "WSC_route.tsv"

readWaypoint :: String -> Waypoint
readWaypoint s
  = Waypoint (1000*read sx) (read slong) (read slat) (read salt)
  where
    [sx, slong, slat, salt] = take 4 . splitOn "\t" $ s

routeCoord :: [Waypoint] -> Distance -> (Longitude, Latitude)
routeCoord [] x = error "routeRecord: no waypoints"
routeCoord [Waypoint x0 long0 lat0 alt0] x = (long0, lat0)
routeCoord (Waypoint x0 long0 lat0 alt0 : Waypoint x1 long1 lat1 alt1 : wps) x
  | x < x0    = (long0, lat0)
  | x <= x1   = (long0 + u*(long1 - long0), lat0 + u*(lat1 - lat0))
  | otherwise = routeCoord (Waypoint x1 long1 lat1 alt1 : wps) x
    where
    u = (x - x0)/(x1 - x0)


addLongLat :: [Waypoint] -> Car -> Car
addLongLat wps (Car name x _ _ c)
  = Car name x long lat c
  where
    (long, lat) = routeCoord wps (3020000 - x)
  

createMap :: [Car] -> IO ()
createMap cars
  = writeFile "results/cars.kml" 
      . ppTopElement 
      $ unode "kml" ([Attr (unqual "xmlnls") "http://www.opengis.net/kml/2.2"], [
          unode "Folder" (
            unode "name" ("BWSC 2021" :: String) :
            unode "Style" ([Attr (unqual "id") "car"], [
              unode "BalloonStyle" $
                unode "text" [
                  unode "strong" ("$[name]" :: String),
                  unode "br" (),
                  unode "p" ("$[description]" :: String) ],
              unode "Icon" $ unode "href" icon ])
            : map geCar cars ) ])
  where
    icon = "https://maps.google.com/mapfiles/kml/shapes/placemark_circle.png" :: String


geCar :: Car -> Element
geCar car
  = unode "Placemark" [
      unode "name" (name car),
      unode "description" (printf "Distance: %0.1f km. Consumption: %0.1f J/m." (distance car/1000) (consumption car) :: String),
      unode "visibility" ("1" :: String),
      unode "open" ("1" :: String),
      unode "styleUrl" ("#car" :: String),
      unode "Point" [
        unode "coordinates" (show (longitude car) <> "," <> show (latitude car))
      ]
    ]




main :: IO ()
main
  = do
      wps <- getRoute
      cars <- map (addLongLat wps) <$> getCars
      writeFile "results/front.tsv" . unlines . map showCar $ cars
      processHandle <- runCommand "gnuplot front.plt"
      waitForProcess(processHandle)
      createDominationGraph cars
      putStrLn . unlines . map showScore . carScores $ cars
      createMap . map (addLongLat wps) $ cars
      return ()