#include "plan.h"
namespace minigraph {
uint64_t pattern_size() { return 4; }
static const Graph *graph;
using MiniGraphType = MiniGraphCostModel;
class Loop1 {
private:
  Context &ctx;
  // Adjacent Lists
  VertexSet &i0_adj;
  // Iterate Set
  VertexSet &s0;

public:
  Loop1(Context &_ctx, VertexSet &_i0_adj, VertexSet &_s0)
      : ctx{_ctx}, i0_adj{_i0_adj}, s0{_s0} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i1_idx = r.begin(); i1_idx < r.end(); i1_idx++) { // loop-1begin
      const IdType i1_id = s0[i1_idx];
      VertexSet i1_adj = graph->N(i1_id);
      VertexSet s1 = i1_adj.subtract(i0_adj, i0_adj.vid());
      if (s1.size() == 0)
        continue;
      /* VSet(1, 1) In-Edges: 1 Restricts: 0 */
      VertexSet s2 = s0.subtract(i1_adj, i1_adj.vid());
      /* VSet(2, 1) In-Edges: 0 Restricts: 0 1 */
      for (size_t i2_idx = 0; i2_idx < s2.size(); i2_idx++) { // loop-2 begin
        const IdType i2_id = s2[i2_idx];
        VertexSet i2_adj = graph->N(i2_id);
        counter += s1.intersect_cnt(i2_adj);
        /* VSet(3, 2) In-Edges: 1 2 Restricts: 0 */
      } // loop-2 end
    } // loop-1 end
  } // operator end
}; // Loop

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
      if (s0.size() > 4 * 28) {
        tbb::parallel_for(tbb::blocked_range<size_t>(0, s0.size(), 1),
                          Loop1(ctx, i0_adj, s0), tbb::auto_partitioner());
        continue;
      }
      for (size_t i1_idx = 0; i1_idx < s0.size(); i1_idx++) { // loop-1 begin
        const IdType i1_id = s0[i1_idx];
        VertexSet i1_adj = graph->N(i1_id);
        VertexSet s1 = i1_adj.subtract(i0_adj, i0_adj.vid());
        if (s1.size() == 0)
          continue;
        /* VSet(1, 1) In-Edges: 1 Restricts: 0 */
        VertexSet s2 = s0.subtract(i1_adj, i1_adj.vid());
        /* VSet(2, 1) In-Edges: 0 Restricts: 0 1 */
        for (size_t i2_idx = 0; i2_idx < s2.size(); i2_idx++) { // loop-2 begin
          const IdType i2_id = s2[i2_idx];
          VertexSet i2_adj = graph->N(i2_id);
          counter += s1.intersect_cnt(i2_adj);
          /* VSet(3, 2) In-Edges: 1 2 Restricts: 0 */
        } // loop-2 end
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
