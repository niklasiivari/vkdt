#include "modules/api.h"
#include <math.h>

static float
auto_temp_kelvin(const float position, const uint32_t nbands)
{
  const float m_lo = 1e6f/15000.0f, m_hi = 1e6f/2000.0f;
  return 1e6f/(m_lo + CLAMP(position, 0.0f, 1.0f)*(m_hi-m_lo));
}

int init(dt_module_t *module)
{
  module->committed_param_size = 12 * sizeof(float);
  return 0;
}

void modify_roi_in(dt_graph_t *graph, dt_module_t *module)
{
  module->connector[0].roi = module->connector[1].roi;
  module->connector[2].roi.marker = s_roi_mark_uninited;
  module->connector[3].roi.marker = s_roi_mark_uninited;
}

void modify_roi_out(dt_graph_t *graph, dt_module_t *module)
{
  module->connector[1].roi = module->connector[0].roi;
  module->connector[1].array_length = 10;
}

void commit_params(dt_graph_t *graph, dt_module_t *module)
{
  const dt_image_params_t *img_param = dt_module_get_input_img_param(graph, module, dt_token("input"));

  float *f = (float *)module->committed_param;
  const int modeid = dt_module_get_param(module->so, dt_token("mode"));
  const int tempid = dt_module_get_param(module->so, dt_token("temp"));
  const int expid  = dt_module_get_param(module->so, dt_token("exposure"));
  const int tintid = dt_module_get_param(module->so, dt_token("tint"));

  const int mode = (modeid >= 0 && dt_module_param_int(module, modeid)) ? dt_module_param_int(module, modeid)[0] : 0;
  const float t  = (tempid >= 0 && dt_module_param_float(module, tempid)) ? dt_module_param_float(module, tempid)[0] : 6504.0f;
  const float exposure = (expid >= 0 && dt_module_param_float(module, expid)) ? dt_module_param_float(module, expid)[0] : 0.0f;
  const float tint = (tintid >= 0 && dt_module_param_float(module, tintid)) ? dt_module_param_float(module, tintid)[0] : 0.0f;

  if(mode == 1) // Rec.2020 RGB
  {
    f[0] = 0.0f;
    f[1] = exp2f(exposure);
    f[2] = 6504.0f;
    f[3] = 1.0f; // mode 1 flag for shader
  }
  else // Camera SSF (sclut)
  {
    if(t <= 0.0f)
    {
      f[0] = -1.0f; // Signal shader to compute autotemp
      if(dt_connected(module->connector+2))
        module->flags |= s_module_request_write_sink;
    }
    else
    {
      const float m0 = 1e6f/15000.0f, m1 = 1e6f/2000.0f;
      f[0] = CLAMP((1e6f/CLAMP(t, 2000.0f, 15000.0f)-m0)/(m1-m0), 0.0f, 1.0f);
    }
    f[1] = exp2f(exposure);
    f[2] = CLAMP(t, 2000.0f, 15000.0f);
    f[3] = 0.0f; // mode 0 flag for shader
  }

  f[4] = tint;
  f[5] = 0.0f;
  f[6] = 0.0f;
  f[7] = 0.0f;

  float auto_wb[3] = { 1.0f, 1.0f, 1.0f };
  if(img_param)
  {
    auto_wb[0] = img_param->whitebalance[0];
    auto_wb[1] = img_param->whitebalance[1];
    auto_wb[2] = img_param->whitebalance[2];
  }
  if(!(auto_wb[0] > 0.0f) || !(auto_wb[1] > 0.0f) || !(auto_wb[2] > 0.0f))
    auto_wb[0] = auto_wb[1] = auto_wb[2] = 1.0f;

  f[8]  = auto_wb[0] / auto_wb[1];
  f[9]  = 1.0f;
  f[10] = auto_wb[2] / auto_wb[1];
  f[11] = 1.0f;
}

void animate(dt_graph_t *graph, dt_module_t *module)
{
  const int modeid = dt_module_get_param(module->so, dt_token("mode"));
  const int mode = (modeid >= 0 && dt_module_param_int(module, modeid)) ? dt_module_param_int(module, modeid)[0] : 0;
  if(mode == 0)
  {
    const int tempid = dt_module_get_param(module->so, dt_token("temp"));
    const float *temp = tempid >= 0 ? dt_module_param_float(module, tempid) : 0;
    if(temp && temp[0] <= 0.0f && dt_connected(module->connector+2))
      module->flags |= s_module_request_write_sink;
  }
}

