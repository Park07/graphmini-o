#include "plan.h"
namespace minigraph {
uint64_t pattern_size() { return 7; }
static const Graph *graph;
using MiniGraphType = MiniGraphCostModel;
class Loop4 {
private:
  Context &ctx;
  // Parent Intermediates
  VertexSet &s9;
  VertexSet &s10;
  // Iterate Set
  VertexSet &s11;
  // MiniGraphs Indices
  ManagedContainer &m4_s11;
  // MiniGraphs
  MiniGraphType &m4;
  MiniGraphType &m5;

public:
  Loop4(Context &_ctx, VertexSet &_s9, VertexSet &_s10, VertexSet &_s11,
        ManagedContainer &_m4_s11, MiniGraphType &_m4, MiniGraphType &_m5)
      : ctx{_ctx}, s9{_s9}, s10{_s10}, s11{_s11}, m4_s11{_m4_s11}, m4{_m4},
        m5{_m5} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i4_idx = r.begin(); i4_idx < r.end(); i4_idx++) { // loop-4begin
      const IdType i4_id = s11[i4_idx];
      VertexSet i4_adj = graph->N(i4_id);
      VertexSet m4_adj = m4.N(m4_s11[i4_idx]);
      VertexSet s12 = s9.intersect(i4_adj);
      /* VSet(12, 4) In-Edges: 3 4 Restricts: */
      VertexSet s13 = s10.intersect(m4_adj);
      if (s13.size() == 0)
        continue;
      /* VSet(13, 4) In-Edges: 1 2 4 Restricts: 0 */
      auto m5_s13 = m5.indices(s13);
      for (size_t i5_idx = 0; i5_idx < s13.size(); i5_idx++) { // loop-5 begin
        const IdType i5_id = s13[i5_idx];
        VertexSet m5_adj = m5.N(m5_s13[i5_idx]);
        counter += s12.subtract_cnt(m5_adj);
        /* VSet(14, 5) In-Edges: 3 4 Restricts: */
      } // loop-5 end
    } // loop-4 end
  } // operator end
}; // Loop

