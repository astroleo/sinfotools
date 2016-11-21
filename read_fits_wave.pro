function read_fits_wave, file, naxis=naxis, hdr=hdr
	if not keyword_set(naxis) then naxis = 1

	data = readfits(file,hdr)
	lambda=get_fits_wave(file,hdr=hdr,naxis=naxis)

	return, {w:lambda, f:data}
end