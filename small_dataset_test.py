#!/usr/bin/env python3
import networkx as nx
import random
import os
import subprocess
import time

def create_small_dataset(vertices, edges, dataset_name):
    """Create small dataset with known answer"""
    
    # Generate random graph
    G = nx.gnm_random_graph(vertices, edges, seed=42)
    
    # Get ground truth triangle count
    triangles = sum(1 for _ in nx.enumerate_all_cliques(G) if len(_) == 3)
    
    # Create dataset directory
    dataset_dir = f"small_datasets/{dataset_name}"
    os.makedirs(dataset_dir, exist_ok=True)
    
    # Save graph as snap.txt
    with open(f"{dataset_dir}/snap.txt", 'w') as f:
        for u, v in G.edges():
            f.write(f"{u} {v}\n")
    
    # Create meta file
    with open(f"{dataset_dir}/meta.txt", 'w') as f:
        f.write(f"NUM_VERTEX\t{vertices}\n")
        f.write(f"NUM_EDGE\t{edges}\n") 
        f.write(f"NUM_TRIANGLE\t{triangles}\n")
        f.write(f"MAX_DEGREE\t{max(dict(G.degree()).values())}\n")
        f.write(f"MAX_OFFSET\t{edges}\n")
        f.write(f"MAX_TRIANGLE\t{max(dict(G.degree()).values())}\n")
    
    return triangles

def test_dataset(dataset_name, expected_triangles):
    """Test GraphMini on small dataset"""
    
    dataset_path = f"small_datasets/{dataset_name}"
    
    # Preprocess
    print(f"  Preprocessing {dataset_name}...")
    result = subprocess.run(["./build/bin/prep", dataset_path], 
                          capture_output=True, text=True)
    if result.returncode != 0:
        return {"status": "PREP_FAILED", "error": result.stderr}
    
    # Test triangle pattern
    triangle_binary = "011101110"  # 3x3 triangle
    
    print(f"  Testing GraphMini...")
    
    # Code generation
    cmd1 = ["./build/bin/run", "test", dataset_path, "triangle", triangle_binary, "0", "4", "3"]
    
    try:
        start = time.time()
        result1 = subprocess.run(cmd1, capture_output=True, text=True, timeout=120)
        codegen_time = time.time() - start
        
        if result1.returncode != 0:
            if "segmentation fault" in result1.stderr.lower():
                return {"status": "SEGFAULT", "time": codegen_time}
            return {"status": "CODEGEN_FAILED", "time": codegen_time}
        
        # Runner
        cmd2 = ["./build/bin/runner", "1", dataset_path]
        start = time.time()
        result2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=30)
        runner_time = time.time() - start
        
        if result2.returncode != 0:
            return {"status": "RUNNER_FAILED", "time": codegen_time + runner_time}
        
        # Extract result
        graphmini_result = None
        for line in result2.stdout.split('\n'):
            if "RESULT=" in line:
                graphmini_result = int(line.split('=')[1])
                break
        
        total_time = codegen_time + runner_time
        
        # Check correctness
        if graphmini_result == expected_triangles:
            return {"status": "CORRECT", "time": total_time, "result": graphmini_result}
        else:
            return {"status": "WRONG_ANSWER", "time": total_time, 
                   "expected": expected_triangles, "got": graphmini_result}
    
    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "time": 120}

def find_breaking_point():
    """Find exact point where GraphMini breaks"""
    
    print("=== Finding GraphMini Breaking Point ===")
    
    # Test progression: start small, increase vertices
    for vertices in range(7, 15):  # 7 to 14 vertices
        
        sparse_edges = vertices + 5  # Sparse: V + 5 edges
        dense_edges = min(vertices * 3, vertices * (vertices-1) // 2)  # Dense: 3V edges
        
        print(f"\n=== Testing {vertices} vertices ===")
        
        for density, edges in [("sparse", sparse_edges), ("dense", dense_edges)]:
            
            dataset_name = f"{vertices}v_{edges}e_{density}"
            print(f"\n{density.capitalize()}: {vertices}v, {edges}e")
            
            # Create test dataset
            expected = create_small_dataset(vertices, edges, dataset_name)
            print(f"  Expected triangles: {expected}")
            
            # Test GraphMini
            result = test_dataset(dataset_name, expected)
            
            print(f"  GraphMini: {result['status']} ({result.get('time', 0):.1f}s)")
            
            if result['status'] == 'CORRECT':
                print(f"  ✅ PASSED")
            elif result['status'] == 'WRONG_ANSWER':
                print(f"  ❌ WRONG: expected {result['expected']}, got {result['got']}")
                print(f"  🚨 CORRECTNESS BUG FOUND at {vertices} vertices!")
                return {"bug_type": "CORRECTNESS", "vertices": vertices}
            elif result['status'] in ['TIMEOUT', 'SEGFAULT']:
                print(f"  🚨 PERFORMANCE FAILURE at {vertices} vertices!")
                return {"bug_type": result['status'], "vertices": vertices}
            else:
                print(f"  🚨 OTHER FAILURE: {result['status']}")
                return {"bug_type": result['status'], "vertices": vertices}
    
    print("\n✅ All tests passed up to 14 vertices")
    return {"bug_type": "NONE"}

if __name__ == "__main__":
    result = find_breaking_point()
    
    if result['bug_type'] != 'NONE':
        print(f"\n🎯 GraphMini breaks at {result['vertices']} vertices")
        print(f"   Failure type: {result['bug_type']}")
    else:
        print(f"\n✅ GraphMini handles up to 14 vertices correctly")
