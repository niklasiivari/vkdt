# rgb2s: rgb to spectral upsampling

`rgb2s` is the input boundary for the experimental spectral graph. It
transforms RGB input images into the `spectral` scene radiance
payload.

## connectors

* `input` RGB input image
* `output` the `spectral` scene radiance payload
* `sclut` the spectral upsampling LUT, wire depending on `mode`
* `picked` (optional) route picked colour here for auto white balance

## parameters

* `mode` upsample using camera SSF (`sclut`) or from Rec.2020 RGB (`spectra-em`)
* `exposure` linear exposure adjustment
* `temp` capture illuminant temperature anchor, `0` for auto white balance. only used in `Camera SSF` mode
* `tint` green-magenta white balance shift

## usage & LUT wiring

### Mode 0: Camera
Used when camera Spectral Sensitivity Functions (SSFs) are available.
1. Generate the companion camera LUT with:
   `vkdt-mkclut --nanchor 9 --spectral <camera model>`
2. Connect an `i-lut` node loading `data/${maker} ${model}.spectral.lut` to `rgb2s`'s `sclut` connector.
3. Set `mode` to `camera`.
4. White balance can be adjusted via `temp` or set to `0` for auto-WB.

### Mode 1: Rec.2020
Used to feed spectral downstream modules (`srelight`, `sfilmsim`, etc.) from standard linear Rec.2020 RGB without requiring camera SSF calibration.
1. Connect an `i-lut` node loading `data/spectra-em.lut` (shipped in `bin/data/spectra-em.lut`) to `rgb2s`'s `sclut` connector.
2. Set `mode` to `rec.2020`.

## `spectral` payload

The logical connector is named `spectral` and is exposed as connector
`output`. Its storage is an array of eleven native-resolution `rgba:f16`
images: ten RGBA groups plus a one-sample tail.
