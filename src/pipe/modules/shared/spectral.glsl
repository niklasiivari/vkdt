// 40 linear samples at 10nm intervals (380nm to 770nm).
// Stored as 10 rgba:f16 images.

const int spectral_samples = 40;
const int spectral_groups = 10;
const float spectral_lambda0 = 380.0;
const float spectral_step_nm = 10.0;

vec4 spectral_lambda(uint group)
{
  return vec4(380.0, 390.0, 400.0, 410.0) + vec4(float(group) * 40.0);
}

#define SPECTRAL_LOOP(g) for (int g = 0; g < spectral_groups; g++)

ivec2 nm_to_spectral_idx(float nm)
{
  int s = int(clamp((nm - spectral_lambda0) / spectral_step_nm, 0.0, float(spectral_samples - 1)));
  return ivec2(s / 4, s % 4);
}

vec4 spectral_fetch(sampler2D spectrum[spectral_groups], ivec2 pixel, int group)
{
  return texelFetch(spectrum[group], pixel, 0);
}

float spectral_fetch_sample(sampler2D spectrum[spectral_groups], ivec2 pixel, int sample_idx)
{
  vec4 g = spectral_fetch(spectrum, pixel, sample_idx / 4);
  return g[sample_idx % 4];
}

void spectral_store(writeonly image2D spectrum[spectral_groups], ivec2 pixel, int group, vec4 value)
{
  imageStore(spectrum[group], pixel, value);
}

// CIE 1931 2-degree CMF approximation (380-770nm)
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

#include "shared/cie.glsl"

vec4 spectral_d65(int group)
{
  return spectral_d65_vec[group];
}

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
    vec4 l = spectral_lambda(group);
    vec4 bb = spectral_blackbody(l, cct);
    return bb * (100.0 / spectral_blackbody(560.0, cct));
  }
  return cie_d_s0_vec[group] + m.x * cie_d_s1_vec[group] + m.y * cie_d_s2_vec[group];
}
