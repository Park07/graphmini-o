#!/bin/bash

echo "=== GraphMini Success Test ==="
cd /Users/williampark/GraphMini/build

# Test triangle pattern with different thread counts
for threads in 1 2 4; do
    echo ""
    echo "Testing with $threads threads:"
    export OMP_NUM_THREADS=$threads
    echo "  Command: ./bin/run wiki ../dataset/GraphMini/wiki triangle 011101110 0 4 3"
    ./bin/run wiki ../dataset/GraphMini/wiki triangle 011101110 0 4 3
    echo "  ✅ Completed with $threads threads"
done
