# sfilmsim: fully spectral version of filmsim

## connectors

* `input` the `spectral` scene radiance payload
* `output` the exposed, developed, and printed film simulation (or negative)
* `profile` wire data/filmsim.lut with the film and paper data

## parameters

this module has a lot of parameters.

* `process` what to read and write: raw to print, raw to negative, or negative scan to print
* `film` the film stock id in the datafile
* `ev film` exposure correction when exposing the film
* `g film` gamma correction for exposing the film
* `g fast` gamma correction for the fast (highlight) density curve sublayer
* `g slow` gamma correction for the slow (shadow) density curve sublayer
* `exhaust` developer exhaustion, reduces contrast/density in areas of high exposure
* `hl boost` boosts highlights, useful in combination with halation
* `paper` the print paper id in the datafile
* `p base` scale on paper's base density in the print
* `ev paper` exposure correction when sensitising the paper
* `g paper` gamma correction when sensitising the paper
* `g fast p` gamma correction for the paper fast density curve sublayer
* `g slow p` gamma correction for the paper slow density curve sublayer
* `p exh` paper developer exhaustion, reduces contrast/density in areas of high paper exposure
* `glare` veiling glare in the scanner/viewing optics
* `filter c` cyan filtration when exposing the print paper, auto-filled by neutral optimisation
* `filter m` magenta filtration when exposing the print paper, auto-filled by neutral optimisation
* `filter y` yellow filtration when exposing the print paper, auto-filled by neutral optimisation
* `tune m` fine tune the magenta filter, red/green tint
* `tune y` fine tune the yellow filter, warm/cold white balance
* `preflash` preflash the paper, lowering maximum luminance and contrast
* `pf ev` exposure of the preflash step
* `pf m` magenta filtration during the preflash step
* `pf y` yellow filtration during the preflash step
* `couplers` developer inhibitor release couplers, affects colourfulness and local contrast
* `cp amt` amount of developer inhibitor release couplers
* `lang r` red-channel Langmuir isotherm coefficient for the coupler inhibition curve
* `lang g` green-channel Langmuir isotherm coefficient for the coupler inhibition curve
* `lang b` blue-channel Langmuir isotherm coefficient for the coupler inhibition curve
* `cp rad` radius of influence of the couplers on the negative
* `halation` colourful blur around high contrast edges
* `radius` radius of the halation effect on the negative
* `hal amt` scale the rgb strength of the halation effect
* `hal mids` midtone protection for halation, fades out the effect for darker tones
* `hal bnc` number of halation light bounces to simulate
* `hal dec` decay factor applied to each successive halation bounce
* `scat amt` in-emulsion light scatter before halation
* `strength` strength of the halation effect per colour channel
* `grain` film grain simulation
* `size` scale the grain size
* `uniform` scales the stock's own grain uniformity
* `enlarge` upsample the image before exposing the paper, for a bigger print/export
* `scan ill` colour temperature of the viewing/scanning illuminant
* `film ill` colour temperature to expose the film under instead of its own reference
