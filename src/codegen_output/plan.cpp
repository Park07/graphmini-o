#include "plan.h"
namespace minigraph {
uint64_t pattern_size() { return 5; }
static const Graph *graph;
using MiniGraphType = MiniGraphCostModel;
class Loop2 {
private:
  Context &ctx;
  // Iterate Set
  VertexSet &s1;
  // MiniGraphs Indices
  // MiniGraphs
  MiniGraphEager &m1;

public:
  Loop2(Context &_ctx, VertexSet &_s1, MiniGraphEager &_m1)
      : ctx{_ctx}, s1{_s1}, m1{_m1} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i2_idx = r.begin(); i2_idx < r.end(); i2_idx++) { // loop-2begin
      const IdType i2_id = s1[i2_idx];
      VertexSet m1_adj = m1.N(i2_idx);
      VertexSet s2 = m1_adj.bounded(i2_id);
      if (s2.size() == 0)
        continue;
      /* VSet(2, 2) In-Edges: 0 1 2 Restricts: 0 1 2 */
      auto m1_s2 = m1.indices(s2);
      for (size_t i3_idx = 0; i3_idx < s2.size(); i3_idx++) { // loop-3 begin
        const IdType i3_id = s2[i3_idx];
        VertexSet m1_adj = m1.N(m1_s2[i3_idx]);
        counter += s2.intersect_cnt(m1_adj, m1_adj.vid());
        /* VSet(3, 3) In-Edges: 0 1 2 3 Restricts: 0 1 2 3 */
      } // loop-3 end
    } // loop-2 end
  } // operator end
}; // Loop

class Loop1 {
private:
  Context &ctx;
  // Iterate Set
  VertexSet &s0;
  // MiniGraphs Indices
  // MiniGraphs
  MiniGraphEager &m0;

public:
  Loop1(Context &_ctx, VertexSet &_s0, MiniGraphEager &_m0)
      : ctx{_ctx}, s0{_s0}, m0{_m0} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i1_idx = r.begin(); i1_idx < r.end(); i1_idx++) { // loop-1begin
      const IdType i1_id = s0[i1_idx];
      VertexSet m0_adj = m0.N(i1_idx);
      VertexSet s1 = m0_adj.bounded(i1_id);
      if (s1.size() == 0)
        continue;
      /* VSet(1, 1) In-Edges: 0 1 Restricts: 0 1 */
      MiniGraphEager m1(true, false);
      /* Vertices = VSet(1) In-Edges: 0 1 Restricts: 0 1  | Intersect = VSet(1)
       * In-Edges: 0 1 Restricts: 0 1 */
      m1.build(&m0, s1, s1, s1);
      // skip building indices for m1 because they can be obtained directly
      if (s1.size() > 4 * 6) {
        tbb::parallel_for(tbb::blocked_range<size_t>(0, s1.size(), 1),
                          Loop2(ctx, s1, m1), tbb::auto_partitioner());
        continue;
      }
      for (size_t i2_idx = 0; i2_idx < s1.size(); i2_idx++) { // loop-2 begin
        const IdType i2_id = s1[i2_idx];
        VertexSet m1_adj = m1.N(i2_idx);
        VertexSet s2 = m1_adj.bounded(i2_id);
        if (s2.size() == 0)
          continue;
        /* VSet(2, 2) In-Edges: 0 1 2 Restricts: 0 1 2 */
        auto m1_s2 = m1.indices(s2);
        for (size_t i3_idx = 0; i3_idx < s2.size(); i3_idx++) { // loop-3 begin
          const IdType i3_id = s2[i3_idx];
          VertexSet m1_adj = m1.N(m1_s2[i3_idx]);
          counter += s2.intersect_cnt(m1_adj, m1_adj.vid());
          /* VSet(3, 3) In-Edges: 0 1 2 3 Restricts: 0 1 2 3 */
        } // loop-3 end
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
      MiniGraphEager m0(true, false);
      /* Vertices = VSet(0) In-Edges: 0 Restricts: 0  | Intersect = VSet(0)
       * In-Edges: 0 Restricts: 0 */
      m0.build(s0, s0, s0);
      // skip building indices for m0 because they can be obtained directly
      if (s0.size() > 4 * 6) {
        tbb::parallel_for(tbb::blocked_range<size_t>(0, s0.size(), 1),
                          Loop1(ctx, s0, m0), tbb::auto_partitioner());
        continue;
      }
      for (size_t i1_idx = 0; i1_idx < s0.size(); i1_idx++) { // loop-1 begin
        const IdType i1_id = s0[i1_idx];
        VertexSet m0_adj = m0.N(i1_idx);
        VertexSet s1 = m0_adj.bounded(i1_id);
        if (s1.size() == 0)
          continue;
        /* VSet(1, 1) In-Edges: 0 1 Restricts: 0 1 */
        MiniGraphEager m1(true, false);
        /* Vertices = VSet(1) In-Edges: 0 1 Restricts: 0 1  | Intersect =
         * VSet(1) In-Edges: 0 1 Restricts: 0 1 */
        m1.build(&m0, s1, s1, s1);
        // skip building indices for m1 because they can be obtained directly
        if (s1.size() > 4 * 6) {
          tbb::parallel_for(tbb::blocked_range<size_t>(0, s1.size(), 1),
                            Loop2(ctx, s1, m1), tbb::auto_partitioner());
          continue;
        }
        for (size_t i2_idx = 0; i2_idx < s1.size(); i2_idx++) { // loop-2 begin
          const IdType i2_id = s1[i2_idx];
          VertexSet m1_adj = m1.N(i2_idx);
          VertexSet s2 = m1_adj.bounded(i2_id);
          if (s2.size() == 0)
            continue;
          /* VSet(2, 2) In-Edges: 0 1 2 Restricts: 0 1 2 */
          auto m1_s2 = m1.indices(s2);
          for (size_t i3_idx = 0; i3_idx < s2.size();
               i3_idx++) { // loop-3 begin
            const IdType i3_id = s2[i3_idx];
            VertexSet m1_adj = m1.N(m1_s2[i3_idx]);
            counter += s2.intersect_cnt(m1_adj, m1_adj.vid());
            /* VSet(3, 3) In-Edges: 0 1 2 3 Restricts: 0 1 2 3 */
          } // loop-3 end
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
