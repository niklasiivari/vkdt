// 41 linear samples at 10nm intervals (380nm to 780nm).
// Stored as 11 rgba:f16 images (group 10 holds 780nm in .x, .yzw = 0).

const int spectral_samples = 41;
const int spectral_groups = 11;
const float spectral_lambda0 = 380.0;
const float spectral_step_nm = 10.0;

const vec4 spectral_lambda[spectral_groups] = vec4[](
  vec4(380.0, 390.0, 400.0, 410.0), vec4(420.0, 430.0, 440.0, 450.0),
  vec4(460.0, 470.0, 480.0, 490.0), vec4(500.0, 510.0, 520.0, 530.0),
  vec4(540.0, 550.0, 560.0, 570.0), vec4(580.0, 590.0, 600.0, 610.0),
  vec4(620.0, 630.0, 640.0, 650.0), vec4(660.0, 670.0, 680.0, 690.0),
  vec4(700.0, 710.0, 720.0, 730.0), vec4(740.0, 750.0, 760.0, 770.0),
  vec4(780.0,   0.0,   0.0,   0.0));

vec4 spectral_mask(int group)
{
  return group == spectral_groups-1 ? vec4(1.0, 0.0, 0.0, 0.0) : vec4(1.0);
}

vec4 spectral_fetch(sampler2D spectrum[spectral_groups], ivec2 pixel, int group)
{
  return texelFetch(spectrum[group], pixel, 0);
}

void spectral_store(writeonly image2D spectrum[spectral_groups], ivec2 pixel, int group, vec4 value)
{
  imageStore(spectrum[group], pixel, value * spectral_mask(group));
}

// CIE 1931 2-degree CMF approximation (380-780nm)
vec3 spectral_cmf1931(float lambda)
{
  float tx0 = (lambda-442.0)*((lambda < 442.0) ? 0.0624 : 0.0374);
  float tx1 = (lambda-599.8)*((lambda < 599.8) ? 0.0264 : 0.0323);
  float tx2 = (lambda-501.1)*((lambda < 501.1) ? 0.0490 : 0.0382);
  float ty0 = (lambda-568.8)*((lambda < 568.8) ? 0.0213 : 0.0247);
  float ty1 = (lambda-530.9)*((lambda < 530.9) ? 0.0613 : 0.0322);
  float tz0 = (lambda-437.0)*((lambda < 437.0) ? 0.0845 : 0.0278);
  float tz1 = (lambda-459.0)*((lambda < 459.0) ? 0.0385 : 0.0725);
  return vec3(
      0.362*exp(-0.5*tx0*tx0) + 1.056*exp(-0.5*tx1*tx1) - 0.065*exp(-0.5*tx2*tx2),
      0.821*exp(-0.5*ty0*ty0) + 0.286*exp(-0.5*ty1*ty1),
      1.217*exp(-0.5*tz0*tz0) + 0.681*exp(-0.5*tz1*tz1));
}

// Planck's Law blackbody radiation
float spectral_blackbody(float lambda_nm, float temperature_K)
{
  float c2 = 1.438777e7 / (lambda_nm * temperature_K);
  float l5 = lambda_nm * lambda_nm * lambda_nm * lambda_nm * lambda_nm;
  return (1.1910428e15 / l5) / (exp(c2) - 1.0);
}

vec4 spectral_blackbody(vec4 lambda_nm, float temperature_K)
{
  vec4 c2 = vec4(1.438777e7) / (lambda_nm * temperature_K);
  vec4 l5 = lambda_nm * lambda_nm * lambda_nm * lambda_nm * lambda_nm;
  return (vec4(1.1910428e15) / l5) / (exp(c2) - vec4(1.0));
}

// Precomputed CIE 1931 2-degree CMF vectors
const vec4 spectral_cmf_x[spectral_groups] = vec4[](
  vec4(0.000204, 0.001873, 0.011674, 0.049306),
  vec4(0.141073, 0.273393, 0.358601, 0.343750),
  vec4(0.281210, 0.191832, 0.100877, 0.032012),
  vec4(0.002355, 0.016480, 0.069841, 0.159607),
  vec4(0.282597, 0.433715, 0.602888, 0.772903),
  vec4(0.920461, 1.021039, 1.055926, 1.000205),
  vec4(0.853537, 0.656211, 0.454521, 0.283632),
  vec4(0.159458, 0.080766, 0.036855, 0.015152),
  vec4(0.005612, 0.001873, 0.000563, 0.000152),
  vec4(0.000037, 0.000008, 0.000002, 0.000000),
  vec4(0.000000, 0.000000, 0.000000, 0.000000));

