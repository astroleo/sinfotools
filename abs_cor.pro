pro abs_cor, objlist, atmos, thresh=thresh, over=over, poly=poly, test=test

;----------------------------
; cross correlate spectra using atmospheric absorption features
; and shift the first (objcubelist) to match the second (atmos).
;----------------------------
; examples:
;  abs_cor,'spec1'
;  abs_cor,'cube*',/test
;  abs_cor,'cube0.fits',atmos='atmos_HK.fits',thresh=0.5,/over
;
;----------------------------
; objlist = name of fits cube(s) or 1D spectra of science object(s), 
;           typically standard stars; can include wildcards
;
; atmos = atmospheric transmission spectrum (typically from atran)
;         if none is specified, the default is used if it can be
;         found. It is probably best to use a spectrum at the same
;         resolution as the object spectrum.
; 
; OPTIONS:
;
; thresh = threshold (as fraction of max value) to which spectra in
;          cube sould be combined; default is 0.1
;
; over = keyword for overwriting original file
;
; poly = order of poylnomial to divide out of intrinsic object spectrum
;                     (default=3)
;
; test = keyword for just testing, and not creating output files
;
;----------------------------
; version 1.0, 24 Feb 06, Ric Davies

;----------------------------
; advanced parameters

atmos_default = 'atmosHK_pix100'  ; name of default atmospheric 
                                  ; transmission spectrum

hlim = [1.48,1.79]       ; min,max of H-band
klim = [2.00,2.40]       ; min,max of K-band

;----------------------------

resolve_all,/continue_on_error,/quiet

if not(keyword_set(poly)) then poly = 3

if not(keyword_set(thresh)) then thresh = 0.10

;check atmos spectrum
if (n_elements(atmos)) eq 0 then begin
    atmos = atmos_default
    tmp = findfile(atmos+'.fits',count=nfiles)
    if (nfiles eq 1) then begin
        print,'Using default atmospheric transmission spectrum : '$
          +atmos+'.fits'
    endif else begin
    read,'Name of atmospheric transmission spectrum : ',atmos
    endelse
endif
if (strmid(atmos,4,5,/reverse_offset) eq '.fits') then $
  atmos = strmid(atmos,0,strlen(atmos)-5)

;read in atmosphere & check lambda sampling
a_raw = readfits(atmos+'.fits',ahdr)
crval1a = sxpar(ahdr,'CRVAL1')
cdelt1a = sxpar(ahdr,'CDELT1')
crpix1a = sxpar(ahdr,'CRPIX1')
naxis1a = sxpar(ahdr,'NAXIS1')
lambdaa = ((findgen(naxis1a)+1-crpix1a)*cdelt1a+crval1a)

;check how many files
if (n_elements(objlist) eq 0) then begin
    objlist = ''
    read,'Name of object fits cube(s) : ',objlist
    endif
if (strmid(objlist,4,5,/reverse_offset) eq '.fits') then $
  objlist = strmid(objlist,0,strlen(objlist)-5)

filenames = findfile(objlist+'.fits',count=nfiles)
if (nfiles eq 0) then begin
    print,'No files found'
    stop
endif
if (nfiles gt 1) then begin
    print,'Found ',strtrim(string(nfiles),2),' files:'
    for i=0,nfiles-1 do print,filenames[i]
endif

for fileloop=0,nfiles-1 do begin
objcube = filenames[fileloop]
print,'Working on ',objcube


;read in object cube
if (strmid(objcube,4,5,/reverse_offset) eq '.fits') then $
  objcube = strmid(objcube,0,strlen(objcube)-5)
obj_raw = float(readfits(objcube+'.fits',shdr))
csize = size(obj_raw)

; for 1d spectra
if (csize[0] eq 1) then begin
crvals = sxpar(shdr,'CRVAL1')
cdelts = sxpar(shdr,'CDELT1')
crpixs = sxpar(shdr,'CRPIX1')
naxis1s = sxpar(shdr,'NAXIS1')
lambdas = ((findgen(naxis1s)+1-crpixs)*cdelts+crvals)
s_raw = obj_raw
endif

; for 3d cubes
if (csize[0] eq 3) then begin
crvals = sxpar(shdr,'CRVAL3')
cdelts = sxpar(shdr,'CDELT3')
crpixs = sxpar(shdr,'CRPIX3')
naxis3s = sxpar(shdr,'NAXIS3')
naxis2s = sxpar(shdr,'NAXIS2')
naxis1s = sxpar(shdr,'NAXIS1')
lambdas = ((findgen(naxis3s)+1-crpixs)*cdelts+crvals)
endif

range = where((lambdas ge hlim[0] and lambdas le hlim[1]) or (lambdas ge klim[0] and lambdas le klim[1]),range_i)

