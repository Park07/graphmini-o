#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DATASET_DIR=${SCRIPT_DIR}/TXT
BINARY_DIR=${SCRIPT_DIR}/../build/bin/prep

# Check if prep binary exists
if [ ! -f "$BINARY_DIR" ]; then
    echo "Error: prep binary not found at $BINARY_DIR"
    echo "compile: mkdir -p build && cd build && cmake .. && make -j"
    exit 1
fi

# Preprocess each dataset
for dataset in enron; do
    if [ -d "${DATASET_DIR}/${dataset}" ]; then
        echo "Preprocessing ${dataset}..."
        mkdir -p "${SCRIPT_DIR}/GraphMini/${dataset}"
        cp "${DATASET_DIR}/${dataset}/snap.txt" "${SCRIPT_DIR}/GraphMini/${dataset}/"
        ${BINARY_DIR} "${SCRIPT_DIR}/GraphMini/${dataset}"
        echo "${dataset} preprocessing complete"
    else
        echo "Warning: ${dataset} dataset not found, skipping..."
    fi
done

