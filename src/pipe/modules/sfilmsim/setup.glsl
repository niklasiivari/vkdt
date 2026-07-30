// Per-frame setup helpers.

const int s_model_film  = 0;
const int s_model_paper = 1;
const int s_sensitivity   = 0;
const int s_dye_density   = 1;
const int s_density_model = 2;

shared vec4 shared_model_centers[2][3];
shared vec4 shared_model_inv_sigmas[2][3];
shared vec4 shared_model_amps[2][3];
shared vec3 shared_model_gamma[2];
shared float shared_model_mix_ex[2];
shared vec3 shared_model_center_offset[2];
shared int shared_model_positive[2];
shared vec3 shared_model_scale[2][3];
shared vec3 shared_model_bias[2][3];
shared vec3 shared_model_dmax;

shared vec3 shared_coupler_col0, shared_coupler_col1, shared_coupler_col2;
shared vec3 shared_grain_area_fast, shared_grain_area_mid, shared_grain_area_slow;
shared vec3 shared_grain_uniformity;
shared vec3 shared_grain_dmin;
shared vec3 shared_halation_strength;

shared vec4 shared_expose_factor_r[n_spectral_groups];
shared vec4 shared_expose_factor_g[n_spectral_groups];
shared vec4 shared_expose_factor_b[n_spectral_groups];
shared vec4 shared_expose_ae_bb;
shared float shared_expose_autoexp_norm;
shared vec4 shared_reduce_acc[32];

shared mat3 shared_M;
shared vec3 shared_c_ref;
shared vec3 shared_Kr;
shared vec3 shared_langmuir_k_dmax;
shared vec3 shared_langmuir_num_dmax;

shared vec4 shared_scan_dye_r[n_spectral_groups], shared_scan_dye_g[n_spectral_groups], shared_scan_dye_b[n_spectral_groups];
shared vec4 shared_scan_radiance[n_spectral_groups];
shared float shared_scan_autoexp, shared_scan_autoexp_norm;
shared vec2 shared_m_scan;
shared float shared_glare_mean;
shared uint shared_glare_seed;

shared vec4 shared_enlarger_dye_r[n_spectral_groups], shared_enlarger_dye_g[n_spectral_groups], shared_enlarger_dye_b[n_spectral_groups];
shared vec4 shared_enlarger_factor_r[n_spectral_groups], shared_enlarger_factor_g[n_spectral_groups], shared_enlarger_factor_b[n_spectral_groups];
shared vec3 shared_preflash;
shared float shared_enlarger_autoexp, shared_enlarger_autoexp_norm;

float gumbel_cdf(float z)
{
  return exp2(-exp2(-(model_gumbel_scale * z + model_gumbel_loc)));
}

float eval_channel_density_at_y0(int slot, int ch, float o, float mix_ex)
{
  float sgn = (shared_model_positive[slot] != 0) ? -1.0 : 1.0;
  float d = 0.0;
  [[unroll]]
  for(int l = 0; l < 3; l++)
  {
    float g = shared_model_gamma[slot][l];
    float z = clamp(sgn * (-(shared_model_centers[slot][l][ch] + g * o)) * shared_model_inv_sigmas[slot][l][ch], -10.0, 10.0);
    float cdf = norm_cdf(z);
    if(mix_ex > 0.0) cdf = mix(cdf, gumbel_cdf(z), mix_ex);
    d += shared_model_amps[slot][l][ch] * cdf;
  }
  return d;
}

