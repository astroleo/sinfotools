ra=$(sqlite3 $OBSDB "select ra from sinfo where dateobs='$1';")
dec=$(sqlite3 $OBSDB "select dec from sinfo where dateobs='$1';")

##
## define 10 arcsec search box, i.e. 0.0028
searchrad=$(echo "scale=6;10/3600" | bc)
ra_min=$(echo "$ra - $searchrad" | bc)
ra_max=$(echo "$ra + $searchrad" | bc)
dec_min=$(echo "$dec - $searchrad" | bc)
dec_max=$(echo "$dec + $searchrad" | bc)
##
## get info on calibrator
sqlite3 $OBSDB "select ra, dec, name, Jmag, Hmag, Kmag, SpType from std where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"