const vec4 spectral_cmf_y[spectral_groups] = vec4[](
  vec4(0.000253, 0.000582, 0.001280, 0.002691),
  vec4(0.005408, 0.010384, 0.019054, 0.033415),
  vec4(0.056017, 0.089944, 0.139442, 0.213069),
  vec4(0.328117, 0.500611, 0.707113, 0.869052),
  vec4(0.954169, 0.994462, 0.991082, 0.950106),
  vec4(0.872134, 0.762587, 0.634136, 0.500339),
  vec4(0.373692, 0.263667, 0.175480, 0.110045),
  vec4(0.064982, 0.036117, 0.018890, 0.009297),
  vec4(0.004305, 0.001875, 0.000769, 0.000296),
  vec4(0.000108, 0.000037, 0.000012, 0.000004),
  vec4(0.000001, 0.000000, 0.000000, 0.000000));

const vec4 spectral_cmf_z[spectral_groups] = vec4[](
  vec4(0.006685, 0.020444, 0.060786, 0.205061),
  vec4(0.654302, 1.386823, 1.733914, 1.781385),
  vec4(1.671217, 1.294473, 0.809347, 0.465525),
  vec4(0.270763, 0.155962, 0.084991, 0.043036),
  vec4(0.020178, 0.008758, 0.003518, 0.001308),
  vec4(0.000450, 0.000143, 0.000042, 0.000012),
  vec4(0.000003, 0.000001, 0.000000, 0.000000),
  vec4(0.000000, 0.000000, 0.000000, 0.000000),
  vec4(0.000000, 0.000000, 0.000000, 0.000000),
  vec4(0.000000, 0.000000, 0.000000, 0.000000),
  vec4(0.000000, 0.000000, 0.000000, 0.000000));

// D65 reference illuminant (6504K daylight), normalized to unit Y sum
const vec4 spectral_d65_vec[spectral_groups] = vec4[](
  vec4(0.0047281, 0.0051699, 0.0078285, 0.0086543),
  vec4(0.0088382, 0.0081996, 0.0099191, 0.0110675),
  vec4(0.0111434, 0.0108640, 0.0109643, 0.0102915),
  vec4(0.0103427, 0.0101957, 0.0099106, 0.0101847),
  vec4(0.0098740, 0.0098399, 0.0094572, 0.0091104),
  vec4(0.0090586, 0.0083869, 0.0085117, 0.0084731),
  vec4(0.0082933, 0.0078762, 0.0079149, 0.0075676),
  vec4(0.0075853, 0.0077802, 0.0074026, 0.0065929),
  vec4(0.0067713, 0.0070305, 0.0058253, 0.0066085),
  vec4(0.0071003, 0.0060134, 0.0043894, 0.0063172),
  vec4(0.0059936, 0.0000000, 0.0000000, 0.0000000));
const float spectral_d65_white_Y = 10573.900214600024;

vec4 spectral_d65(int group)
{
  return spectral_d65_vec[group];
}

// CIE daylight basis S0/S1/S2 vectors per 4-wavelength group
const vec4 cie_d_s0_vec[spectral_groups] = vec4[](
  vec4(63.4, 65.8, 94.8, 104.8), vec4(105.9, 96.8, 113.9, 125.6),
  vec4(125.5, 121.3, 121.3, 113.5), vec4(113.1, 110.8, 106.5, 108.8),
  vec4(105.3, 104.4, 100.0, 96.0), vec4(95.1, 89.1, 90.5, 90.3),
  vec4(88.4, 84.0, 85.1, 81.9), vec4(82.6, 84.9, 81.3, 71.9),
  vec4(74.3, 76.4, 63.3, 71.7), vec4(77.0, 65.2, 47.7, 68.6),
  vec4(65.0, 0.0, 0.0, 0.0));

const vec4 cie_d_s1_vec[spectral_groups] = vec4[](
  vec4(38.5, 35.0, 43.4, 46.3), vec4(43.9, 37.1, 36.7, 35.9),
  vec4(32.6, 27.9, 24.3, 20.1), vec4(16.2, 13.2, 8.6, 6.1),
  vec4(4.2, 1.9, 0.0, -1.6), vec4(-3.5, -3.5, -5.8, -7.2),
  vec4(-8.6, -9.5, -10.9, -10.7), vec4(-12.0, -14.0, -13.6, -12.0),
  vec4(-13.3, -12.9, -10.6, -11.6), vec4(-12.2, -10.2, -7.8, -11.2),
  vec4(-10.4, 0.0, 0.0, 0.0));

