pipe/modules/sfilmsim/libsfilmsim.so: pipe/modules/sfilmsim/wb.h pipe/modules/sfilmsim/pos_wb.h
SFILMSIM_GLSL_DEPS=pipe/modules/sfilmsim/constants.h pipe/modules/sfilmsim/head.glsl pipe/modules/sfilmsim/data.glsl pipe/modules/sfilmsim/setup.glsl pipe/modules/sfilmsim/filmsim.glsl pipe/modules/sfilmsim/state.glsl pipe/modules/sfilmsim/state_ops.glsl pipe/modules/sfilmsim/sampling.glsl pipe/modules/sfilmsim/develop.glsl pipe/modules/sfilmsim/print.glsl pipe/modules/sfilmsim/halation.glsl pipe/modules/shared/spectral.glsl
pipe/modules/sfilmsim/expose.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/develop.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/halin.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/halout.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/scatter.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/dirlut.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/setup.comp.spv: $(SFILMSIM_GLSL_DEPS)
pipe/modules/sfilmsim/scan.comp.spv: $(SFILMSIM_GLSL_DEPS)