float solve_exhaustion_center_offset(int slot, int ch)
{
  float target = eval_channel_density_at_y0(slot, ch, 0.0, 0.0);
  float lo = -0.25, hi = 0.25;
  float r_lo = eval_channel_density_at_y0(slot, ch, lo, shared_model_mix_ex[slot]) - target;
  float r_hi = eval_channel_density_at_y0(slot, ch, hi, shared_model_mix_ex[slot]) - target;
  [[loop]] for(int e = 0; e < 12 && r_lo * r_hi > 0.0; e++)
  {
    lo *= 2.0; hi *= 2.0;
    r_lo = eval_channel_density_at_y0(slot, ch, lo, shared_model_mix_ex[slot]) - target;
    r_hi = eval_channel_density_at_y0(slot, ch, hi, shared_model_mix_ex[slot]) - target;
  }
  if(r_lo * r_hi > 0.0) return 0.0;
  [[loop]] for(int b = 0; b < 30; b++)
  {
    float mid = 0.5 * (lo + hi);
    float r_mid = eval_channel_density_at_y0(slot, ch, mid, shared_model_mix_ex[slot]) - target;
    if((r_lo < 0.0) == (r_mid < 0.0)) { lo = mid; r_lo = r_mid; } else { hi = mid; }
  }
  return 0.5 * (lo + hi);
}

void setup_density_model_slot(int slot, int stock, vec3 gamma, float mix_ex, bool phys)
{
  int tid = int(gl_LocalInvocationIndex);
  int y_row = stock * 3 + s_density_model;

  if (tid < 19)
  {
    int x_idx = (tid < 9)  ? (tid / 3) * 4 + (tid % 3) :
                (tid == 9) ? 12 :
                (phys && tid <= 18) ? (tid - 10) + 13 : -1;

    if (x_idx >= 0)
    {
      vec4 val = texelFetch(img_filmsim, ivec2(x_idx, y_row), 0);
      if (tid < 9)
      {
        int l = tid / 3, t = tid % 3;
        if (t == 0)      shared_model_centers[slot][l]    = val;
        else if (t == 1) shared_model_amps[slot][l]       = val;
        else             shared_model_inv_sigmas[slot][l] = val;
      }
      else if (tid == 9)
      {
        shared_model_positive[slot] = val.a > 0.5 ? 1 : 0;
        if (phys) shared_model_dmax = val.rgb;
      }
      else if (phys)
      {
        if (tid == 10)      shared_coupler_col0       = val.rgb;
        else if (tid == 11) shared_coupler_col1       = val.rgb;
        else if (tid == 12) shared_coupler_col2       = val.rgb;
        else if (tid == 13) shared_grain_area_fast    = val.rgb;
        else if (tid == 14) shared_grain_area_mid     = val.rgb;
        else if (tid == 15) shared_grain_area_slow    = val.rgb;
        else if (tid == 16) shared_grain_uniformity   = val.rgb;
        else if (tid == 17) shared_halation_strength  = val.rgb;
        else if (tid == 18) shared_grain_dmin         = val.rgb;
      }
    }
  }

  if (tid == 0)
  {
    shared_model_gamma[slot] = max(gamma, vec3(1e-3));
    shared_model_mix_ex[slot] = clamp(mix_ex, 0.0, 1.0);
    shared_model_center_offset[slot] = vec3(0.0);
  }
  barrier();

  if(shared_model_mix_ex[slot] > 0.0)
  {
    if(tid < 3)
      shared_model_center_offset[slot][tid] = solve_exhaustion_center_offset(slot, tid);
    barrier();
  }

  if(tid < 3)
  {
    int l = tid;
    float sgn = (shared_model_positive[slot] != 0) ? -1.0 : 1.0;
    vec3 centers = shared_model_centers[slot][l].rgb;
    vec3 inv_sigmas = shared_model_inv_sigmas[slot][l].rgb;
    float g = shared_model_gamma[slot][l];
    vec3 offset = shared_model_center_offset[slot];

    shared_model_scale[slot][l] = sgn * g * inv_sigmas;
    shared_model_bias[slot][l]  = -sgn * (centers + g * offset) * inv_sigmas;
  }
  barrier();
}

void setup_film_density_model(int film)
{
  setup_density_model_slot(s_model_film, film,
      vec3(params.g_fast, params.g_slow, params.g_slow),
      params.exhaust, true);
}

