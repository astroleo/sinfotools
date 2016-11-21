;;
;; PRO IMG_GET_CENTER
;; 
;; PURPOSE
;;    finds the peak position in an image; derived from cube_get_center
;;
function img_get_center, imgfile, verbose=verbose, header=header
	if not file_test(imgfile) then begin
		print, 'file ' + imgfile + ' does not exist.'
		return, 1
	endif
	
	img=readfits(imgfile,header,/silent)
	ixnan=where(finite(img,/nan))
	if ixnan[0] ne -1 then img[ixnan]=0.
	smimg=smooth(img,5)
	g=gauss2dfit(smimg,gf)

	;; ctr contains center position in pixels from lower left edge of image
	ctr=[gf[4],gf[5]]
	if keyword_set(verbose) then print, ctr[0], ctr[1], format='("Fitted center position is ", f5.2, ", ", f5.2)'

	return, ctr
end