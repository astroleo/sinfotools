;;
;; takes a cube, extracts a spectrum in a given radius (in pixel) around the fitted central position
;;
;; PARAMETERS
;;
;;    cubefile   file name of the cube of which the spectrum will be extracted
;;    outfile    file name of the saved spectrum
;;    radius     radius (in px) for the extraction
;;    wave       (optional) returns wavelength calibration
;;    smooth     (optional) smoothes each slice (uses smcube from cube_get_center) before determining total counts; NOT flux conserving!
;;    ctr        fitted center position (x,y pixel values)
;;    usectr     use these pixels as center position
;;
function cube2spec, cubefile, outfile, radius, wave=wave, smooth=smooth, ctr=ctr, usectr=usectr
	if not file_test(cubefile) then begin
		spawn, 'sinfolog "file ' + cubefile + ' does not exist."'
		return, 1
	endif

	if keyword_set(usectr) then ctr=usectr else $
		ctr=cube_get_center(cubefile,/verbose)
	
	cube=readfits(cubefile,header)
	s=size(cube)
	nx=s[1]
	ny=s[2]
	nz=s[3]

	if keyword_set(smooth) then begin
		smwidth=5
		smcube=fltarr(nx,ny,nz)
		for i=0, nz-1 do smcube[*,*,i]=median(cube[*,*,i],smwidth)
		cube=smcube
	endif
	
	ixnan=where(finite(cube,/nan))
	cube[ixnan]=0.

	crpix3=sxpar(header,'CRPIX3') ; Reference pixel in z
	crval3=sxpar(header,'CRVAL3') ; central wavelength
	cdelt3=sxpar(header,'CDELT3') ; microns per pixel
	ctype3=sxpar(header,'CTYPE3')
	cunit3=sxpar(header,'CUNIT3')
	wave=crval3 + (findgen(nz)-crpix3)*cdelt3

	mask=fltarr(nx,ny)
	for x=0, nx-1 do begin
		for y=0, ny-1 do begin
			d=sqrt((x-ctr[0])^2+(y-ctr[1])^2)
			if d le radius then mask[x,y]=1 else mask[x,y]=0
		endfor
	endfor
	
	spec=fltarr(nz)
	for i=0,nz-1 do spec[i]=total(mask * cube[*,*,i])
	
	; define outfile
	fxaddpar, header, 'crpix1', crpix3
	fxaddpar, header, 'crval1', crval3
	fxaddpar, header, 'cdelt1', cdelt3
	fxaddpar, header, 'ctype1', ctype3
	fxaddpar, header, 'cunit1', cunit3
	fxaddpar, header, 'naxis', 1
	fxaddpar, header, 'naxis1', nz
	sxdelpar, header, 'naxis2'
	sxdelpar, header, 'naxis3'
	sxdelpar, header, 'crpix2'
	sxdelpar, header, 'crpix3'
	sxdelpar, header, 'crval2'
	sxdelpar, header, 'crval3'
	sxdelpar, header, 'cdelt2'
	sxdelpar, header, 'cdelt3'
	sxdelpar, header, 'ctype2'
	sxdelpar, header, 'ctype3'
	sxdelpar, header, 'cunit2'
	sxdelpar, header, 'cunit3'
	sxdelpar, header, 'CD1_1'
	sxdelpar, header, 'CD1_2'
	sxdelpar, header, 'CD2_1'
	sxdelpar, header, 'CD2_2'
	writefits, outfile, spec, header
	print, "Wrote " + outfile
	return, spec
end