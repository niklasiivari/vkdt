#include "modules/api.h"

int init(dt_module_t *module)
{
  module->committed_param_size = sizeof(int);
  return 0;
}

void commit_params(dt_graph_t *graph, dt_module_t *module)
{
  int *p = (int *)module->committed_param;
  p[0] = dt_module_param_int(module, dt_module_get_param(module->so, dt_token("observer")))[0];
}

void modify_roi_in(dt_graph_t *graph, dt_module_t *module)
{
  module->connector[0].roi = module->connector[1].roi;
}

void modify_roi_out(dt_graph_t *graph, dt_module_t *module)
{
  module->connector[1].roi = module->connector[0].roi;
}

void create_nodes(dt_graph_t *graph, dt_module_t *module)
{
  const int wd = module->connector[0].roi.wd;
  const int ht = module->connector[0].roi.ht;
  const int id = dt_node_add(graph, module, "s2rgb", "main", wd, ht, 1, 0, 0, 2,
      "input", "read", "rgba", "f16", dt_no_roi,
      "output", "write", "rgba", "f16", &module->connector[1].roi);
  dt_connector_copy(graph, module, 0, id, 0);
  dt_connector_copy(graph, module, 1, id, 1);
}
