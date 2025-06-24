#include "plan.h"
namespace minigraph {
uint64_t pattern_size() { return 3; }
static const Graph *graph;
using MiniGraphType = MiniGraphCostModel;
class Loop0 {
private:
  Context &ctx;

public:
  Loop0(Context &_ctx) : ctx{_ctx} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i0_id = r.begin(); i0_id < r.end(); i0_id++) { // loop-0begin
      VertexSet i0_adj = graph->N(i0_id);
      VertexSet s0 = i0_adj.bounded(i0_id);
      if (s0.size() == 0)
        continue;
      /* VSet(0, 0) In-Edges: 0 Restricts: 0 */
      for (size_t i1_idx = 0; i1_idx < s0.size(); i1_idx++) { // loop-1 begin
        const IdType i1_id = s0[i1_idx];
        VertexSet i1_adj = graph->N(i1_id);
        counter += s0.intersect_cnt(i1_adj, i1_adj.vid());
        /* VSet(1, 1) In-Edges: 0 1 Restricts: 0 1 */
      } // loop-1 end
    } // loop-0 end
  } // operator end
}; // Loop

void plan(const GraphType *_graph, Context &ctx) { // plan
  ctx.tick_begin = tbb::tick_count::now();
  ctx.iep_redundency = 0;
  graph = _graph;
  MiniGraphIF::DATA_GRAPH = graph;
  VertexSetType::MAX_DEGREE = graph->get_maxdeg();
  tbb::parallel_for(tbb::blocked_range<size_t>(0, graph->get_vnum()),
                    Loop0(ctx), tbb::simple_partitioner());
} // plan
} // namespace minigraph
