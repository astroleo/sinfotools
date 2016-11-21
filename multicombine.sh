#!/bin/bash
##
## combine cubes from multiple nights
##
## USAGE
##
## e.g. sh $SINFOTOOLS/multicombine.sh "NGC1365" "2010-11-18T02:23:15.9990 2010-11-19T01:51:59.2887 2010-12-03T01:55:24.0051 2010-12-03T02:11:53.4675 2011-02-02T02:22:36.4130"
##
source $HOME/spred/use_spred

dbfile="$OBSDB"

object=$1
refdates=$2

cd $SINFOLOCAL/reduced_cubes/
combinedlist=${object}_combined.txt

for refdate in $refdates; do
	night=`sqlite3 $dbfile "select night from sinfo where dateobs like '$refdate%';"`
	reffile=`sqlite3 $dbfile "select arcfile from sinfo where dateobs like '$refdate%';"`
	refgrat1=`sqlite3 $dbfile "select grat1 from sinfo where dateobs like '$refdate%';"`
	refopti1=`sqlite3 $dbfile "select opti1 from sinfo where dateobs like '$refdate%';"`
	refHHMMSS=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$reffile';"`

	while read line; do
		obj=`echo $line | awk -F " " '{print $1}'`
		xy=`echo $line | awk -F " " '{print $2 " " $3}'`
		echo "$SINFOREDDIR/$night/data/$obj $xy" >> $combinedlist
	done < $SINFOREDDIR/$night/data/list_calcubes_center_${refHHMMSS}.txt
done

if [ "$refgrat1" == "H+K" ]; then refgrat1="HK"; fi
refopti1=$(echo "$refopti1 * 1000/1" | bc)

combinedcube=${object}_${refgrat1}_${refopti1}.fits

echo "Creating $combinedcube..."

spredCombineCubesbySlice.py $combinedlist 2 $combinedcube
