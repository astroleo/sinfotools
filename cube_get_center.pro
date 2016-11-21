;;
;; PRO CUBE_GET_CENTER
;; 
;; PURPOSE
;;    finds the peak position in a cube of a standard star; to be used to extract
;;    the spectrum within a certain radius around this position using cube2spec
;;
;; OPTIONS
;;    smwidth    smoothing width in px (5 by default); for no smoothing enter smwidth=1 as smwidth=0 will be interpreted by IDL as keyword not set (causing it to fall back to default)
;;
;; CAVEATS
;;    centers cubes based on mean K band position
;;    IDL's gauss2dfit routine works only well if the image size is multiple times the FWHM of the Gauss
;;       for some small FoV objects, explicit best fit values (using QFitsView) are given instead
;;
function cube_get_center, cubefile, verbose=verbose, header=header, smwidth=smwidth, nx=nx, ny=ny
	if not file_test(cubefile) then begin
		print, 'file ' + cubefile + ' does not exist.'
		return, 1
	endif
	
	a=readfits(cubefile,header,/silent) ;; need to read in data here to get header
	nx=n_elements(a[*,0,0])
	ny=n_elements(a[0,*,0])

	aa=strsplit(cubefile,'/',/extract)
	file_wo_path=aa[n_elements(aa)-1] ;; file without path
	if file_wo_path eq 'Circinus_K_025.fits' or $
		file_wo_path eq 'Circinus_K_025_smooth_5px.fits' then return, [31.14, 30.14] else $
	if file_wo_path eq 'CenA_K_100.fits' or $
		file_wo_path eq 'CenA_K_100_smooth_5px.fits' then return, [36.73, 32.77] else $
	if file_wo_path eq 'IC1459_combined.fits' or $
		file_wo_path eq 'IC1459_combined_smooth_5px.fits' then return, [16.387,30.847] else $
	if file_wo_path eq 'M87_combined.fits' or $
		file_wo_path eq 'M87_combined_smooth_5px.fits' then return, [36.759,43.642] else $
	if file_wo_path eq 'NGC4051_0.1.fits' or $
		file_wo_path eq 'NGC4051_0.1_smooth_5px.fits' then return, [13.98,19.131] else $
	if file_wo_path eq 'NGC4261_combined.fits' or $
		file_wo_path eq 'NGC4261_combined_smooth_5px.fits' then return, [27.3,27.06] else $
	if file_wo_path eq 'NGC4472_combined.fits' or $
		file_wo_path eq 'NGC4472_combined_smooth_5px.fits' then return, [30.709,32.856] else $
	if file_wo_path eq 'NGC3627_combined_smooth_5px.fits' or $
		file_wo_path eq 'NGC3627_combined.fits' then return, [34.018, 32.143] else begin
		wave=get_fits_wave(cubefile,hdr=header,naxis=3)
	
		dateobs=sxpar(header,"DATE-OBS")
		cmd='sqlite3 $OBSDB "select grat1 from sinfo where dateobs=\"'+dateobs+'\";"'
		spawn, cmd, grat1

		if grat1 ne 'K' and grat1 ne 'H+K' then begin
			print, cubefile
			print, grat1
			stop
		endif
	
		; select only K band part of cube	
		params=get_sinfo_drs_parameters()
		K=[params[where(params.name eq 'K_lower')].value,params[where(params.name eq 'K_upper')].value]
		inband_K=where(wave ge K[0] and wave le K[1])
		a=a[*,*,inband_K]
		s=size(a)
		nx=s[1]
		ny=s[2]
		nz=s[3]

		;; median smooth each slice
		smcube=fltarr(nx,ny,nz)
		if not keyword_set(smwidth) then smwidth=5
		if smwidth gt 1 then begin
			for i=0, nz-1 do smcube[*,*,i]=median(a[*,*,i],smwidth)
		endif else smcube=a
		;; do the fit now on the combined cube
		ixnan=where(finite(smcube,/nan))
		if ixnan[0] ne -1 then smcube[ixnan]=0.
		smcube2d=median(smcube,dimension=3)
		g=gauss2dfit(smcube2d,gf)
		;; ctr contains center position in pixels from lower left edge of image
		ctr=[gf[4],gf[5]]
		if keyword_set(verbose) then print, ctr[0], ctr[1], gf[2], gf[3], format='("Fitted center position is ", f5.2, ", ", f5.2, " with FWHM = ", f5.2, ", ", f5.2)'

		return, ctr
	endelse
end