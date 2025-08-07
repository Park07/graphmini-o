#!/bin/bash

echo "=== Simple GraphMini Framework ==="

PROJECT_ROOT="/Users/williampark/graphmini-o"
RESULTS_DIR="${PROJECT_ROOT}/simple_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Dataset,PatternFile,Threads,Status,ExitCode" > "$RESULTS_DIR/results.csv"

cd "$PROJECT_ROOT"

# Test only small patterns first
echo "=== Testing Small Patterns ==="
for query_file in $(ls queries/wiki/small_sparse/*.graph 2>/dev/null | head -3); do
    test_name=$(basename "$query_file" .graph)
    echo "Testing: $test_name"
    
    pattern_binary=$(python3 query_to_binary.py "$query_file")
    if [[ "$pattern_binary" == "ERROR"* ]]; then
        echo "  ❌ Pattern conversion failed"
        continue
    fi
    
    for threads in 1 2; do
        echo -n "  $threads threads: "
        
        # Test with 300s timeout 
        python3 run_with_timeout.py 300 bash -c "
            export OMP_NUM_THREADS=$threads
            ./build/bin/run wiki ./dataset/GraphMini/wiki $test_name '$pattern_binary' 0 4 3 > /dev/null 2>&1 &&
            ./build/bin/runner $threads ./dataset/GraphMini/wiki > /dev/null 2>&1
        " > "$RESULTS_DIR/${test_name}_${threads}t.log" 2>&1
        
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "SUCCESS"
            echo "wiki,$test_name,$threads,SUCCESS,0" >> "$RESULTS_DIR/results.csv"
        elif [ $exit_code -eq 124 ]; then
            echo "TIMEOUT"
            echo "wiki,$test_name,$threads,TIMEOUT,124" >> "$RESULTS_DIR/results.csv"
        else
            echo "FAILED (exit $exit_code)"
            echo "wiki,$test_name,$threads,FAILED,$exit_code" >> "$RESULTS_DIR/results.csv"
        fi
    done
done

echo "Results saved to: $RESULTS_DIR/results.csv"
cat "$RESULTS_DIR/results.csv"
