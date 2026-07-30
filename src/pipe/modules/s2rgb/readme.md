# s2rgb: spectrum to display RGB

`s2rgb` is the terminal output boundary from the packed `spectral` connector to
linear Rec.2020. It integrates the scene radiance against human Color Matching Functions
and applies the final XYZ-to-Rec.2020 display encoding matrix.

## parameters

* `observer` human observer color matching functions to integrate against