void setup_paper_density_model(int paper)
{
  setup_density_model_slot(s_model_paper, paper,
      params.gamma_paper * vec3(params.g_fast_p, params.g_slow_p, params.g_slow_p),
      params.p_exh, false);
}

void setup_coupler_matrix()
{
  int tid = int(gl_LocalInvocationIndex);
  if (tid == 0)
  {
    mat3 M_raw = mat3(shared_coupler_col0, shared_coupler_col1, shared_coupler_col2);
    vec3 c_ref = M_raw * (0.5 * shared_model_dmax);
    vec3 lang_k = max(vec3(params.langmuir_r, params.langmuir_g, params.langmuir_b), vec3(1e-3));
    shared_M = M_raw * params.cp_amt;
    shared_c_ref = c_ref;
    shared_Kr = lang_k * (2.0 * c_ref);
    shared_langmuir_k_dmax = lang_k * shared_model_dmax;
    shared_langmuir_num_dmax = (lang_k + 0.5) * shared_model_dmax;
  }
  barrier();
}

void setup_expose_film(int film)
{
  int tid = int(gl_LocalInvocationIndex);
  if (tid < n_spectral_groups)
  {
    shared_expose_factor_r[tid] = vec4(0.0);
    shared_expose_factor_g[tid] = vec4(0.0);
    shared_expose_factor_b[tid] = vec4(0.0);
  }
  vec4 ref_tx = texelFetch(img_filmsim, ivec2(22, film * 3 + s_density_model), 0);
  float ref_cct = ref_tx.w;
  // ref_cct is the film stock's reference illuminant (its calibration white point).
  // The spectral connector delivers scene radiance normalized under reference D65.
  // We compute exposure normalization at runtime by integrating sensitivity
  // against the stock's reference illuminant SPD.
  float film_cct = (params.film_ill != 0.0) ? params.film_ill : ref_cct;
  vec2 m_film = spectral_illuminant_m(film_cct);
  vec2 m_ref  = spectral_illuminant_m(ref_cct);
  const float d65_cct = 6504.0;
  vec2 m_d65 = spectral_illuminant_m(d65_cct);
  barrier();

  // Pass 1: expose_norm = integral(sensitivity * ref_ill * envelope)
  vec3 norm_acc = vec3(0.0);
  if (tid < n_expose_bands)
  {
    float lambda = 380.0 + tid * 10.0;
    vec3 log_sensitivity = texelFetch(img_filmsim, ivec2(tid * 2, film * 3 + s_sensitivity), 0).rgb;
    vec3 sensitivity = mix(exp2(log_sensitivity * log2_10), vec3(0.0), isnan(log_sensitivity));
    float ref_spd = spectral_illuminant_spd(ref_cct, tid, m_ref);
    norm_acc = sensitivity * envelope(lambda) * ref_spd;
  }
  SUBGROUP_REDUCE(vec3, xyz, vec3(0.0), norm_acc, shared_expose_ae_bb.yzw);

  // Pass 2: per-band factor and autoexposure metering
  // factor[i] = sensitivity[i] * envelope[i] * (film_ill / d65)[i] / expose_norm
  float ae_val = 0.0;
  if (tid < n_expose_bands)
  {
    float lambda = 380.0 + tid * 10.0;
    vec3 log_sensitivity = texelFetch(img_filmsim, ivec2(tid * 2, film * 3 + s_sensitivity), 0).rgb;
    vec3 sensitivity = mix(exp2(log_sensitivity * log2_10), vec3(0.0), isnan(log_sensitivity));
    vec3 expose_norm = max(shared_expose_ae_bb.yzw, vec3(1e-6));
    vec3 env_sens = sensitivity * envelope(lambda);
    float film_spd = spectral_illuminant_spd(film_cct, tid, m_film);
    float d65_spd  = spectral_illuminant_spd(d65_cct, tid, m_d65);
    vec3 factor = env_sens * (film_spd / max(d65_spd, 1e-6)) / expose_norm;
    shared_expose_factor_r[tid/4][tid%4] = factor.r;
    shared_expose_factor_g[tid/4][tid%4] = factor.g;
    shared_expose_factor_b[tid/4][tid%4] = factor.b;
    ae_val = dot(factor * d65_spd, vec3(1.0/3.0));
  }

  SUBGROUP_REDUCE(float, x, 0.0, ae_val, shared_expose_ae_bb.x);

  if (tid == 0)
  {
    // 0.18 maps 18% grey to 0 EV on the D-logE curve
    shared_expose_autoexp_norm = max(1e-6, 0.18 * shared_expose_ae_bb.x / spectral_d65_white_Y);
    prep.film.hl_boost_k_gain = 0.003224982 * (exp2(params.hl_boost_ev) - 1.0);
  }
  barrier();
}

