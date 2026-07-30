# srelight: spectral relighting

`srelight` re-lights the spectral scene under a chosen light source's spectral
power distribution, instead of the reference D65 illuminant. Each light source
model exposes only the parameters relevant to it; switching `source`
shows/hides the matching group below.

## parameters

* `source` light source model to relight the scene under
* `mix` relighting mix factor, 0 is D65 reference, 1 is fully the custom light source
* `d cct` daylight color temperature
* `bb cct` blackbody color temperature
* `led pmp` LED blue pump peak wavelength
* `led cct` LED phosphor color temperature
* `led cri` LED color rendering index rating
* `discharg` discharge lamp subtype
* `laser_l1` primary laser peak wavelength
* `laser_l2` secondary laser peak wavelength
* `bandwdth` spectral bandwidth of the laser peaks

Each source's spectral power distribution is normalized to the same total
luminance as D65, so brightness changes at `mix` 1.0 come from metameric
mismatch against the scene's reflectances, not from exposure loss.
