#!/usr/bin/env python3
import os
import sys

def convert_query_file(input_path, output_path):
    """Convert from labeled graph format to simple adjacency format"""
    
    vertices = 0
    edges = []
    
    with open(input_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
                
            parts = line.split()
            if parts[0] == 't':  # Header: t <vertices> <edges>
                vertices = int(parts[1])
            elif parts[0] == 'e':  # Edge: e <src> <dst> <label>
                src, dst = int(parts[1]), int(parts[2])
                edges.append((src, dst))
    
    # Write in simple format
    with open(output_path, 'w') as f:
        f.write(f"{vertices}\n")
        for src, dst in edges:
            f.write(f"{src} {dst}\n")

# Convert all query files
for root, dirs, files in os.walk('queries'):
    for file in files:
        if file.endswith('.graph'):
            input_path = os.path.join(root, file)
            
            # Check if it's the old format
            try:
                with open(input_path, 'r') as f:
                    first_line = f.readline().strip()
                    if first_line.startswith('t '):
                        print(f"Converting: {input_path}")
                        convert_query_file(input_path, input_path)
            except:
                print(f"Skipping: {input_path}")

print("Conversion complete!")