vec3 filter_neutral(vec2 extra_my)
{
  return clamp(vec3(params.filter_c,
      clamp(params.filter_m, 0, 1) + 0.1*params.tune_m + extra_my.x,
      clamp(params.filter_y, 0, 1) + 0.1*params.tune_y + extra_my.y),
      vec3(0.0), vec3(1.0));
}

void setup_enlarger_illuminant(int film, int paper)
{
  int tid = int(gl_LocalInvocationIndex);
  if (tid < n_spectral_groups)
  {
    shared_enlarger_dye_r[tid] = vec4(0.0);
    shared_enlarger_dye_g[tid] = vec4(0.0);
    shared_enlarger_dye_b[tid] = vec4(0.0);
    shared_enlarger_factor_r[tid] = vec4(0.0);
    shared_enlarger_factor_g[tid] = vec4(0.0);
    shared_enlarger_factor_b[tid] = vec4(0.0);
  }
  barrier();
  vec3 pf_val = vec3(0.0);
  float ae_val = 0.0;
  vec3 neutral_main = filter_neutral(vec2(0.0));
  vec3 neutral_pf   = filter_neutral(vec2(params.pf_m, params.pf_y));

  if (tid < n_spectral_bands)
  {
    float lambda = 380.0 + tid * 10.0;
    vec3 log_sensitivity = texelFetch(img_filmsim, ivec2(tid * 2, paper * 3 + s_sensitivity), 0).rgb;
    vec3 sensitivity = mix(exp2(log_sensitivity * log2_10), vec3(0.0), isnan(log_sensitivity));

    vec4 dye_density = vec4(0.0);
    bool missing = false;
    float base_light = 1.0;
    if(film >= 0 && params.process != s_process_print_neg)
    {
      dye_density = texelFetch(img_filmsim, ivec2(tid * 2, film * 3 + s_dye_density), 0);
      missing = any(isnan(dye_density.xyz));
      dye_density = mix(dye_density, vec4(0.0), isnan(dye_density));
      dye_density.xyz *= log2_10;
      dye_density = clamp(dye_density, vec4(0.0), vec4(1e5));
      base_light = exp2(-dye_density.w * dye_density_min_factor_film * log2_10);
    }

    float illuminant = spectral_blackbody(lambda, enlarger_lamp_K) * kg3_transmittance[tid];
    float common_light = illuminant * base_light * exp2(params.ev_paper);

    vec3 dich = dichroic_filters(lambda);
    vec3 f_main = mix(vec3(1.0), dich, neutral_main);
    float light_main = f_main.x * f_main.y * f_main.z * common_light;
    vec3 factor = missing ? vec3(0.0) : sensitivity * light_main;

    vec3 f_pf = mix(vec3(1.0), dich, neutral_pf);
    float light_pf = f_pf.x * f_pf.y * f_pf.z * common_light * exp2(params.pf_ev);
    pf_val = (missing || params.preflash <= 0) ? vec3(0.0) : sensitivity * light_pf;

    ae_val = dot(factor, vec3(1.0/3.0)) * exp2(-params.ev_paper);

    shared_enlarger_dye_r[tid/4][tid%4] = dye_density.x;
    shared_enlarger_dye_g[tid/4][tid%4] = dye_density.y;
    shared_enlarger_dye_b[tid/4][tid%4] = dye_density.z;
    shared_enlarger_factor_r[tid/4][tid%4] = factor.r;
    shared_enlarger_factor_g[tid/4][tid%4] = factor.g;
    shared_enlarger_factor_b[tid/4][tid%4] = factor.b;
  }

  SUBGROUP_REDUCE(vec3, xyz, vec3(0.0), pf_val, shared_preflash);
  SUBGROUP_REDUCE(float, x, 0.0, ae_val, shared_enlarger_autoexp);
  if (tid == 0)
  {
    shared_enlarger_autoexp_norm = max(1e-6, 0.18 * shared_enlarger_autoexp);
  }
  barrier();
}

