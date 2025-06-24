SET(GraphMiningSrc
        TestClass.cpp
        graph.cpp
        dataloader.cpp
        pattern.cpp
        prefix.cpp
        schedule.cpp
        vertex_set.cpp
        motif_generator.cpp
        disjoint_set_union.cpp
        mpi_stubs.cpp
        )

ADD_LIBRARY(graph_mining SHARED ${GraphMiningSrc})
