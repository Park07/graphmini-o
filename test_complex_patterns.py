#!/usr/bin/env python3
import networkx as nx
import os
import subprocess
import time

def create_pattern_binary(pattern_edges, vertices):
    """Create binary adjacency matrix from edge list"""
    matrix = ['0'] * (vertices * vertices)
    for u, v in pattern_edges:
        matrix[u * vertices + v] = '1'
        matrix[v * vertices + u] = '1'
    return ''.join(matrix)

def test_complex_pattern(dataset_path, pattern_name, pattern_binary, timeout=180):
    """Test GraphMini with complex pattern"""
    
    print(f"    Testing {pattern_name}...")
    
    # Code generation
    cmd1 = ["./build/bin/run", "test", dataset_path, pattern_name, pattern_binary, "0", "4", "3"]
    
    try:
        start = time.time()
        result1 = subprocess.run(cmd1, capture_output=True, text=True, timeout=timeout)
        codegen_time = time.time() - start
        
        if result1.returncode != 0:
            if "segmentation fault" in result1.stderr.lower():
                return {"status": "SEGFAULT", "time": codegen_time}
            return {"status": "CODEGEN_FAILED", "time": codegen_time}
        
        print(f"      Code generation: {codegen_time:.1f}s")
        
        # Runner
        cmd2 = ["./build/bin/runner", "1", dataset_path]
        start = time.time()
        result2 = subprocess.run(cmd2, capture_output=True, text=True, timeout=30)
        runner_time = time.time() - start
        
        if result2.returncode != 0:
            return {"status": "RUNNER_FAILED", "time": codegen_time + runner_time}
        
        # Extract result
        result_count = None
        for line in result2.stdout.split('\n'):
            if "RESULT=" in line:
                result_count = int(line.split('=')[1])
                break
        
        total_time = codegen_time + runner_time
        return {"status": "SUCCESS", "time": total_time, "result": result_count, "codegen_time": codegen_time}
    
    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "time": timeout}

def test_pattern_complexity():
    """Test increasingly complex patterns"""
    
    print("=== Testing Pattern Complexity Limits ===")
    
    # Use 8-vertex dataset (we know this size works for triangles)
    dataset_path = "small_datasets/8v_24e_dense"
    
    # Test patterns of increasing complexity
    patterns = [
        # Simple patterns
        ("triangle", [(0,1), (1,2), (2,0)], 3),
        ("4-path", [(0,1), (1,2), (2,3)], 4),  
        ("4-cycle", [(0,1), (1,2), (2,3), (3,0)], 4),
        ("4-star", [(0,1), (0,2), (0,3)], 4),
        
        # Medium complexity
        ("5-cycle", [(0,1), (1,2), (2,3), (3,4), (4,0)], 5),
        ("5-clique", [(0,1), (0,2), (0,3), (0,4), (1,2), (1,3), (1,4), (2,3), (2,4), (3,4)], 5),
        
        # High complexity (like HKU patterns)
        ("6-complex", [(0,1), (0,2), (1,3), (2,4), (3,5), (4,5), (1,4), (2,3)], 6),
        ("7-complex", [(0,1), (0,2), (1,3), (2,4), (3,5), (4,6), (5,6), (1,4), (2,3), (0,5)], 7),
        ("8-complex", [(0,1), (0,2), (1,3), (2,4), (3,5), (4,6), (5,7), (6,7), (1,4), (2,3), (0,5), (1,6)], 8),
    ]
    
    for pattern_name, edges, vertices in patterns:
        print(f"\n  Pattern: {pattern_name} ({vertices} vertices, {len(edges)} edges)")
        
        # Create binary representation
        pattern_binary = create_pattern_binary(edges, vertices)
        print(f"    Binary length: {len(pattern_binary)} bits")
        
        # Test with increasing timeouts for complex patterns
        timeout = 60 if vertices <= 5 else (120 if vertices <= 7 else 1200)
        
        result = test_complex_pattern(dataset_path, pattern_name, pattern_binary, timeout)
        
        print(f"    Result: {result['status']} ({result.get('time', 0):.1f}s)")
        
        if result['status'] == 'SUCCESS':
            print(f"      Codegen: {result['codegen_time']:.1f}s, Found: {result['result']} matches")
        elif result['status'] in ['TIMEOUT', 'SEGFAULT']:
            print(f"    🚨 PATTERN COMPLEXITY LIMIT REACHED!")
            print(f"       GraphMini cannot handle {vertices}-vertex complex patterns")
            return {"breaking_pattern": pattern_name, "vertices": vertices}
        else:
            print(f"    Failed: {result['status']}")
            return {"breaking_pattern": pattern_name, "vertices": vertices}
    
    return {"all_passed": True}

if __name__ == "__main__":
    result = test_pattern_complexity()
    
    if "breaking_pattern" in result:
        print(f"\n🎯 GraphMini breaks at complex {result['vertices']}-vertex patterns")
        print(f"   Breaking pattern: {result['breaking_pattern']}")
        print(f"\nConclusion: Pattern complexity, not vertex count, is the limit")
    else:
        print(f"\n✅ All complex patterns handled successfully")
