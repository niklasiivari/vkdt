// filmsim.glsl: pure colour and spectral math shared by every filmsim shader.

#extension GL_KHR_shader_subgroup_basic      : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable

#define SPECTRAL_DYE_LIGHT(RAW, DENS, DYE_R, DYE_G, DYE_B, FAC_R, FAC_G, FAC_B) \
  do { \
    RAW = vec3(0.0); \
    [[unroll]] \
    for(int i = 0; i < n_spectral_groups; i++) \
    { \
      vec4 ds = (DENS).x * DYE_R[i] + (DENS).y * DYE_G[i] + (DENS).z * DYE_B[i]; \
      vec4 light = exp2(-ds); \
      RAW.r += dot(light, FAC_R[i]); \
      RAW.g += dot(light, FAC_G[i]); \
      RAW.b += dot(light, FAC_B[i]); \
    } \
  } while(false)

// Select the reduction type and shared accumulator lanes.
#define SUBGROUP_REDUCE(TYPE, SWIZZLE, ZERO, VAL, RESULT) \
  do { \
    TYPE subsum = subgroupAdd(VAL); \
    if (subgroupElect()) shared_reduce_acc[gl_SubgroupID].SWIZZLE = subsum; \
    barrier(); \
    if (gl_SubgroupID == 0) \
    { \
      TYPE val = (gl_SubgroupInvocationID < gl_NumSubgroups) ? shared_reduce_acc[gl_SubgroupInvocationID].SWIZZLE : ZERO; \
      TYPE sum = subgroupAdd(val); \
      if (gl_SubgroupInvocationID == 0) RESULT = sum; \
    } \
    barrier(); \
  } while(false)

float envelope(float w)
{
  return 1000.0 * smoothstep(380.0, 400.0, w) * (1.0 - smoothstep(700.0, 730.0, w));
}

float norm_cdf(float z)
{
  return 1.0 / (1.0 + exp2(-z * (0.10294312 * z * z + 2.30220556)));
}

vec3 norm_cdf(vec3 z)
{
  return 1.0 / (1.0 + exp2(-z * (vec3(0.10294312) * z * z + vec3(2.30220556))));
}

vec3 gumbel_cdf(vec3 z)
{
  return exp2(-exp2(-(z * vec3(model_gumbel_scale) + vec3(model_gumbel_loc))));
}

vec3 dichroic_filters(float w)
{
  bool low = (w <= 550.0);
  vec3 edges = low ? vec3(607.0, 500.0, 516.0) : vec3(607.0, 610.0, 516.0);
  vec3 inv_w = vec3(0.176776695, 0.176776695, 0.11785113);
  vec3 cdf   = norm_cdf((vec3(w) - edges) * inv_w);
  return vec3(1.0 - cdf.x, low ? 1.0 - cdf.y : cdf.y, cdf.z);
}

uvec3 pcg3d(uvec3 v)
{
  v = v * 1664525u + 1013904223u;
  v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
  v ^= v >> 16u;
  v.x += v.y*v.z; v.y += v.z*v.x; v.z += v.x*v.y;
  return v;
}

vec3 hash3(ivec2 p, uint stream)
{
  return vec3(pcg3d(uvec3(uvec2(p), stream))) * (1.0/4294967296.0);
}
