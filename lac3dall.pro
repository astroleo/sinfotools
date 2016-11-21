@$SINFOTOOLS/lac3d/lac3dn
;; pro lac3dall
;;
;; run lac3d in a directory with potential subdirectories YYYY-MM-DD/cubes
;;
pro lac3dall
	spawn, 'find * | egrep "^standard\/cube_[0-9]{6}\.fits"', cubes_std ;; get list of all standard star cubes
	spawn, 'find * | egrep "^data\/cube_[0-9]{6}\.fits"', cubes_data ;; get list of all object cubes
	spawn, 'find * | egrep "^data\/cube_sky_[0-9]{6}\.fits"', cubes_sky ;; get list of all sky cubes
	
	cubes=[cubes_std,cubes_data,cubes_sky]
	
	for i=0, n_elements(cubes)-1 do begin
		;;
		;; check if lac3d cube already exists
		cube_split=strsplit(cubes[i],'.',/extract)
		xcube=cube_split[0]+'_crop_x.fits'
		print, xcube
		
		if file_test(xcube) then begin
			spawn, 'sinfolog "lac3d cube ' + xcube + ' exists. Continuing"'
			continue
		endif
		a=systime(/seconds)
		;;
		;; now cropping cube for NaN values to speed up lac3d
		;; benchmarks
		;;    MacBookAir
		;;       an original 64x68x2560 cube took 638 sec, cropped 300 slices from each edge in z dimension: 561 sec, further cropped each slice in x/y by 3 pixels: 447 sec; it also significantly reduces the file size
		;;    macir26
		;;       full cube took 447 sec
		;;
		spawn, 'sinfolog "Now cropping cube to actual data length: ' + cubes[i] + '"'
		cube=readfits(cubes[i],hdr)
		naxis1=sxpar(hdr,'naxis1')
		naxis2=sxpar(hdr,'naxis2')
		naxis3=sxpar(hdr,'naxis3')
		cropx=3
		cropy=3
		cropz=300
		cube_crop=cube[cropx:naxis1-cropx-1,cropy:naxis2-cropy-1,cropz:naxis3-cropz-1]
		
		; update header
		crpix3_new = fix(sxpar(hdr, 'CRPIX3')) - cropz
		sxaddpar, hdr, 'CRPIX3', crpix3_new

		f_cube_crop=cube_split[0]+'_crop.fits'
		writefits,f_cube_crop,cube_crop,hdr

		spawn, 'sinfolog "Now removing cosmics from cube: ' + f_cube_crop + '"'
		lac3d, f_cube_crop
		b=systime(/seconds)
		spawn, 'sinfolog "Finished removing cosmics from cube: ' + f_cube_crop + '"'
		spawn, 'sinfolog "That took ' + strtrim(b-a,2) + ' seconds."'
	endfor
end