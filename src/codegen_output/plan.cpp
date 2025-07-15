#include "plan.h"
namespace minigraph {
uint64_t pattern_size() { return 5; }
void plan(const GraphType *graph, Context &ctx) {
  using MiniGraphType = MiniGraphCostModel;
  MiniGraphIF::DATA_GRAPH = graph;
  VertexSetType::MAX_DEGREE = graph->get_maxdeg();
#pragma omp parallel num_threads(ctx.num_threads) default(none)                \
    shared(ctx, graph)
  { // pragma parallel
    cc &counter = ctx.per_thread_result.at(omp_get_thread_num());
    cc &handled = ctx.per_thread_handled.at(omp_get_thread_num());
    double start = omp_get_wtime();
    ctx.iep_redundency = 0;
#pragma omp for schedule(dynamic, 1) nowait
    for (IdType i0_id = 0; i0_id < graph->get_vnum(); i0_id++) { // loop-0 begin
      VertexSet i0_adj = graph->N(i0_id);
      VertexSet s0 = i0_adj;
      if (s0.size() == 0)
        continue;
      /* VSet(0, 0) In-Edges: 0 Restricts: */
      VertexSet s1 = s0.bounded(i0_id);
      /* VSet(1, 0) In-Edges: 0 Restricts: 0 */
      MiniGraphType m0(false, false);
      /* Vertices = VSet(0) In-Edges: 0 Restricts:  | Intersect = VSet(0)
       * In-Edges: 0 Restricts: */
      double m0_factor = 0;
      m0_factor += s1.size() * s0.size() * 0.6395197459907617 * 1;
      m0.set_reuse_multiplier(m0_factor);
      m0.build(s0, s0, s1);
      // skip building indices for m0 because they can be obtained directly
      for (size_t i1_idx = 0; i1_idx < s1.size(); i1_idx++) { // loop-1 begin
        const IdType i1_id = s1[i1_idx];
        VertexSet i1_adj = graph->N(i1_id);
        VertexSet m0_adj = m0.N(i1_idx);
        VertexSet s2 = i1_adj.subtract(i0_adj);
        if (s2.size() == 0)
          continue;
        /* VSet(2, 1) In-Edges: 1 Restricts: */
        VertexSet s3 = s0.subtract(m0_adj);
        if (s3.size() == 0)
          continue;
        /* VSet(3, 1) In-Edges: 0 Restricts: */
        VertexSet s4 = m0_adj;
        if (s4.size() == 0)
          continue;
        /* VSet(4, 1) In-Edges: 0 1 Restricts: */
        MiniGraphType m1(false, false);
        /* Vertices = VSet(4) In-Edges: 0 1 Restricts:  | Intersect = VSet(2)
         * In-Edges: 1 Restricts: */
        double m1_factor = 0;
        m1_factor += s3.size() * s4.size() * 0.6395197459907617 * 1;
        m1.set_reuse_multiplier(m1_factor);
        m1.build(s4, s2, s3);
        auto m0_s3 = m0.indices(s3);
        for (size_t i2_idx = 0; i2_idx < s3.size(); i2_idx++) { // loop-2 begin
          const IdType i2_id = s3[i2_idx];
          VertexSet i2_adj = graph->N(i2_id);
          VertexSet m0_adj = m0.N(m0_s3[i2_idx]);
          VertexSet s5 = s2.intersect(i2_adj);
          /* VSet(5, 2) In-Edges: 1 2 Restricts: */
          VertexSet s6 = s4.subtract(m0_adj);
          if (s6.size() == 0)
            continue;
          /* VSet(6, 2) In-Edges: 0 1 Restricts: */
          auto m1_s6 = m1.indices(s6);
          for (size_t i3_idx = 0; i3_idx < s6.size();
               i3_idx++) { // loop-3 begin
            const IdType i3_id = s6[i3_idx];
            VertexSet m1_adj = m1.N(m1_s6[i3_idx]);
            counter += s5.subtract_cnt(m1_adj);
            /* VSet(7, 3) In-Edges: 1 2 Restricts: */
          } // loop-3 end
        } // loop-2 end
      } // loop-1 end
      handled += 1;
    } // loop-0 end
    ctx.per_thread_time.at(omp_get_thread_num()) = omp_get_wtime() - start;
  } // pragma parallel
} // plan
} // namespace minigraph
extern "C" void plan(const minigraph::GraphType *graph,
                     minigraph::Context &ctx) {
  return minigraph::plan(graph, ctx);
};