const vec4 cie_d_s2_vec[spectral_groups] = vec4[](
  vec4(3.0, 1.2, -1.1, -0.5), vec4(-0.7, -1.2, -2.6, -2.9),
  vec4(-2.8, -2.6, -2.6, -1.8), vec4(-1.5, -1.3, -1.2, -1.0),
  vec4(-0.5, -0.3, 0.0, 0.2), vec4(0.5, 2.1, 3.2, 4.1),
  vec4(4.7, 5.1, 6.7, 7.3), vec4(8.6, 9.8, 10.2, 8.3),
  vec4(9.6, 8.5, 7.0, 7.6), vec4(8.0, 6.7, 5.2, 7.4),
  vec4(6.8, 0.0, 0.0, 0.0));

// CIE daylight basis S0/S1/S2 scalar arrays
const float cie_d_s0[41] = float[](
   63.4,  65.8,  94.8, 104.8, 105.9,  96.8, 113.9, 125.6, 125.5, 121.3,
  121.3, 113.5, 113.1, 110.8, 106.5, 108.8, 105.3, 104.4, 100.0,  96.0,
   95.1,  89.1,  90.5,  90.3,  88.4,  84.0,  85.1,  81.9,  82.6,  84.9,
   81.3,  71.9,  74.3,  76.4,  63.3,  71.7,  77.0,  65.2,  47.7,  68.6, 65.0
);
const float cie_d_s1[41] = float[](
   38.5,  35.0,  43.4,  46.3,  43.9,  37.1,  36.7,  35.9,  32.6,  27.9,
   24.3,  20.1,  16.2,  13.2,   8.6,   6.1,   4.2,   1.9,   0.0,  -1.6,
   -3.5,  -3.5,  -5.8,  -7.2,  -8.6,  -9.5, -10.9, -10.7, -12.0, -14.0,
  -13.6, -12.0, -13.3, -12.9, -10.6, -11.6, -12.2, -10.2,  -7.8, -11.2, -10.4
);
const float cie_d_s2[41] = float[](
    3.0,   1.2,  -1.1,  -0.5,  -0.7,  -1.2,  -2.6,  -2.9,  -2.8,  -2.6,
   -2.6,  -1.8,  -1.5,  -1.3,  -1.2,  -1.0,  -0.5,  -0.3,   0.0,   0.2,
    0.5,   2.1,   3.2,   4.1,   4.7,   5.1,   6.7,   7.3,   8.6,   9.8,
   10.2,   8.3,   9.6,   8.5,   7.0,   7.6,   8.0,   6.7,   5.2,   7.4,  6.8
);

// CIE Daylight locus M1, M2 weights from color temperature K
vec2 spectral_daylight_weights(float temperature_K)
{
  float T = clamp(temperature_K, 4000.0, 25000.0);
  float invT = 1.0 / T;
  float x = (T <= 7000.0)
    ? (((-4.6070e9 * invT + 2.9678e6) * invT + 99.11) * invT + 0.244063)
    : (((-2.0064e9 * invT + 1.9018e6) * invT + 247.48) * invT + 0.237040);
  float y = -3.0*x*x + 2.870*x - 0.275;
  float d = 0.2562*x - 0.7341*y + 0.0241;
  return (vec2(-1.7703, -31.4424) * x + vec2(5.9114, 30.0717) * y + vec2(-1.3515, 0.0300)) / d;
}

// Scene illuminant model: Planckian blackbody < 4000K, CIE daylight >= 4000K
const float spectral_illuminant_bb_max_cct = 4000.0;

vec2 spectral_illuminant_m(float cct)
{
  if (cct < spectral_illuminant_bb_max_cct) return vec2(0.0);
  return spectral_daylight_weights(cct);
}

float spectral_illuminant_spd(float cct, int tid, vec2 m)
{
  if (cct < 1.0) return 1.0;
  if (cct < spectral_illuminant_bb_max_cct)
  {
    float lambda = spectral_lambda0 + float(tid) * spectral_step_nm;
    return spectral_blackbody(lambda, cct) * (100.0 / spectral_blackbody(560.0, cct));
  }
  return cie_d_s0[tid] + m.x * cie_d_s1[tid] + m.y * cie_d_s2[tid];
}

vec4 spectral_illuminant_spd_vec(float cct, int group, vec2 m)
{
  if (cct < 1.0) return vec4(1.0);
  if (cct < spectral_illuminant_bb_max_cct)
  {
    vec4 l = spectral_lambda[group];
    vec4 bb = spectral_blackbody(l, cct);
    return bb * (100.0 / spectral_blackbody(560.0, cct));
  }
  return cie_d_s0_vec[group] + m.x * cie_d_s1_vec[group] + m.y * cie_d_s2_vec[group];
}