void setup_scan_illuminant()
{
  int tid = int(gl_LocalInvocationIndex);
  if (tid < n_spectral_groups)
  {
    shared_scan_dye_r[tid] = vec4(0.0);
    shared_scan_dye_g[tid] = vec4(0.0);
    shared_scan_dye_b[tid] = vec4(0.0);
    shared_scan_radiance[tid] = vec4(0.0);
  }
  if (tid == 0)
  {
    shared_m_scan = spectral_illuminant_m(params.scan_ill);
  }
  barrier();
  float ae_val = 0.0;
  if (tid < n_spectral_bands)
  {
    float lambda = 380.0 + tid * 10.0;
    const int paper = s_paper_offset + params.paper;
    const int film  = params.film;
    int dye_stock = (params.process != s_process_scan_neg) ? paper : film;

    vec4 dye_density = texelFetch(img_filmsim, ivec2(tid * 2, dye_stock * 3 + s_dye_density), 0);
    bool missing = any(isnan(dye_density.xyz));
    dye_density = mix(dye_density, vec4(0.0), isnan(dye_density));
    dye_density.xyz *= log2_10;
    dye_density.xyz = min(dye_density.xyz, 300.0);

    float scan_illuminant = spectral_illuminant_spd(params.scan_ill, tid, shared_m_scan);

    bool is_positive_stock = false;
    if(params.process == s_process_scan_neg)
      is_positive_stock = (shared_model_positive[s_model_film] != 0);
    vec3 neutral_main = is_positive_stock ? filter_neutral(vec2(0.0)) : vec3(0.0);
    vec3 dich = dichroic_filters(lambda);
    vec3 f_main = mix(vec3(1.0), dich, neutral_main);
    float filter_light = f_main.x * f_main.y * f_main.z;

    float base_scale = (params.process != s_process_scan_neg) ? params.p_base : dye_density_min_factor_film;
    float base_density = dye_density.w * base_scale;
    float base_light = exp2(-base_density * log2_10);
    shared_scan_dye_r[tid/4][tid%4] = dye_density.x;
    shared_scan_dye_g[tid/4][tid%4] = dye_density.y;
    shared_scan_dye_b[tid/4][tid%4] = dye_density.z;
    shared_scan_radiance[tid/4][tid%4] = missing ? 0.0 : scan_illuminant * filter_light * base_light;

    ae_val = scan_illuminant * filter_light * spectral_cmf1931(lambda).y * base_light;
    if(missing) ae_val = 0.0;
  }

  SUBGROUP_REDUCE(float, x, 0.0, ae_val, shared_scan_autoexp);

  if (tid == 0)
  {
    shared_glare_mean = (params.process == s_process_scan_neg) ? 0.0 : params.glare * 0.01;
    shared_glare_seed = (uint(global.hash) * 61u + uint(global.frame)) ^ 0xa511e9b3u;
  }
  else if (tid == 1)
  {
    float norm = max(shared_scan_autoexp, 1e-5);
    shared_scan_autoexp_norm = norm * spectral_step_nm;
  }
  barrier();
}
