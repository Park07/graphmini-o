#!/bin/bash

echo "=== Fixed GraphMini Performance Test ==="
cd /Users/williampark/GraphMini/build

DATASETS=("wiki")  # Start with just wiki
PATTERNS=("triangle 011101110")  # Start with just triangle
THREAD_COUNTS=(1 2 4)

RESULTS_DIR="../fixed_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Dataset,Pattern,Threads,Execution_Time,Result_Count,Success" > "$RESULTS_DIR/results.csv"

for dataset in "${DATASETS[@]}"; do
    for pattern_info in "${PATTERNS[@]}"; do
        read pattern_name pattern_binary <<< "$pattern_info"
        
        echo ""
        echo "=== Testing $dataset + $pattern_name ==="
        
        for threads in "${THREAD_COUNTS[@]}"; do
            echo "  Testing $threads threads..."
            export OMP_NUM_THREADS=$threads
            
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
            
            # Simple timeout test
            timeout 30 ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3 > "$log_file" 2>&1
            exit_code=$?
            
            if [[ $exit_code -eq 0 ]]; then
                # Parse results without complex bc calculations
                execution_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
                result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*' | head -1)
                
                if [[ -n "$execution_time" && -n "$result_count" ]]; then
                    echo "    ✅ SUCCESS: ${execution_time}s, $result_count results"
                    echo "$dataset,$pattern_name,$threads,$execution_time,$result_count,SUCCESS" >> "$RESULTS_DIR/results.csv"
                else
                    echo "    ⚠️  PARTIAL: Check log for details"
                    echo "$dataset,$pattern_name,$threads,PARTIAL,PARTIAL,PARTIAL" >> "$RESULTS_DIR/results.csv"
                fi
            elif [[ $exit_code -eq 124 ]]; then
                echo "    ❌ TIMEOUT (>30s)"
                echo "$dataset,$pattern_name,$threads,TIMEOUT,TIMEOUT,TIMEOUT" >> "$RESULTS_DIR/results.csv"
            else
                echo "    ❌ FAILED (exit code: $exit_code)"
                echo "$dataset,$pattern_name,$threads,FAILED,FAILED,FAILED" >> "$RESULTS_DIR/results.csv"
            fi
        done
    done
done

echo ""
echo "=== Results Summary ==="
cat "$RESULTS_DIR/results.csv"

echo ""
echo "=== Sample Log Content ==="
echo "First successful log:"
for log in "$RESULTS_DIR"/*.log; do
    if grep -q "RESULT=" "$log"; then
        echo "--- $log ---"
        cat "$log"
        break
    fi
done
