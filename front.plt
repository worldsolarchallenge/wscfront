set term svg size 600,400
set datafile separator "\t"

set output "front.svg"
set xlabel "Speed (km/h)"
set ylabel "Consumption (J/m)"

set rmargin 15
set grid

set style line 11 lc rgb '#cccccc'
set border 3 back ls 11
set grid back ls 11

plot "front.tsv" using 5:6:($1) with labels point pt 6 lc "red" left offset char 0.5 notitle
     
unset output