class Loop3 {
private:
  Context &ctx;
  // Adjacent Lists
  VertexSet &i0_adj;
  VertexSet &i1_adj;
  VertexSet &i2_adj;
  // Parent Intermediates
  VertexSet &s6;
  VertexSet &s7;
  // Iterate Set
  VertexSet &s8;
  // MiniGraphs Indices
  ManagedContainer &m2_s8;
  ManagedContainer &m1_s8;
  // MiniGraphs
  MiniGraphType &m2;
  MiniGraphType &m1;
  MiniGraphType &m4;

public:
  Loop3(Context &_ctx, VertexSet &_i0_adj, VertexSet &_i1_adj,
        VertexSet &_i2_adj, VertexSet &_s6, VertexSet &_s7, VertexSet &_s8,
        ManagedContainer &_m2_s8, ManagedContainer &_m1_s8, MiniGraphType &_m2,
        MiniGraphType &_m1, MiniGraphType &_m4)
      : ctx{_ctx}, i0_adj{_i0_adj}, i1_adj{_i1_adj}, i2_adj{_i2_adj}, s6{_s6},
        s7{_s7}, s8{_s8}, m2_s8{_m2_s8}, m1_s8{_m1_s8}, m2{_m2}, m1{_m1},
        m4{_m4} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i3_idx = r.begin(); i3_idx < r.end(); i3_idx++) { // loop-3begin
      const IdType i3_id = s8[i3_idx];
      VertexSet i3_adj = graph->N(i3_id);
      VertexSet m2_adj = m2.N(m2_s8[i3_idx]);
      VertexSet m1_adj = m1.N(m1_s8[i3_idx]);
      VertexSet s9 = i3_adj.subtract(i0_adj).subtract(i1_adj).subtract(i2_adj);
      if (s9.size() == 0)
        continue;
      /* VSet(9, 3) In-Edges: 3 Restricts: */
      VertexSet s10 = s6.subtract(m2_adj);
      if (s10.size() == 0)
        continue;
      /* VSet(10, 3) In-Edges: 1 2 Restricts: 0 */
      VertexSet s11 = s7.subtract(m1_adj);
      if (s11.size() == 0)
        continue;
      /* VSet(11, 3) In-Edges: 0 Restricts: */
      MiniGraphType m5(false, false);
      /* Vertices = VSet(10) In-Edges: 1 2 Restricts: 0  | Intersect = VSet(9)
       * In-Edges: 3 Restricts: */
      double m5_factor = 0;
      m5_factor += s11.size() * s10.size() * 0.75 * 1;
      m5.set_reuse_multiplier(m5_factor);
      m5.build(s10, s9, s11);
      auto m4_s11 = m4.indices(s11);
      if (s11.size() > 4 * 6) {
        tbb::parallel_for(tbb::blocked_range<size_t>(0, s11.size(), 1),
                          Loop4(ctx, s9, s10, s11, m4_s11, m4, m5),
                          tbb::auto_partitioner());
        continue;
      }
      for (size_t i4_idx = 0; i4_idx < s11.size(); i4_idx++) { // loop-4 begin
        const IdType i4_id = s11[i4_idx];
        VertexSet i4_adj = graph->N(i4_id);
        VertexSet m4_adj = m4.N(m4_s11[i4_idx]);
        VertexSet s12 = s9.intersect(i4_adj);
        /* VSet(12, 4) In-Edges: 3 4 Restricts: */
        VertexSet s13 = s10.intersect(m4_adj);
        if (s13.size() == 0)
          continue;
        /* VSet(13, 4) In-Edges: 1 2 4 Restricts: 0 */
        auto m5_s13 = m5.indices(s13);
        for (size_t i5_idx = 0; i5_idx < s13.size(); i5_idx++) { // loop-5 begin
          const IdType i5_id = s13[i5_idx];
          VertexSet m5_adj = m5.N(m5_s13[i5_idx]);
          counter += s12.subtract_cnt(m5_adj);
          /* VSet(14, 5) In-Edges: 3 4 Restricts: */
        } // loop-5 end
      } // loop-4 end
    } // loop-3 end
  } // operator end
}; // Loop

