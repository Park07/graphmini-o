#!/bin/bash
# Run this script from your project root: /Users/williampark/graphmini-o
# It will fix the meta file paths for the benchmark.

echo "--- Fixing meta file paths ---"

# An array of your datasets
DATASETS=("wiki" "dblp" "enron" "patents" "lj" "orkut")

for dataset in "${DATASETS[@]}"; do
    DATASET_DIR="./dataset/GraphMini/${dataset}"

    # Check if the directory exists
    if [ -d "$DATASET_DIR" ]; then
        # Find the actual .meta file (it's the only one in there)
        # We use 'find' to get the full name, e.g., "wiki.meta"
        actual_meta_file=$(find "$DATASET_DIR" -name "*.meta" -print -quit)

        if [ -n "$actual_meta_file" ]; then
            # Get just the filename from the full path
            actual_meta_filename=$(basename "$actual_meta_file")

            # The path where the program is looking for the meta file
            expected_meta_path="${DATASET_DIR}/snap.txt.meta"

            echo "Processing dataset: $dataset"

            # Create a symbolic link (shortcut)
            # 'ln -s' creates the link, '-f' overwrites it if it already exists
            ln -sf "$actual_meta_filename" "$expected_meta_path"

            echo "  -> Linked '$expected_meta_path' to '$actual_meta_filename'"
        else
            echo "Warning: No .meta file found for dataset '$dataset'. Skipping."
        fi
    fi
done

echo "--- Path fixing complete. You can now run the benchmark. ---"