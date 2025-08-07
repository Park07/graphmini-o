#!/usr/bin/env python3
import networkx as nx
import random
import os
import subprocess
import sys
from collections import defaultdict
import time

def generate_test_graph(num_vertices, num_edges, is_dense=False):
    """Generate a random graph with specified vertices and edges"""

    # Create empty graph
    G = nx.Graph()
    G.add_nodes_from(range(num_vertices))

    # Calculate max possible edges
    max_edges = num_vertices * (num_vertices - 1) // 2
    num_edges = min(num_edges, max_edges)

    # Generate random edges
    edges_added = 0
    attempts = 0
    while edges_added < num_edges and attempts < num_edges * 10:
        u = random.randint(0, num_vertices - 1)
        v = random.randint(0, num_vertices - 1)
        if u != v and not G.has_edge(u, v):
            G.add_edge(u, v)
            edges_added += 1
        attempts += 1

    return G

def graph_to_graphmini_format(G, filename):
    """Convert NetworkX graph to GraphMini format"""
    num_vertices = G.number_of_nodes()

    with open(filename, 'w') as f:
        f.write(f"{num_vertices}\n")
        for u, v in G.edges():
            f.write(f"{u} {v}\n")

    return filename

def graph_to_binary_string(G):
    """Convert graph to binary adjacency matrix string"""
    n = G.number_of_nodes()
    matrix = ['0'] * (n * n)

    for u, v in G.edges():
        matrix[u * n + v] = '1'
        matrix[v * n + u] = '1'

    return ''.join(matrix)

def count_triangles_networkx(G):
    """Ground truth triangle count using NetworkX"""
    triangles = list(nx.enumerate_all_cliques(G))
    triangle_count = len([t for t in triangles if len(t) == 3])
    return triangle_count

def count_subgraphs_networkx(G, pattern_G):
    """Count subgraph isomorphisms using NetworkX"""
    from networkx.algorithms import isomorphism
    matcher = isomorphism.GraphMatcher(G, pattern_G)
    return len(list(matcher.subgraph_isomorphisms_iter()))

def test_graphmini(graph_file, pattern_binary, vertices, test_name):
    """Test GraphMini with timeout and error handling"""

    # Code generation phase
    print(f"    Testing GraphMini code generation...")
    cmd1 = [
        "./build/bin/run", "wiki",
        "/Users/williampark/graphmini-o/dataset/GraphMini/wiki",
        test_name, pattern_binary, "0", "4", "3"
    ]

    try:
        start_time = time.time()
        result1 = subprocess.run(cmd1, capture_output=True, text=True, timeout=300)
        codegen_time = time.time() - start_time

        if result1.returncode != 0:
            error_msg = result1.stderr.strip()
            if "mkdir" in error_msg:
                return {"status": "MKDIR_ERROR", "time": codegen_time, "error": error_msg}
            elif "segmentation fault" in error_msg.lower():
                return {"status": "SEGFAULT", "time": codegen_time, "error": error_msg}
            else:
                return {"status": "CODEGEN_FAILED", "time": codegen_time, "error": error_msg}

        print(f"    Code generation: {codegen_time:.2f}s")

        # Runner phase
        print(f"    Testing GraphMini runner...")
        cmd2 = ["./build/bin/runner", "1", "/Users/williampark/graphmini-o/dataset/GraphMini/wiki"]

        start_time = time.time()
        result2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=60)
        runner_time = time.time() - start_time

        if result2.returncode != 0:
            return {"status": "RUNNER_FAILED", "time": codegen_time + runner_time, "error": result2.stderr}

        # Extract result
        output_lines = result2.stdout.split('\n')
        result_count = None
        for line in output_lines:
            if "RESULT=" in line:
                result_count = int(line.split('=')[1])
                break

        return {
            "status": "SUCCESS",
            "time": codegen_time + runner_time,
            "result": result_count,
            "codegen_time": codegen_time,
            "runner_time": runner_time
        }

    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "time": 300}
    except Exception as e:
        return {"status": "ERROR", "error": str(e)}

