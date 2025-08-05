#!/usr/bin/env python3
import sys

def file_to_binary_string(file_path):
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()

        header = lines[0].strip().split()
        if header[0] != 't':
            # Handle format from your uploaded query_dense_4_1.graph if needed
            if len(lines[0].strip().split()) == 2:
                 header = ['t'] + lines[0].strip().split()
            else:
                 return "ERROR: Invalid header format"


        num_vertices = int(header[1])
        if num_vertices == 0:
            return "ERROR: Zero vertices"

        matrix = ['0'] * (num_vertices * num_vertices)

        for line in lines[1:]:
            parts = line.strip().split()
            if not parts or parts[0] != 'e':
                continue # Skip vertex lines or empty lines

            u, v = int(parts[1]), int(parts[2])

            if u < num_vertices and v < num_vertices:
                matrix[u * num_vertices + v] = '1'
                matrix[v * num_vertices + u] = '1'

        return "".join(matrix)

    except (IOError, IndexError, ValueError) as e:
        return f"ERROR: {e}"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 query_to_binary.py <path_to_query_file>")
        sys.exit(1)

    result = file_to_binary_string(sys.argv[1])
    print(result)