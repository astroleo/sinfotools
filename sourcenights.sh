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
##
## define 10 arcsec search box, i.e. 0.0028
searchrad=$(echo "scale=6;10/3600" | bc)
ra_min=$(echo "$ra - $searchrad" | bc)
ra_max=$(echo "$ra + $searchrad" | bc)
dec_min=$(echo "$dec - $searchrad" | bc)
dec_max=$(echo "$dec + $searchrad" | bc)
##
## get all nights in which object has been observed

echo "J/0.025:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 = 'J' and opti1 = 0.025;"
echo "J/0.1:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 = 'J' and opti1 = 0.1;"
echo "J/0.25:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 = 'J' and opti1 = 0.25;"

echo "H/0.025:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 = 'H' and opti1 = 0.025;"
echo "H/0.1:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 = 'H' and opti1 = 0.1;"
echo "H/0.25:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 = 'H' and opti1 = 0.25;"

echo "K/0.025:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like 'K' and opti1 = 0.025;"
echo "K/0.1:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like 'K' and opti1 = 0.1;"
echo "K/0.25:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like 'K' and opti1 = 0.25;"

echo "H+K/0.025:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like 'H+K' and opti1 = 0.025;"
echo "H+K/0.1:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like 'H+K' and opti1 = 0.1;"
echo "H+K/0.25:"
sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like 'H+K' and opti1 = 0.25;"
##
## get distinct programme IDs and PIs
p=$(sqlite3 $dbfile "select distinct prog from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like '%K';")
echo ""
echo "Programmes are: $p"
echo ""
for prog in $p; do
	p1=$(echo $prog | awk -F "(" '{print $1}')
	p2=$(echo $p1 | cut -c 2-10)
	echo $p2
	sqlite3 $dbfile "select picoi, title from prog where prog like \"%${p2}\";"
	##
	## get all AO info for object observations
	sqlite3 $dbfile "select distinct ao_tiptilt, ao_horder, ao_lgs from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and grat1 like '%K' and prog like \"$prog\";"
done