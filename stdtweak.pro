pro stdtweak, objname, stdname

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; find optimal wavelength offset & scaling for standard star so 
; that its wavelength matches that of an object spectrum.
;
; version 1, Ric Davies July 2004
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; objname = obj spectrum fits file
; stdname = standard star (atmosphere) spectrum fits file

datao = readfits(objname+'.fits',ohdr)
ocrval1 = sxpar(ohdr,'CRVAL1')
ocdelt1 = sxpar(ohdr,'CDELT1')
ocrpix1 = sxpar(ohdr,'CRPIX1')
onaxis1 = sxpar(ohdr,'NAXIS1')
ol = ((dindgen(onaxis1)+1-ocrpix1)*ocdelt1+ocrval1)

datas = readfits(stdname+'.fits',shdr)
scrval1 = sxpar(shdr,'CRVAL1')
scdelt1 = sxpar(shdr,'CDELT1')
scrpix1 = sxpar(shdr,'CRPIX1')
snaxis1 = sxpar(shdr,'NAXIS1')
sl = ((dindgen(snaxis1)+1-scrpix1)*scdelt1+scrval1)

range = where(datao gt 0 and datas gt 0)
o = datao[range]
s = datas[range]
olambda = ol[range]
slambda = sl[range]
onaxis1 = n_elements(o)
snaxis1 = n_elements(s)

s = s / mean(s)
si = interpol(s,slambda,olambda,/quadratic)
tmp = o / interpol(s,slambda,olambda,/quadratic)
qsize = onaxis1/10
qtmp = tmp[qsize:onaxis1-qsize]
qsi = si[qsize:onaxis1-qsize]
ymin = min(qtmp[where(qtmp gt 0 and qsi gt 0)])
ymax = max(qtmp[where(qtmp gt 0 and qsi gt 0)])

stop

;stop
offset=0.
scale = 1.
value = 'o 0'
print,'type "o <value>" for an offset, "s <value>" for a scaling, or "e" to end'
while (value ne 'e') do begin
 read,value
 if (strmid(value,0,1) eq 'o') then $
  offset = float(strmid(value,2,9))
 if (strmid(value,0,1) eq 's') then $
  scale = float(strmid(value,2,9))
 diff = o / interpol(s^scale,slambda+offset*scdelt1,olambda,/quadratic)
 plot,olambda,diff,xstyle=1,ystyle=1,yrange=[ymin,ymax]

endwhile

print,'final scaling is to power '+strtrim(string(scale),2)
print,'final offset is '+strtrim(string(offset),2)+' = '+$
  strtrim(string(offset*scdelt1),2)+' microns'
print,'old CRVAL1 for '+stdname+' was '+$
  strtrim(string(scrval1),2)
print,'new CRVAL1 for '+stdname+' is  '+$
  strtrim(string(scrval1+offset*scdelt1),2)

;stop

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
