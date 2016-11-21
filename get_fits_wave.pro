;;
;; FUNCTION GET_FITS_WAVE
;;
;; PURPOSE
;;    get wavelength scale of a FITS file using standard header keywords
;;
;; KEYWORDS
;;    hdr (optional)     if set, uses header directly instead of reading data
;;    naxis (optional)   set this keyword if naxis != 1
;;
;; TO DO
;;    speed up routine: find a way to just read header without data
;;
function get_fits_wave, file, hdr=hdr, naxis=naxis
	if not keyword_set(hdr) then data = readfits(file,hdr)
	if not keyword_set(naxis) then naxis = 1

	if naxis eq 1 then begin
		crval = sxpar(hdr,'CRVAL1')
		cdelt = sxpar(hdr,'CDELT1')
		crpix = sxpar(hdr,'CRPIX1')
		naxis = sxpar(hdr,'NAXIS1')
	endif else if naxis eq 2 then begin
		crval = sxpar(hdr,'CRVAL2')
		cdelt = sxpar(hdr,'CDELT2')
		crpix = sxpar(hdr,'CRPIX2')
		naxis = sxpar(hdr,'NAXIS2')
	endif else if naxis eq 3 then begin
		crval = sxpar(hdr,'CRVAL3')
		cdelt = sxpar(hdr,'CDELT3')
		crpix = sxpar(hdr,'CRPIX3')
		naxis = sxpar(hdr,'NAXIS3')
	endif else stop

	wave = ((dindgen(naxis)+1-crpix)*cdelt+crval)

	return, wave
end