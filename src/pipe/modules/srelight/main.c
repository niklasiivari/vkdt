#include "modules/api.h"

int init(dt_module_t *module)
{
  module->committed_param_size = 11 * sizeof(float);
  return 0;
}

void commit_params(dt_graph_t *graph, dt_module_t *module)
{
  float *f = (float *)module->committed_param;
  int *i = (int *)module->committed_param;
  i[0]  = dt_module_param_int  (module, dt_module_get_param(module->so, dt_token("source")))[0];
  f[1]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("mix")))[0];
  f[2]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("d cct")))[0];
  f[3]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("bb cct")))[0];
  f[4]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("led cct")))[0];
  f[5]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("led cri")))[0];
  f[6]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("led pmp")))[0];
  i[7]  = dt_module_param_int  (module, dt_module_get_param(module->so, dt_token("discharg")))[0];
  f[8]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("laser_l1")))[0];
  f[9]  = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("laser_l2")))[0];
  f[10] = dt_module_param_float(module, dt_module_get_param(module->so, dt_token("bandwdth")))[0];
}

void modify_roi_in(dt_graph_t *graph, dt_module_t *module)
{
  module->connector[0].roi = module->connector[1].roi;
}

void modify_roi_out(dt_graph_t *graph, dt_module_t *module)
{
  module->connector[1].roi = module->connector[0].roi;
  module->connector[1].array_length = 11;
}

void create_nodes(dt_graph_t *graph, dt_module_t *module)
{
  const int wd = module->connector[0].roi.wd;
  const int ht = module->connector[0].roi.ht;
  const int id = dt_node_add(graph, module, "srelight", "main", wd, ht, 1, 0, 0, 2,
      "input", "read", "rgba", "f16", dt_no_roi,
      "output", "write", "rgba", "f16", &module->connector[1].roi);
  dt_connector_copy(graph, module, 0, id, 0);
  dt_connector_copy(graph, module, 1, id, 1);
}