;extract spectrum and normalise
if (csize[0] eq 3) then begin
print,'Extracting spectrum'
im = fltarr(naxis1s,naxis2s)*0.
for ix=0,naxis1s-1 do begin
    for iy=0,naxis2s-1 do begin
        vals = reform(obj_raw[ix,iy,range])
        gvals = where(finite(vals),gvals_i)
        if (gvals_i gt 0) then im[ix,iy] = median(vals[gvals])
    endfor
endfor
good = where(im ge max(im)*thresh)
s_raw = fltarr(naxis3s)*0.
for iz=0,naxis3s-1 do begin
    slice = reform(obj_raw[*,*,iz])
    vals = slice[good]
    gvals = where(finite(vals),gvals_i)
    if (gvals_i gt 0) then s_raw[iz] = mean(vals[gvals])
endfor
endif

s = s_raw / median(s_raw)

;check wavelengths of object and atmos
if (mean(lambdaa-lambdas) ne 0) then $
    a = spline(lambdaa,a_raw,lambdas) else a = a_raw

;adjust where atmos is zero
a = a / median(a)
tmp = where(s eq 0,tmp_i)
if (tmp_i gt 0) then a[tmp] = 0

;divide out intrinsic shape of spectrum
sa = s / a
tmp = where(finite(sa,/nan) or finite(sa,/inf),tmp_i)
if (tmp_i gt 0) then sa[tmp] = 0.
zzz_i = 0

for i=1,5 do begin
errs = fltarr(n_elements(lambdas))*0.+1.e3
if (range_i gt 0) then errs[range] = 1.e-6
if (zzz_i gt 0) then errs[zzz] = 1.e3
par1 = poly_fit(lambdas,sa,poly, measure_errors=errs,yfit=fit)
par2 = sa-fit
par3 = stddev(par2[where(errs lt 10)])
par4 = stddev(par2[where(errs lt 10 and abs(par2) le 4.0*par3)])
zzz = where(abs(par2) gt 3*par4,zzz_i)
;plot,sa,yrange=[0,5]
;oplot,fit,color=6
;oplot,errs/1e3,color=13
;print,i,zzz_i
;wait,0.2
endfor

sd = s / fit

;cross correlate the spectrum and atmosphere
print,'Finding shift'
npts = 7
nvec = indgen(npts)-npts/2
shift = 0.
delta_shift = 1.
iter = 0.
maxiter = 10

while (abs(delta_shift) gt 0.005 and iter lt maxiter) do begin

sd_s = spline(lambdas+shift*cdelts,sd,lambdas)
xc = c_correlate(sd_s,a,nvec)
npts_z = interpol(nvec,100*npts-99)
xc_z = spline(nvec,xc,npts_z)
delta_shift =  mean(npts_z[where(xc_z eq max(xc_z))])
shift = shift + delta_shift
iter = iter + 1
;print,iter,delta_shift,shift
endwhile

if (iter eq maxiter) then print,'Iteration terminated prematurely'

;-ve shifts move spectrum to shorter wavelengths
if (shift lt 0) then print,'Shift = ',$
  string(format='(f5.2)',shift),' pixels (to shorter wavelengths)'
if (shift gt 0) then print,'Shift = ',$
  string(format='(f5.2)',shift),' pixels (to longer wavelengths)'

if not(keyword_set(test)) then begin
;apply same shift to whole cube
    if (abs(shift) lt 0.01) then begin
        print,'No shift applied (too small)' 
        obj_out = obj
    endif else begin
        if (csize[0] eq 3) then begin
            print,'Shifting entire cube... this may take a couple of minutes'
            obj_out = fltarr(naxis1s,naxis2s,naxis3s)
            for ix=0,naxis1s-1 do begin
                for iy=0,naxis2s-1 do begin
                    ;print,ix,iy
                    outspec = fltarr(naxis3s)
                    outspec = outspec + !values.f_nan
                    tmp_s = reform(obj_raw[ix,iy,*])
                    good = where(finite(tmp_s),good_i)
                    if (good_i ge 5) then outspec = $
                      spline(lambdas[good]+shift*cdelts,tmp_s[good],lambdas)
                    bad = where(finite(tmp_s,/nan) or finite(tmp_s,/inf),bad_i)
                    if (bad_i gt 0) then outspec[bad] = !values.f_nan
                    obj_out[ix,iy,*] = outspec
                endfor
            endfor
        endif
        if (csize[0] eq 1) then begin
            obj_out = fltarr(naxis1s)
            obj_out = obj_out + !values.f_nan
            good = where(finite(obj_raw),good_i)
            if (good_i ge 5) then obj_out = $
              spline(lambdas[good]+shift*cdelts,obj_raw[good],lambdas)
            bad = where(finite(obj_raw,/nan) or finite(obj_raw,/inf),bad_i)
            if (bad_i gt 0) then obj_out[bad] = !values.f_nan
        endif
    endelse
    
;write out shifted spectrum
    if keyword_set(over) then begin
        writefits,objcube+'.fits',float(obj_out),shdr
    endif else begin
        writefits,objcube+'_s.fits',float(obj_out),shdr
    endelse
endif

endfor ; fileloop

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
