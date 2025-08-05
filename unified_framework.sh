#!/bin/bash

echo "=== GraphMini-O Modern Benchmark Framework ==="

# --- CONFIGURATION ---
PROJECT_ROOT="/Users/williampark/graphmini-o"
# Add all datasets you want to test
DATASETS=("wiki" "dblp" "enron")
THREAD_COUNTS=(1 4 8 16)
TIMEOUT=900 # 15 minutes (900 seconds)

# These must match your directory names inside 'queries/dataset_name/'
PATTERN_CATEGORIES=(
    "small_sparse" "small_dense"
    "medium_sparse" "medium_dense"
    "large_sparse" "large_dense"
)

# --- SETUP ---
cd "$PROJECT_ROOT" || { echo "ERROR: Could not find project root. Exiting."; exit 1; }

BRANCH_NAME=$(git branch --show-current | sed 's/[^a-zA-Z0-9]/-/g')
RESULTS_DIR="${PROJECT_ROOT}/unified_results_${BRANCH_NAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved in: $RESULTS_DIR"
echo "Dataset,PatternCategory,QueryFile,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_Peak_MB,Status,Notes" > "$RESULTS_DIR/unified_results.csv"

# --- CHECK DEPENDENCIES ---
if [ ! -f "run_with_timeout.py" ] || [ ! -f "query_to_binary.py" ]; then
    echo "ERROR: Missing helper scripts 'run_with_timeout.py' or 'query_to_binary.py' in project root."
    exit 1
fi
if [ ! -d "build" ]; then
    echo "ERROR: 'build' directory not found. Please compile the project first."
    exit 1
fi

# --- RUN EXPERIMENTS ---
echo ""
echo "=============================="
echo "PHASE: RUNNING EXPERIMENTS"
echo "=============================="

# Main loop
for dataset in "${DATASETS[@]}"; do
    for category in "${PATTERN_CATEGORIES[@]}"; do
        query_dir="${PROJECT_ROOT}/queries/${dataset}/${category}"
        if [ ! -d "$query_dir" ]; then continue; fi

        for query_file in "$query_dir"/*.graph; do
            if [ ! -f "$query_file" ]; then continue; fi

            test_name=$(basename "$query_file" .graph)

            # --- Convert query file to binary string using our Python script ---
            pattern_binary=$(python3 query_to_binary.py "$query_file")
            if [[ "$pattern_binary" == "ERROR"* ]]; then
                echo "Skipping bad query file: $query_file ($pattern_binary)"
                continue
            fi

            # --- This is the two-step execution process for GraphMini-O ---
            # 1. Generate the specialized C++ code for this pattern
            "${PROJECT_ROOT}/build/bin/run" "$dataset" "${PROJECT_ROOT}/dataset/GraphMini/${dataset}" "$test_name" "$pattern_binary" 0 4 3 > /dev/null 2>&1

            # 2. Run the compiled code with different thread counts
            for threads in "${THREAD_COUNTS[@]}"; do
                log_file="$RESULTS_DIR/${dataset}_${category}_${test_name}_${threads}t.log"
                echo -n "Running: [${dataset}] [${category}/${test_name}] [${threads} threads]..."

                # Set threads and execute the runner with timeout
                export OMP_NUM_THREADS=$threads
                python3 run_with_timeout.py $TIMEOUT \
                    /usr/bin/time -l "${PROJECT_ROOT}/build/bin/runner" 1 "${PROJECT_ROOT}/dataset/GraphMini/${dataset}" > "$log_file" 2>&1
                exit_code=$?

                status="SUCCESS"; notes=""
                if [ $exit_code -eq 124 ]; then status="TIMEOUT"; notes="Query exceeded ${TIMEOUT}s limit"; fi
                if [ $exit_code -ne 0 ] && [ $exit_code -ne 124 ]; then status="FAILED"; notes="Program crashed (exit code ${exit_code})"; fi

                # --- PARSE RESULTS FROM THE LOG FILE ---
                if [ "$status" = "SUCCESS" ]; then
                    load_time=$(grep "LoadTime" "$log_file" | awk '{print $2}' | head -1)
                    exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | awk '{print $2}' | head -1)
                    result_count=$(grep "RESULT=" "$log_file" | cut -d'=' -f2 | head -1)
                    peak_mem_bytes=$(grep "maximum resident set size" "$log_file" | awk '{print $1}' | tail -1)
                    peak_mem_mb=$(echo "scale=2; ${peak_mem_bytes:-0} / 1024 / 1024" | bc)
                    echo " Done. Time: ${exec_time}s, Results: ${result_count}"
                else
                    load_time="N/A"; exec_time="N/A"; result_count="N/A"; peak_mem_mb=0
                    echo " ${status}"
                fi

                # Append to CSV
                echo "$dataset,$category,$(basename "$query_file"),$threads,$load_time,$exec_time,$result_count,$peak_mem_mb,$status,\"$notes\"" >> "$RESULTS_DIR/unified_results.csv"
            done
        done
    done
done

echo ""
echo "=============================="
echo "Benchmark Complete."
echo "Results are in: $RESULTS_DIR/unified_results.csv"
echo "=============================="