class Loop2 {
private:
  Context &ctx;
  // Adjacent Lists
  VertexSet &i0_adj;
  VertexSet &i1_adj;
  // Parent Intermediates
  VertexSet &s3;
  VertexSet &s4;
  VertexSet &s2;
  // Iterate Set
  VertexSet &s5;
  // MiniGraphs Indices
  ManagedContainer &m0_s5;
  // MiniGraphs
  MiniGraphType &m3;
  MiniGraphType &m0;
  MiniGraphType &m2;
  MiniGraphType &m1;

public:
  Loop2(Context &_ctx, VertexSet &_i0_adj, VertexSet &_i1_adj, VertexSet &_s3,
        VertexSet &_s4, VertexSet &_s2, VertexSet &_s5,
        ManagedContainer &_m0_s5, MiniGraphType &_m3, MiniGraphType &_m0,
        MiniGraphType &_m2, MiniGraphType &_m1)
      : ctx{_ctx}, i0_adj{_i0_adj}, i1_adj{_i1_adj}, s3{_s3}, s4{_s4}, s2{_s2},
        s5{_s5}, m0_s5{_m0_s5}, m3{_m3}, m0{_m0}, m2{_m2}, m1{_m1} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i2_idx = r.begin(); i2_idx < r.end(); i2_idx++) { // loop-2begin
      const IdType i2_id = s5[i2_idx];
      VertexSet i2_adj = graph->N(i2_id);
      VertexSet m3_adj = m3.N(i2_idx);
      VertexSet m0_adj = m0.N(m0_s5[i2_idx]);
      VertexSet s6 = m3_adj;
      if (s6.size() == 0)
        continue;
      /* VSet(6, 2) In-Edges: 1 2 Restricts: 0 */
      VertexSet s7 = s4.subtract(m0_adj);
      if (s7.size() == 0)
        continue;
      /* VSet(7, 2) In-Edges: 0 Restricts: */
      VertexSet s8 = s2.intersect(i2_adj);
      /* VSet(8, 2) In-Edges: 1 2 Restricts: */
      MiniGraphType m4(false, false);
      /* Vertices = VSet(7) In-Edges: 0 Restricts:  | Intersect = VSet(6)
       * In-Edges: 1 2 Restricts: 0 */
      double m4_factor = 0;
      m4_factor += s8.size() * s7.size() * 0.75 * 1;
      m4.set_reuse_multiplier(m4_factor);
      m4.build(&m3, s7, s6, s8);
      auto m2_s8 = m2.indices(s8);
      auto m1_s8 = m1.indices(s8);
      if (s8.size() > 4 * 6) {
        tbb::parallel_for(tbb::blocked_range<size_t>(0, s8.size(), 1),
                          Loop3(ctx, i0_adj, i1_adj, i2_adj, s6, s7, s8, m2_s8,
                                m1_s8, m2, m1, m4),
                          tbb::auto_partitioner());
        continue;
      }
      for (size_t i3_idx = 0; i3_idx < s8.size(); i3_idx++) { // loop-3 begin
        const IdType i3_id = s8[i3_idx];
        VertexSet i3_adj = graph->N(i3_id);
        VertexSet m2_adj = m2.N(m2_s8[i3_idx]);
        VertexSet m1_adj = m1.N(m1_s8[i3_idx]);
        VertexSet s9 =
            i3_adj.subtract(i0_adj).subtract(i1_adj).subtract(i2_adj);
        if (s9.size() == 0)
          continue;
        /* VSet(9, 3) In-Edges: 3 Restricts: */
        VertexSet s10 = s6.subtract(m2_adj);
        if (s10.size() == 0)
          continue;
        /* VSet(10, 3) In-Edges: 1 2 Restricts: 0 */
        VertexSet s11 = s7.subtract(m1_adj);
        if (s11.size() == 0)
          continue;
        /* VSet(11, 3) In-Edges: 0 Restricts: */
        MiniGraphType m5(false, false);
        /* Vertices = VSet(10) In-Edges: 1 2 Restricts: 0  | Intersect = VSet(9)
         * In-Edges: 3 Restricts: */
        double m5_factor = 0;
        m5_factor += s11.size() * s10.size() * 0.75 * 1;
        m5.set_reuse_multiplier(m5_factor);
        m5.build(s10, s9, s11);
        auto m4_s11 = m4.indices(s11);
        if (s11.size() > 4 * 6) {
          tbb::parallel_for(tbb::blocked_range<size_t>(0, s11.size(), 1),
                            Loop4(ctx, s9, s10, s11, m4_s11, m4, m5),
                            tbb::auto_partitioner());
          continue;
        }
        for (size_t i4_idx = 0; i4_idx < s11.size(); i4_idx++) { // loop-4 begin
          const IdType i4_id = s11[i4_idx];
          VertexSet i4_adj = graph->N(i4_id);
          VertexSet m4_adj = m4.N(m4_s11[i4_idx]);
          VertexSet s12 = s9.intersect(i4_adj);
          /* VSet(12, 4) In-Edges: 3 4 Restricts: */
          VertexSet s13 = s10.intersect(m4_adj);
          if (s13.size() == 0)
            continue;
          /* VSet(13, 4) In-Edges: 1 2 4 Restricts: 0 */
          auto m5_s13 = m5.indices(s13);
          for (size_t i5_idx = 0; i5_idx < s13.size();
               i5_idx++) { // loop-5 begin
            const IdType i5_id = s13[i5_idx];
            VertexSet m5_adj = m5.N(m5_s13[i5_idx]);
            counter += s12.subtract_cnt(m5_adj);
            /* VSet(14, 5) In-Edges: 3 4 Restricts: */
          } // loop-5 end
        } // loop-4 end
      } // loop-3 end
    } // loop-2 end
  } // operator end
}; // Loop