dt_graph_run_t check_params(
    dt_module_t *module,
    uint32_t     parid,
    uint32_t     num,
    void        *oldval)
{
  const int modeid = dt_module_get_param(module->so, dt_token("mode"));
  if(modeid >= 0 && parid == (uint32_t)modeid)
  {
    const int *p_mode = dt_module_param_int(module, parid);
    if(oldval && p_mode && *(int*)oldval != p_mode[0])
      return s_graph_run_all; // topology re-link if autotemp node is added/removed
  }

  const int tempid = dt_module_get_param(module->so, dt_token("temp"));
  if(tempid >= 0 && parid == (uint32_t)tempid)
  {
    const float *p_temp = dt_module_param_float(module, parid);
    if(p_temp && p_temp[0] <= 0.0f)
    {
      const int mode = (modeid >= 0 && dt_module_param_int(module, modeid)) ? dt_module_param_int(module, modeid)[0] : 0;
      if(mode == 0) module->flags |= s_module_request_write_sink;
    }
  }
  return s_graph_run_record_cmd_buf;
}

void write_sink(
    dt_module_t            *module,
    void                   *buf,
    dt_write_sink_params_t *p)
{
  const float position = ((const float *)buf)[0];
  const int tempid = dt_module_get_param(module->so, dt_token("temp"));
  float *temp = tempid >= 0 ? (float *)dt_module_param_float(module, tempid) : 0;
  if(!temp || temp[0] > 0.0f || !(position >= 0.0f && position <= 1.0f)) return;

  const uint32_t clut_ht = module->connector[2].roi.full_ht;
  const uint32_t nbands  = clut_ht ? module->connector[2].roi.full_wd / (2 * clut_ht) : 9;
  temp[0] = auto_temp_kelvin(position, nbands);
  module->flags &= ~s_module_request_write_sink;
  module->graph->runflags |= s_graph_run_record_cmd_buf;
}

void create_nodes(dt_graph_t *graph, dt_module_t *module)
{
  const int modeid = dt_module_get_param(module->so, dt_token("mode"));
  const int mode = (modeid >= 0 && dt_module_param_int(module, modeid)) ? dt_module_param_int(module, modeid)[0] : 0;
  int have_sclut = dt_connected(module->connector+2);
  int have_pick  = dt_connected(module->connector+3);

  int id_auto = -1;
  if(mode == 0 && have_sclut)
  {
    const dt_roi_t tiny = { .wd = 1, .ht = 1 };
    const int push = have_pick ? 1 : 0;
    id_auto = dt_node_add(graph, module, "rgb2s", "autotemp", 1, 1, 1, sizeof(push), &push, 3,
        "sclut", "read", "rgba", "f32", dt_no_roi,
        "temp", "write", "y", "f32", &tiny,
        "picked", "read", "r", have_pick ? dt_token_str(module->connector[3].format) : "f16", dt_no_roi);
    const int id_sink = dt_node_add(graph, module, "rgb2s", "sink", 1, 1, 1, 0, 0, 1,
        "temp", "sink", "y", "f32", dt_no_roi);
    dt_connector_copy(graph, module, 2, id_auto, 0);
    if(have_pick) dt_connector_copy(graph, module, 3, id_auto, 2);
    else          dt_connector_copy(graph, module, 0, id_auto, 2);
    CONN(dt_node_connect(graph, id_auto, 1, id_sink, 0));
  }

  const int id = dt_node_add(graph, module, "rgb2s", "main", module->connector[0].roi.wd,
      module->connector[0].roi.ht, 1, 0, 0, 4,
      "input", "read", "rgba", "f16", dt_no_roi,
      "output", "write", "rgba", "f16", &module->connector[1].roi,
      "sclut", "read", "rgba", "f32", dt_no_roi,
      "autotemp", "read", "y", "f32", dt_no_roi);
  dt_connector_copy(graph, module, 0, id, 0);
  dt_connector_copy(graph, module, 1, id, 1);
  if(have_sclut) dt_connector_copy(graph, module, 2, id, 2);
  else           dt_connector_copy(graph, module, 0, id, 2);
  if(id_auto >= 0) CONN(dt_node_connect(graph, id_auto, 1, id, 3));
  else             dt_connector_copy(graph, module, 0, id, 3); // dummy
}
