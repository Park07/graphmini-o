#!/usr/bin/env python3
import sys

def convert_graph_to_binary(file_path):
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        # Skip comment lines and get vertex count
        n = None
        edges = []
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('t ') or line.startswith('v '):
                continue
                
            if line.startswith('e '):
                # Edge format: e src dst label
                parts = line.split()
                src, dst = int(parts[1]), int(parts[2])
                edges.append((src, dst))
            elif n is None and line.isdigit():
                # First number is vertex count
                n = int(line)
            elif ' ' in line and n is None:
                # Edge format: src dst
                parts = line.split()
                if len(parts) >= 2 and parts[0].isdigit() and parts[1].isdigit():
                    src, dst = int(parts[0]), int(parts[1])
                    edges.append((src, dst))
        
        # If no vertex count found, infer from edges
        if n is None:
            max_vertex = max(max(edge) for edge in edges) if edges else 0
            n = max_vertex + 1
        
        # Create binary adjacency matrix
        matrix = ['0'] * (n * n)
        for src, dst in edges:
            if src < n and dst < n:
                matrix[src * n + dst] = '1'
                matrix[dst * n + src] = '1'  # Undirected
        
        return ''.join(matrix)
    
    except Exception as e:
        return f"ERROR: {e}"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("ERROR: Usage: python3 query_to_binary.py <graph_file>")
        sys.exit(1)
    
    result = convert_graph_to_binary(sys.argv[1])
    print(result)
