// Tabulated spectral data.

// Schott KG3 transmittance.
const float kg3_transmittance[40] = float[](
  0.8627, 0.8588, 0.8451, 0.8300, 0.8207, 0.8192,
  0.8239, 0.8263, 0.8251, 0.8270, 0.8335, 0.8399,
  0.8446, 0.8435, 0.8381, 0.8358, 0.8367, 0.8447,
  0.8480, 0.8440, 0.8362, 0.8246, 0.8087, 0.7892,
  0.7663, 0.7387, 0.7095, 0.6744, 0.6402, 0.5988,
  0.5576, 0.5161, 0.4710, 0.4268, 0.3821, 0.3404,
  0.2895, 0.2547, 0.2214, 0.1871
);
const float enlarger_lamp_K = 3400.0; // TH-KG3's blackbody temperature

// (CIE daylight basis S0/S1/S2 arrays are declared in spectral.glsl)

// (CIE 1931 xy locus array is declared in shared/cie.glsl)
