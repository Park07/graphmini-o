#!/bin/bash

# Working GraphMini test using prof_runner instead of missing run executable

GRAPHMINI_HOME="/Users/williampark/GraphMini"
cd "$GRAPHMINI_HOME"

echo "=== Working GraphMini Baseline Test ==="

# Test with prof_runner (which actually exists)
THREAD_COUNTS=(1 2 4 8)
DATASETS=("wiki" "enron")  # Start with smaller datasets
RESULTS_DIR="working_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

for dataset in "${DATASETS[@]}"; do
    echo "Testing $dataset..."
    
    for threads in "${THREAD_COUNTS[@]}"; do
        echo "  $threads threads..."
        export OMP_NUM_THREADS=$threads
        
        # Use prof_runner instead of the missing run
        cd build
        timeout 60 ./bin/prof_runner 1 "../dataset/GraphMini/$dataset" "../$RESULTS_DIR/${dataset}_${threads}t_aggr" "../$RESULTS_DIR/${dataset}_${threads}t_loop" > "../$RESULTS_DIR/${dataset}_${threads}t.log" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "    SUCCESS"
        else
            echo "    FAILED"
        fi
        cd ..
    done
done

echo "Results in: $RESULTS_DIR"
ls -la "$RESULTS_DIR"
