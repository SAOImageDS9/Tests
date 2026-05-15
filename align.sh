echo
echo "*** align.sh ***"

ds9 -title DS9Test -scale mode 98 data/r.fits data/i.fits data/v.fits -match frame wcs -tile -exit

ds9 -title DS9Test -zscale -mosaicimage iraf mosaic/mosaicimage.fits -mosaicimage wcs mosaic/mosaicimage.fits -tile -exit

ds9 -title DS9Test -zscale -mosaic wcs mosaic/mosaicimage.fits[1] mosaic/mosaicimage.fits[2] mosaic/mosaicimage.fits[3] -rgb -red mosaic/mosaicimage.fits[1] -green mosaic/mosaicimage.fits[2] -blue mosaic/mosaicimage.fits[3] -tile -exit

ds9 -title DS9Test -zscale -mosaic wcs data/m51hst.fits fits/img.fits -fits -rgb -red data/m51hst.fits -green fits/img.fits -tile -exit

ds9 -title DS9Test -zscale data/ch4.nonan.fits data/mips24.nonan.fits -frame new -mosaic wcs data/ch4.nonan.fits data/mips24.nonan.fits -frame new rgb -fits -red data/ch4.nonan.fits -green data/mips24.nonan.fits -frame 1 -pan to 17:42:56.836 -28:31:53.10 fk5 -match frame wcs -tile -exit

ds9 -title DS9Test -mosaicimage iraf mosaic/ds9_2amp.fits -orient x -mosaicimage wcs mosaic/ds9_2amp.fits -orient none -fits -rgb -red mosaic/ds9_2amp.fits[1] -green mosaic/ds9_2amp.fits[2] -tile -exit

ds9 -title DS9Test -mosaicimage iraf mosaic/ds9_8amp_2x2.fits -orient x -mosaicimage wcs mosaic/ds9_8amp_2x2.fits -orient none -tile -exit

ds9 -title DS9Test data/f475w_sub.fits.gz -linear -zscale -frame new data/acisf01423N002_evt2.fits -log -minmax -rgb data/f475w_sub.fits.gz -linear -zscale -green data/acisf01423N002_evt2.fits -log -minmax -frame 2 -lock frame wcs -zoom 2 -exit

echo "Done"


