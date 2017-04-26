##
## sourcenights
##
## PURPOSE
## Query SQLite database for all nights in which a specified object has been observed
##
##
dbfile="$OBSDB"
nobj=`sqlite3 $dbfile "select count(*) from sources where id='$1';"`
if [ ! $nobj -eq 1 ]; then
#	echo "No such source (or too many)."
	exit
fi

ra=`sqlite3 $dbfile "select ra from sources where id='$1';"`
dec=`sqlite3 $dbfile "select dec from sources where id='$1';"`


dbfile="$OBSDBLOCAL/NACO/naco.db"
##
## define 10 arcsec search box, i.e. 0.0028
searchrad=$(echo "scale=6;10/3600" | bc)
ra_min=$(echo "$ra - $searchrad" | bc)
ra_max=$(echo "$ra + $searchrad" | bc)
dec_min=$(echo "$dec - $searchrad" | bc)
dec_max=$(echo "$dec + $searchrad" | bc)
##
## get all night in which object has been observed in K or H+K
sqlite3 $dbfile "select date_obs,ins_opti6_name from obs where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"