#!/bin/bash

# Fixed GraphMini test - no timeout command needed

GRAPHMINI_HOME="/Users/williampark/GraphMini"
cd "$GRAPHMINI_HOME"

echo "=== Fixed GraphMini Baseline Test ==="

THREAD_COUNTS=(1 4)  # Start with just 2 thread counts
DATASETS=("wiki")    # Start with just wiki
RESULTS_DIR="fixed_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

for dataset in "${DATASETS[@]}"; do
    echo "Testing $dataset..."
    
    for threads in "${THREAD_COUNTS[@]}"; do
        echo "  $threads threads..."
        export OMP_NUM_THREADS=$threads
        
        # Remove timeout, run prof_runner directly
        cd build
        ./bin/prof_runner 1 "../dataset/GraphMini/$dataset" "../$RESULTS_DIR/${dataset}_${threads}t_aggr" "../$RESULTS_DIR/${dataset}_${threads}t_loop" > "../$RESULTS_DIR/${dataset}_${threads}t.log" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "    SUCCESS - check results in $RESULTS_DIR"
        else
            echo "    FAILED - check log in $RESULTS_DIR/${dataset}_${threads}t.log"
        fi
        cd ..
    done
done

echo ""
echo "=== Results ==="
echo "Directory: $RESULTS_DIR"
ls -la "$RESULTS_DIR"

echo ""
echo "=== Sample Log (first few lines) ==="
head -10 "$RESULTS_DIR"/*.log | head -20
