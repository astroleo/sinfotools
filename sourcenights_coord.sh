##
## sourcenights
##
## PURPOSE
## Query SQLite database for all nights in which a specified object has been observed
##
##
dbfile="$OBSDB"
ra=$1
dec=$2
##
## define 10 arcsec search box, i.e. 0.0028
searchrad=$(echo "scale=6;10/3600" | bc)
ra_min=$(echo "$ra - $searchrad" | bc)
ra_max=$(echo "$ra + $searchrad" | bc)
dec_min=$(echo "$dec - $searchrad" | bc)
dec_max=$(echo "$dec + $searchrad" | bc)
##
## get all nights in which object has been observed in K or H+K
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like '%K';"