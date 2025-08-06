#!/bin/bash

echo "=== GraphMini-O macOS Framework ==="

PROJECT_ROOT="/Users/williampark/graphmini-o"
DATASETS=("wiki")
THREAD_COUNTS=(1 2 4)

# Category-specific timeouts
declare -A CATEGORY_TIMEOUTS
CATEGORY_TIMEOUTS["small_sparse"]=900    # 15 minutes
CATEGORY_TIMEOUTS["small_dense"]=900
CATEGORY_TIMEOUTS["medium_sparse"]=1800  # 30 minutes
CATEGORY_TIMEOUTS["medium_dense"]=1800
CATEGORY_TIMEOUTS["large_sparse"]=3600   # 60 minutes
CATEGORY_TIMEOUTS["large_dense"]=3600

PATTERN_CATEGORIES=("small_sparse" "medium_sparse" "large_sparse")

cd "$PROJECT_ROOT"
RESULTS_DIR="${PROJECT_ROOT}/macos_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved in: $RESULTS_DIR"
echo "Dataset,PatternCategory,QueryFile,Threads,TotalTime_s,Status,Notes" > "$RESULTS_DIR/results.csv"

for dataset in "${DATASETS[@]}"; do
    for category in "${PATTERN_CATEGORIES[@]}"; do
        query_dir="${PROJECT_ROOT}/queries/${dataset}/${category}"
        if [ ! -d "$query_dir" ]; then continue; fi

        # Get timeout for this category
        timeout_seconds=${CATEGORY_TIMEOUTS[$category]}
        echo "=== Testing $category (${timeout_seconds}s timeout) ==="

        # Test only first 3 files per category for reasonable runtime
        for query_file in $(ls "$query_dir"/*.graph 2>/dev/null | head -3); do
            test_name=$(basename "$query_file" .graph)
            pattern_binary=$(python3 query_to_binary.py "$query_file")

            if [[ "$pattern_binary" == "ERROR"* ]]; then
                echo "Skipping bad query file: $test_name"
                continue
            fi

            echo "Testing: $test_name"

            for threads in "${THREAD_COUNTS[@]}"; do
                log_file="$RESULTS_DIR/${dataset}_${category}_${test_name}_${threads}t.log"
                echo -n "  $threads threads: "

                # Use Python timeout for ENTIRE pipeline (code gen + execution)
                python3 run_with_timeout.py $timeout_seconds bash -c "
                    export OMP_NUM_THREADS=$threads
                    '${PROJECT_ROOT}/build/bin/run' '$dataset' '${PROJECT_ROOT}/dataset/GraphMini/${dataset}' '$test_name' '$pattern_binary' 0 4 3 > /dev/null 2>&1 &&
                    '${PROJECT_ROOT}/build/bin/runner' $threads '${PROJECT_ROOT}/dataset/GraphMini/${dataset}'
                " > "$log_file" 2>&1

                exit_code=$?

                if [ $exit_code -eq 0 ]; then
                    result_count=$(grep "RESULT=" "$log_file" | cut -d'=' -f2 | tail -1)
                    exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | awk '{print $2}' | tail -1)
                    echo "SUCCESS (${exec_time}s, $result_count results)"
                    echo "$dataset,$category,$test_name,$threads,$exec_time,SUCCESS," >> "$RESULTS_DIR/results.csv"
                elif [ $exit_code -eq 124 ]; then
                    echo "TIMEOUT (${timeout_seconds}s)"
                    echo "$dataset,$category,$test_name,$threads,$timeout_seconds,TIMEOUT,Exceeded timeout" >> "$RESULTS_DIR/results.csv"
                else
                    echo "FAILED (exit $exit_code)"
                    echo "$dataset,$category,$test_name,$threads,N/A,FAILED,Exit code $exit_code" >> "$RESULTS_DIR/results.csv"
                fi
            done
        done
    done
done

echo "Framework complete! Results: $RESULTS_DIR/results.csv"
EOF