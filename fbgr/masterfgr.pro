; fore(+)background estimation
; Keywords ==> fg: Foreground; bg: Background
; CMD system ==> [4.5] vs. [3.6]-[4.5]

; ------- input settings
; case flags for fg type
; 0: wise samples
; 1: tril model
fgmode = 1
; total coverage in deg^2
ascale = 3.8423337d; / 0.25d
; constraints on cmd bins
xmin=-6d & xmax=6d
ymin=9d & ymax=16d
xbin = 0.4d & ybin = 0.34d
; -------

; output file names
case fgmode of
0:output_name = 'CleanCat_WISE'
1:output_name = 'CleanCat_Tri'
endcase

; paths to input data files 
dir_fg = '~/Projects/Andromeda/cats/fgr_input'
dir_bg = '~/Projects/Andromeda/cats/Kim12/'

; ------------- read catalogs
; WISE fg samples, each covering 1 deg^2 area
readcol, dir_fg+"/wf1", w1_fg1, w2_fg1, f='d,d', comm='#'
readcol, dir_fg+"/wf2", w1_fg2, w2_fg2, f='d,d', comm='#'
; IRAC matched with WISE
readcol, dir_fg+"/wise-irac", i1_x, i2_x, w1_x, w2_x, f='d,d', comm='#'
; IRAC (raw, cleaned, flags removed)
readcol, dir_fg+"/irac_4cols", irac1, ra, dec, irac2, f='d,d,d,d', comm='#'
; TRIL fg model
readcol, dir_fg+"/trilnew.prt/", tw1, tw2, f='d,d', comm='#'
; bg galaxies from Kim et al. (2012)
readcol, dir_bg+"SDWFS_45.dat", mag_sdwfs, n_sdwfs, f='d,d'
readcol, dir_bg+"H-ATLAS+Spitzer_45.dat", mag_hs, n_hs, f='d,d'
readcol, dir_bg+"fazio_45.dat", mag_fls, n_fls, f='d,d'
readcol, dir_bg+"aeges_45.dat", mag_egs, n_egs, f='d,d'
; -------------

; convert irac to wise
irac1 = irac2wise(irac1, 1, 0)
irac2 = irac2wise(irac2, 2, 0)

; ------------- initialize arrays for the following loop
x = xmin + xbin * findgen((xmax-xmin)/xbin+2) ; color
y = ymin + ybin * findgen((ymax-ymin)/ybin+2) ; mag
nox = n_elements(x)	&	noy = n_elements(y) ; # bins covering the cmd
nirac = n_elements(ra) ; total # irac sources
;ncounts = dblarr(nox-1, noy-1) ; M31 number counts
;ncounts[*] = !values.f_nan ; assign NAN to all elements
;ns = dblarr(nox-1, noy-1)	; abs difference btwn (wise) fg number counts 
;n_sigma = dblarr(nox-1, noy-1)	; fg stdv obtained from 'inds'
probcol = dblarr(nirac)	; prob values (all irac sources)
probcol[*] = !values.f_nan ; assign NAN to all elements
; -------------
step = 2
for i = 0, nox-3, step do begin ; along color axis
for j = 0, noy-2 do begin ; along mag axis
ncounts = !values.f_nan	; init the variable ncounts (assuming a scalar-formated code)
	; ------------------------------------------------
	; -------- select/count sources in cmd bins ------
	; ------------------------------------------------
	; --- IRAC (full cat)
        n_irac = squib(irac2, irac1-irac2, x[i], x[i+step], y[j], y[j+1], 0)
	ind_irac = squib(irac2, irac1-irac2, x[i], x[i+step], y[j], y[j+1], 1)
	; --- IRAC (matched w\ WISE)
	nx = squib(w2_x, w1_x-w2_x, x[i], x[i+step], y[j], y[j+1], 0)
	; --- fg samples
	nfg1 = squib(w2_fg1, w1_fg1-w2_fg1, x[i], x[i+step], y[j], y[j+1], 0)
	nfg2 = squib(w2_fg2, w1_fg2-w2_fg2, x[i], x[i+step], y[j], y[j+1], 0)
	n_wise = ascale * (nfg1+nfg2)/2d ; avg count scaled by total coverage
	; --- fg TRIL MODEL	
	n_tril = squib(tw2, tw1-tw2, x[i], x[i+step], y[j], y[j+1], 0)
	; ------------------------------------------------ 
	print, nfg1, nfg2, n_tril, nx

	case fgmode of
	0: n_avg = n_wise	; use wise fg samples
	1: n_avg = n_tril	; use tril galactic model
	endcase

	if (nx gt 0) and (n_avg ge 0) then begin	; any point source ?

		ndiff = nx - n_avg	; subtract off the bg from total
		if ndiff gt 0 then begin	; total>fg
			;ncounts[i,j] = ndiff / nx ; prob of being M31
			ncounts = ndiff / nx
			;if fgmode eq 0 then begin
			; statistics for comparing the two wise fg samples 
			;ns[i,j] = abs(nfg1-nfg2)/n_avg * ascale ; abs difference
			;n_sigma[i,j] = sqrt(n_avg)/n_avg ; stdv
			;endif
		endif else begin ; total<fg
			;ncounts[i,j] = 0.
			ncounts = 0.
		endelse

	endif
	if (ind_irac[0] ne -1) then begin ; any available IRAC source ?
	probcol[ind_irac] = ncounts ;ncounts[i,j] ; apply the prob values
	endif

endfor
endfor

; convert wise to irac
irac1 = irac2wise(irac1, 1, 1)
irac2 = irac2wise(irac2, 2, 1)

forprint, ra, dec, irac2, irac1-irac2, probcol, text=output_name, /nocomment

; ****************************************************************
; ********************  Background Galaxies **********************
; ****************************************************************
stop
fitdeg = 2
ymin=16d & ymax=19d & ybin=1d
mag_hs = irac2ab(mag_hs, 2, 1)
n_hs = n_hs * ascale ; # sources scaled by coverage
par = poly_fit(mag_hs, alog(n_hs), fitdeg, chisq=chisq, /double) ; fit 2nd deg poly
rchisq = chisq/(n_elements(mag_hs)-fitdeg-1) ; reduced chi^2

; init loop
y = ymin + ybin * findgen((ymax-ymin)/ybin+2) ; mag
noy = n_elements(y) ; # bins covering the cmd
probcol[*] = !values.f_nan ; assign NAN to all elements

for j = 0, noy-2 do begin ; along mag axis
ncounts = !values.f_nan	; init the variable ncounts (assuming a scalar-formated code)
	; ------------------------------------------------
	; -------- select/count sources in cmd bins ------
	; ------------------------------------------------
	; --- IRAC (full cat)
        n_irac = squib(irac2, irac1-irac2, xmin, xmax, y[j], y[j+1], 0)
	ind_irac = squib(irac2, irac1-irac2, xmin, xmax, y[j], y[j+1], 1)
	; -----------
	y_mid = (y[j]+y[j+1])/2 ; middle point
	n_mid = par[0] + par[1] * y_mid + par[2] * y_mid^2d ; estimate bg count using the fit parameters
	n_mid = exp(n_mid)
	print, y_mid, n_mid, n_irac
endfor

END
