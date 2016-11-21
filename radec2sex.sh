#!/bin/bash
function radec2sex() {
	ra=$(echo "scale=5;($1/15.)" | bc) # RA in hours
	dec=$2 # DEC in degrees

	ra_hh=$(echo "$ra/1" | bc)
	ra_rest=$(echo "scale=3;60*($ra-$ra_hh)" | bc)
	ra_mm=$(echo "$ra_rest/1" | bc)
	ra_ss=$(echo "scale=3;60*($ra_rest-$ra_mm)" | bc)

	if [[ `echo "$dec > 0" | bc` -eq 1 ]]; then dec_sign="+"; else dec_sign="-"; fi
	dec=$(echo "scale=5;sqrt($dec^2)" | bc) # probably not the most efficient way to get the absolute value of dec
	dec_dd=$(echo "$dec/1" | bc)
	dec_rest=$(echo "scale=3;60*($dec-$dec_dd)" | bc)
	dec_mm=$(echo "$dec_rest/1" | bc)
	dec_ss=$(echo "scale=3;60*($dec_rest-$dec_mm)" | bc)
	
	echo $ra_hh $ra_mm $ra_ss "     " $dec_sign$dec_dd $dec_mm $dec_ss
	return 1
}

while read line; do
	radec2sex $line
done < ngc1808coords.txt