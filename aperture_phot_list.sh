while read line; do
	cube=$(echo $line | awk '{print $1}')
	ctr_x=$(echo $line | awk '{print $2}')
	ctr_y=$(echo $line | awk '{print $3}')
	idl -e aperture_phot -args $cube $2 $ctr_x $ctr_y
done < $1