class Loop1 {
private:
  Context &ctx;
  // Adjacent Lists
  VertexSet &i0_adj;
  // Parent Intermediates
  VertexSet &s0;
  // Iterate Set
  VertexSet &s1;
  // MiniGraphs Indices
  // MiniGraphs
  MiniGraphType &m0;

public:
  Loop1(Context &_ctx, VertexSet &_i0_adj, VertexSet &_s0, VertexSet &_s1,
        MiniGraphType &_m0)
      : ctx{_ctx}, i0_adj{_i0_adj}, s0{_s0}, s1{_s1}, m0{_m0} {};
  void operator()(const tbb::blocked_range<size_t> &r) const { // operator begin
    const int worker_id = tbb::this_task_arena::current_thread_index();
    cc &counter = ctx.per_thread_result.at(worker_id);
    for (size_t i1_idx = r.begin(); i1_idx < r.end(); i1_idx++) { // loop-1begin
      const IdType i1_id = s1[i1_idx];
      VertexSet i1_adj = graph->N(i1_id);
      VertexSet m0_adj = m0.N(i1_idx);
      VertexSet s2 = i1_adj.subtract(i0_adj);
      if (s2.size() == 0)
        continue;
      /* VSet(2, 1) In-Edges: 1 Restricts: */
      VertexSet s3 = i1_adj.subtract(i0_adj, i0_adj.vid());
      if (s3.size() == 0)
        continue;
      /* VSet(3, 1) In-Edges: 1 Restricts: 0 */
      VertexSet s4 = s0.subtract(m0_adj);
      if (s4.size() == 0)
        continue;
      /* VSet(4, 1) In-Edges: 0 Restricts: */
      VertexSet s5 = s1.subtract(m0_adj, m0_adj.vid());
      if (s5.size() == 0)
        continue;
      /* VSet(5, 1) In-Edges: 0 Restricts: 0 1 */
      MiniGraphType m1(false, false);
      /* Vertices = VSet(2) In-Edges: 1 Restricts:  | Intersect = VSet(4)
       * In-Edges: 0 Restricts: */
      double m1_factor = 0;
      m1_factor += s5.size() * s2.size() * 0.75 * 1;
      m1.set_reuse_multiplier(m1_factor);
      m1.build(s2, s4, s5);
      MiniGraphType m2(false, false);
      /* Vertices = VSet(2) In-Edges: 1 Restricts:  | Intersect = VSet(3)
       * In-Edges: 1 Restricts: 0 */
      double m2_factor = 0;
      m2_factor += s5.size() * s2.size() * 0.75 * 1;
      m2.set_reuse_multiplier(m2_factor);
      m2.build(s2, s3, s5);
      MiniGraphType m3(false, false);
      /* Vertices = VSet(4) In-Edges: 0 Restricts:  | Intersect = VSet(3)
       * In-Edges: 1 Restricts: 0 */
      double m3_factor = 0;
      m3_factor += s5.size() * s2.size() * 0.75 * s4.size() * 0.515625 * 1;
      m3.set_reuse_multiplier(m3_factor);
      m3.build(s4, s3, s5);
      // skip building indices for m3 because they can be obtained directly
      auto m0_s5 = m0.indices(s5);
      if (s5.size() > 4 * 6) {
        tbb::parallel_for(
            tbb::blocked_range<size_t>(0, s5.size(), 1),
            Loop2(ctx, i0_adj, i1_adj, s3, s4, s2, s5, m0_s5, m3, m0, m2, m1),
            tbb::auto_partitioner());
        continue;
      }
      for (size_t i2_idx = 0; i2_idx < s5.size(); i2_idx++) { // loop-2 begin
        const IdType i2_id = s5[i2_idx];
        VertexSet i2_adj = graph->N(i2_id);
        VertexSet m3_adj = m3.N(i2_idx);
        VertexSet m0_adj = m0.N(m0_s5[i2_idx]);
        VertexSet s6 = m3_adj;
        if (s6.size() == 0)
          continue;
        /* VSet(6, 2) In-Edges: 1 2 Restricts: 0 */
        VertexSet s7 = s4.subtract(m0_adj);
        if (s7.size() == 0)
          continue;
        /* VSet(7, 2) In-Edges: 0 Restricts: */
        VertexSet s8 = s2.intersect(i2_adj);
        /* VSet(8, 2) In-Edges: 1 2 Restricts: */
        MiniGraphType m4(false, false);
        /* Vertices = VSet(7) In-Edges: 0 Restricts:  | Intersect = VSet(6)
         * In-Edges: 1 2 Restricts: 0 */
        double m4_factor = 0;
        m4_factor += s8.size() * s7.size() * 0.75 * 1;
        m4.set_reuse_multiplier(m4_factor);
        m4.build(&m3, s7, s6, s8);
        auto m2_s8 = m2.indices(s8);
        auto m1_s8 = m1.indices(s8);
        if (s8.size() > 4 * 6) {
          tbb::parallel_for(tbb::blocked_range<size_t>(0, s8.size(), 1),
                            Loop3(ctx, i0_adj, i1_adj, i2_adj, s6, s7, s8,
                                  m2_s8, m1_s8, m2, m1, m4),
                            tbb::auto_partitioner());
          continue;
        }
        for (size_t i3_idx = 0; i3_idx < s8.size(); i3_idx++) { // loop-3 begin
          const IdType i3_id = s8[i3_idx];
          VertexSet i3_adj = graph->N(i3_id);
          VertexSet m2_adj = m2.N(m2_s8[i3_idx]);
          VertexSet m1_adj = m1.N(m1_s8[i3_idx]);
          VertexSet s9 =
              i3_adj.subtract(i0_adj).subtract(i1_adj).subtract(i2_adj);
          if (s9.size() == 0)
            continue;
          /* VSet(9, 3) In-Edges: 3 Restricts: */
          VertexSet s10 = s6.subtract(m2_adj);
          if (s10.size() == 0)
            continue;
          /* VSet(10, 3) In-Edges: 1 2 Restricts: 0 */
          VertexSet s11 = s7.subtract(m1_adj);
          if (s11.size() == 0)
            continue;
          /* VSet(11, 3) In-Edges: 0 Restricts: */
          MiniGraphType m5(false, false);
          /* Vertices = VSet(10) In-Edges: 1 2 Restricts: 0  | Intersect =
           * VSet(9) In-Edges: 3 Restricts: */
          double m5_factor = 0;
          m5_factor += s11.size() * s10.size() * 0.75 * 1;
          m5.set_reuse_multiplier(m5_factor);
          m5.build(s10, s9, s11);
          auto m4_s11 = m4.indices(s11);
          if (s11.size() > 4 * 6) {
            tbb::parallel_for(tbb::blocked_range<size_t>(0, s11.size(), 1),
                              Loop4(ctx, s9, s10, s11, m4_s11, m4, m5),
                              tbb::auto_partitioner());
            continue;
          }
          for (size_t i4_idx = 0; i4_idx < s11.size();
               i4_idx++) { // loop-4 begin
            const IdType i4_id = s11[i4_idx];
            VertexSet i4_adj = graph->N(i4_id);
            VertexSet m4_adj = m4.N(m4_s11[i4_idx]);
            VertexSet s12 = s9.intersect(i4_adj);
            /* VSet(12, 4) In-Edges: 3 4 Restricts: */
            VertexSet s13 = s10.intersect(m4_adj);
            if (s13.size() == 0)
              continue;
            /* VSet(13, 4) In-Edges: 1 2 4 Restricts: 0 */
            auto m5_s13 = m5.indices(s13);
            for (size_t i5_idx = 0; i5_idx < s13.size();
                 i5_idx++) { // loop-5 begin
              const IdType i5_id = s13[i5_idx];
              VertexSet m5_adj = m5.N(m5_s13[i5_idx]);
              counter += s12.subtract_cnt(m5_adj);
              /* VSet(14, 5) In-Edges: 3 4 Restricts: */
            } // loop-5 end
          } // loop-4 end
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
      VertexSet s0 = i0_adj;
      if (s0.size() == 0)
        continue;
      /* VSet(0, 0) In-Edges: 0 Restricts: */
      VertexSet s1 = s0.bounded(i0_id);
      /* VSet(1, 0) In-Edges: 0 Restricts: 0 */
      MiniGraphType m0(false, false);
      /* Vertices = VSet(1) In-Edges: 0 Restricts: 0  | Intersect = VSet(0)
       * In-Edges: 0 Restricts: */
      double m0_factor = 0;
      m0_factor += s1.size() * s1.size() * 0.6875 * 1;
      m0.set_reuse_multiplier(m0_factor);
      m0.build(s1, s0, s1);
      // skip building indices for m0 because they can be obtained directly
      if (s1.size() > 4 * 6) {
        tbb::parallel_for(tbb::blocked_range<size_t>(0, s1.size(), 1),
                          Loop1(ctx, i0_adj, s0, s1, m0),
                          tbb::auto_partitioner());
        continue;
      }
      for (size_t i1_idx = 0; i1_idx < s1.size(); i1_idx++) { // loop-1 begin
        const IdType i1_id = s1[i1_idx];
        VertexSet i1_adj = graph->N(i1_id);
        VertexSet m0_adj = m0.N(i1_idx);
        VertexSet s2 = i1_adj.subtract(i0_adj);
        if (s2.size() == 0)
          continue;
        /* VSet(2, 1) In-Edges: 1 Restricts: */
        VertexSet s3 = i1_adj.subtract(i0_adj, i0_adj.vid());
        if (s3.size() == 0)
          continue;
        /* VSet(3, 1) In-Edges: 1 Restricts: 0 */
        VertexSet s4 = s0.subtract(m0_adj);
        if (s4.size() == 0)
          continue;
        /* VSet(4, 1) In-Edges: 0 Restricts: */
        VertexSet s5 = s1.subtract(m0_adj, m0_adj.vid());
        if (s5.size() == 0)
          continue;
        /* VSet(5, 1) In-Edges: 0 Restricts: 0 1 */
        MiniGraphType m1(false, false);
        /* Vertices = VSet(2) In-Edges: 1 Restricts:  | Intersect = VSet(4)
         * In-Edges: 0 Restricts: */
        double m1_factor = 0;
        m1_factor += s5.size() * s2.size() * 0.75 * 1;
        m1.set_reuse_multiplier(m1_factor);
        m1.build(s2, s4, s5);
        MiniGraphType m2(false, false);
        /* Vertices = VSet(2) In-Edges: 1 Restricts:  | Intersect = VSet(3)
         * In-Edges: 1 Restricts: 0 */
        double m2_factor = 0;
        m2_factor += s5.size() * s2.size() * 0.75 * 1;
        m2.set_reuse_multiplier(m2_factor);
        m2.build(s2, s3, s5);
        MiniGraphType m3(false, false);
        /* Vertices = VSet(4) In-Edges: 0 Restricts:  | Intersect = VSet(3)
         * In-Edges: 1 Restricts: 0 */
        double m3_factor = 0;
        m3_factor += s5.size() * s2.size() * 0.75 * s4.size() * 0.515625 * 1;
        m3.set_reuse_multiplier(m3_factor);
        m3.build(s4, s3, s5);
        // skip building indices for m3 because they can be obtained directly
        auto m0_s5 = m0.indices(s5);
        if (s5.size() > 4 * 6) {
          tbb::parallel_for(
              tbb::blocked_range<size_t>(0, s5.size(), 1),
              Loop2(ctx, i0_adj, i1_adj, s3, s4, s2, s5, m0_s5, m3, m0, m2, m1),
              tbb::auto_partitioner());
          continue;
        }
        for (size_t i2_idx = 0; i2_idx < s5.size(); i2_idx++) { // loop-2 begin
          const IdType i2_id = s5[i2_idx];
          VertexSet i2_adj = graph->N(i2_id);
          VertexSet m3_adj = m3.N(i2_idx);
          VertexSet m0_adj = m0.N(m0_s5[i2_idx]);
          VertexSet s6 = m3_adj;
          if (s6.size() == 0)
            continue;
          /* VSet(6, 2) In-Edges: 1 2 Restricts: 0 */
          VertexSet s7 = s4.subtract(m0_adj);
          if (s7.size() == 0)
            continue;
          /* VSet(7, 2) In-Edges: 0 Restricts: */
          VertexSet s8 = s2.intersect(i2_adj);
          /* VSet(8, 2) In-Edges: 1 2 Restricts: */
          MiniGraphType m4(false, false);
          /* Vertices = VSet(7) In-Edges: 0 Restricts:  | Intersect = VSet(6)
           * In-Edges: 1 2 Restricts: 0 */
          double m4_factor = 0;
          m4_factor += s8.size() * s7.size() * 0.75 * 1;
          m4.set_reuse_multiplier(m4_factor);
          m4.build(&m3, s7, s6, s8);
          auto m2_s8 = m2.indices(s8);
          auto m1_s8 = m1.indices(s8);
          if (s8.size() > 4 * 6) {
            tbb::parallel_for(tbb::blocked_range<size_t>(0, s8.size(), 1),
                              Loop3(ctx, i0_adj, i1_adj, i2_adj, s6, s7, s8,
                                    m2_s8, m1_s8, m2, m1, m4),
                              tbb::auto_partitioner());
            continue;
          }
          for (size_t i3_idx = 0; i3_idx < s8.size();
               i3_idx++) { // loop-3 begin
            const IdType i3_id = s8[i3_idx];
            VertexSet i3_adj = graph->N(i3_id);
            VertexSet m2_adj = m2.N(m2_s8[i3_idx]);
            VertexSet m1_adj = m1.N(m1_s8[i3_idx]);
            VertexSet s9 =
                i3_adj.subtract(i0_adj).subtract(i1_adj).subtract(i2_adj);
            if (s9.size() == 0)
              continue;
            /* VSet(9, 3) In-Edges: 3 Restricts: */
            VertexSet s10 = s6.subtract(m2_adj);
            if (s10.size() == 0)
              continue;
            /* VSet(10, 3) In-Edges: 1 2 Restricts: 0 */
            VertexSet s11 = s7.subtract(m1_adj);
            if (s11.size() == 0)
              continue;
            /* VSet(11, 3) In-Edges: 0 Restricts: */
            MiniGraphType m5(false, false);
            /* Vertices = VSet(10) In-Edges: 1 2 Restricts: 0  | Intersect =
             * VSet(9) In-Edges: 3 Restricts: */
            double m5_factor = 0;
            m5_factor += s11.size() * s10.size() * 0.75 * 1;
            m5.set_reuse_multiplier(m5_factor);
            m5.build(s10, s9, s11);
            auto m4_s11 = m4.indices(s11);
            if (s11.size() > 4 * 6) {
              tbb::parallel_for(tbb::blocked_range<size_t>(0, s11.size(), 1),
                                Loop4(ctx, s9, s10, s11, m4_s11, m4, m5),
                                tbb::auto_partitioner());
              continue;
            }
            for (size_t i4_idx = 0; i4_idx < s11.size();
                 i4_idx++) { // loop-4 begin
              const IdType i4_id = s11[i4_idx];
              VertexSet i4_adj = graph->N(i4_id);
              VertexSet m4_adj = m4.N(m4_s11[i4_idx]);
              VertexSet s12 = s9.intersect(i4_adj);
              /* VSet(12, 4) In-Edges: 3 4 Restricts: */
              VertexSet s13 = s10.intersect(m4_adj);
              if (s13.size() == 0)
                continue;
              /* VSet(13, 4) In-Edges: 1 2 4 Restricts: 0 */
              auto m5_s13 = m5.indices(s13);
              for (size_t i5_idx = 0; i5_idx < s13.size();
                   i5_idx++) { // loop-5 begin
                const IdType i5_id = s13[i5_idx];
                VertexSet m5_adj = m5.N(m5_s13[i5_idx]);
                counter += s12.subtract_cnt(m5_adj);
                /* VSet(14, 5) In-Edges: 3 4 Restricts: */
              } // loop-5 end
            } // loop-4 end
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