def systematic_debug_test():
    """Systematic testing starting from small graphs"""

    print("=== GraphMini Systematic Debug Framework ===")
    print("Testing correctness and finding exact failure point")
    print()

    # Test configuration
    start_vertices = 3
    max_vertices = 12
    tests_per_size = 3

    results = []

    for num_vertices in range(start_vertices, max_vertices + 1):
        print(f"=== Testing {num_vertices} vertices ===")

        # Test sparse graphs
        sparse_edges = min(num_vertices + 5, num_vertices * (num_vertices - 1) // 4)
        # Test dense graphs
        dense_edges = min(num_vertices * 2, num_vertices * (num_vertices - 1) // 2)

        for density, num_edges in [("sparse", sparse_edges), ("dense", dense_edges)]:
            print(f"  {density.capitalize()} graphs ({num_edges} edges):")

            success_count = 0

            for test_num in range(tests_per_size):
                test_name = f"{num_vertices}v_{density}_{test_num}"
                print(f"    Test {test_num + 1}/{tests_per_size}: {test_name}")

                # Generate random graph
                G = generate_test_graph(num_vertices, num_edges)
                actual_edges = G.number_of_edges()

                print(f"      Generated: {num_vertices}v, {actual_edges}e")

                # Ground truth (NetworkX)
                if num_vertices <= 6:  # Only for small graphs to avoid networkx being slow
                    ground_truth = count_triangles_networkx(G)
                    print(f"      Ground truth triangles: {ground_truth}")
                else:
                    ground_truth = None

                # Convert to GraphMini format
                graph_file = f"test_graphs/{test_name}.graph"
                os.makedirs("test_graphs", exist_ok=True)
                graph_to_graphmini_format(G, graph_file)

                # Test triangle pattern (3-vertex complete graph)
                triangle_binary = "011101110"  # 3x3 adjacency matrix for triangle

                # Test GraphMini
                gm_result = test_graphmini(graph_file, triangle_binary, num_vertices, test_name)

                print(f"      GraphMini status: {gm_result['status']}")
                if gm_result['status'] == 'SUCCESS':
                    print(f"      GraphMini result: {gm_result['result']}")
                    print(f"      Time: {gm_result['time']:.2f}s")

                    # Compare with ground truth
                    if ground_truth is not None:
                        if gm_result['result'] == ground_truth:
                            print(f"      ✅ CORRECT: {gm_result['result']} == {ground_truth}")
                            success_count += 1
                        else:
                            print(f"       INCORRECT: {gm_result['result']} != {ground_truth}")
                            print(f"       CORRECTNESS FAILURE DETECTED!")
                            return {"failure_point": test_name, "vertices": num_vertices}
                    else:
                        success_count += 1
                else:
                    print(f"       GraphMini failed: {gm_result.get('error', 'Unknown error')}")
                    if gm_result['status'] in ['TIMEOUT', 'CODEGEN_FAILED', 'SEGFAULT']:
                        print(f"       SCALABILITY FAILURE DETECTED!")
                        return {"failure_point": test_name, "vertices": num_vertices, "failure_type": gm_result['status']}

                results.append({
                    "vertices": num_vertices,
                    "density": density,
                    "edges": actual_edges,
                    "test": test_name,
                    "ground_truth": ground_truth,
                    "graphmini": gm_result
                })

                print()

            print(f"    {density.capitalize()} success rate: {success_count}/{tests_per_size}")

        print()

    print("=== All tests completed! ===")
    return {"all_passed": True, "results": results}

if __name__ == "__main__":
    random.seed(42)  # Reproducible results
    result = systematic_debug_test()

    if "failure_point" in result:
        print(f" Found exact failure point: {result['failure_point']} at {result['vertices']} vertices")
        print(f"   Failure type: {result.get('failure_type', 'Unknown')}")
    else:
        print(" All tests passed!")
