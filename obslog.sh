##
## sourcenights
##
## PURPOSE
## Query SQLite database for all nights in which a specified object has been observed
##
##
## set locale to use point as decimal symbol
export LC_NUMERIC="C"

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
searchrad=0.0028
ra_min=$(echo "$ra $searchrad" | awk '{printf "%f", $1 - $2}')
ra_max=$(echo "$ra $searchrad" | awk '{printf "%f", $1 + $2}')
dec_min=$(echo "$dec $searchrad" | awk '{printf "%f", $1 - $2}')
dec_max=$(echo "$dec $searchrad" | awk '{printf "%f", $1 + $2}')
##
## get all nights in which object has been observed

nights=`sqlite3 $dbfile "select distinct night from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"`

grat1s=(H K H+K)
opti1s=(0.025 0.1 0.25)

for night in $nights; do
	for grat1 in ${grat1s[@]}; do
		for opti1 in ${opti1s[@]}; do
			tot=`sqlite3 $dbfile "select cast(total(dit*ndit) as integer) from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and night='$night' and grat1 = '$grat1' and opti1 = $opti1;"`
			if [ $tot -gt 0 ]; then
				# first observation
				dateobs_first=`sqlite3 $dbfile "select dateobs from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and night='$night' and grat1 = '$grat1' and opti1 = $opti1 order by dateobs limit 1;"`
				dateobs_last=`sqlite3 $dbfile "select dateobs from sinfo where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max and night='$night' and grat1 = '$grat1' and opti1 = $opti1 order by dateobs desc limit 1;"`
				seeing=`sqlite3 $dbfile "select avg(fwhm_start) from sinfo where datetime(dateobs) between datetime('$dateobs_first') and datetime('$dateobs_last');"`
				echo "$1,$night,$grat1,$opti1,$tot,$seeing"
			fi
		done
	done
done