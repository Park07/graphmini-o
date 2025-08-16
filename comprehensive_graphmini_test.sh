#!/bin/bash

echo "=== COMPREHENSIVE GraphMini-O Test (TODS) ==="
echo "Starting at: $(date)"

# --- CONFIGURATION ---
PROJECT_ROOT="/home/williamp/graphmini-o"
DATA_ROOT="/home/williamp/thesis_data/snap_format"
QUERY_ROOT="/home/williamp/thesis_data/query_sets"

cd "$PROJECT_ROOT/build" || exit 1

# Create required directories for GraphMini-O
mkdir -p "$PROJECT_ROOT/plan" "$PROJECT_ROOT/log" "$PROJECT_ROOT/profile"

# All datasets
DATASETS=("dblp" "youtube" "roadNet-CA" "enron" "lj" "wiki")

# Main results directory with timestamp
MAIN_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAIN_RESULTS_DIR="${PROJECT_ROOT}/results/comprehensive_o_${MAIN_TIMESTAMP}"
mkdir -p "$MAIN_RESULTS_DIR"

# Log everything to main log
exec > >(tee -a "$MAIN_RESULTS_DIR/full_log.txt")
exec 2>&1

echo "=== Test Configuration ==="
echo "Testing GraphMini-O (reverted version)"
echo "Datasets: ${DATASETS[@]}"
echo "Main results directory: $MAIN_RESULTS_DIR"
echo ""

# Main CSV header
echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$MAIN_RESULTS_DIR/comprehensive_results.csv"

# Function to get pattern size
get_pattern_size() {
    local binary=$1
    echo "sqrt(${#binary})" | bc -l | cut -d'.' -f1
}

# Function to load a real pattern from generated files
load_real_pattern() {
    local dataset=$1
    local category=$2
    local index=$3

    # FIXED: Use wildcard to match correct vertex count
    local pattern_file="${QUERY_ROOT}/${dataset}/${category}/query_sample_*v_${index}.graph"
    pattern_file=$(ls $pattern_file 2>/dev/null | head -1)

    if [ ! -f "$pattern_file" ]; then
        echo "ERROR_NOT_FOUND"
        return
    fi

    echo "Loading pattern from: $pattern_file" >&2

    # Parse the pattern file
    local header=$(head -1 "$pattern_file")
    local vertices=$(echo "$header" | awk '{print $2}')
    local edges=$(echo "$header" | awk '{print $3}')

    echo "Pattern has $vertices vertices, $edges edges" >&2

    # Generate binary matrix
    local matrix=$(printf '0%.0s' $(seq 1 $((vertices * vertices))))
    while IFS=' ' read -r type u v _; do
        if [[ "$type" == "e" ]]; then
            if [[ "$u" -lt "$vertices" && "$v" -lt "$vertices" ]]; then
                local index1=$((u * vertices + v))
                local index2=$((v * vertices + u))
                matrix="${matrix:0:$index1}1${matrix:$((index1+1))}"
                matrix="${matrix:0:$index2}1${matrix:$((index2+1))}"
            fi
        fi
    done < "$pattern_file"

    echo "Generated binary matrix: $matrix (length: ${#matrix})" >&2

    echo "${vertices}:${edges}:${matrix}"
}

# Store baselines for speedup calculation
declare -A baselines

echo "========================================="
echo "STARTING COMPREHENSIVE TEST - GraphMini-O"
echo "========================================="

for dataset in "${DATASETS[@]}"; do
    # Create per-dataset timestamped directory
    DATASET_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    DATASET_RESULTS_DIR="${MAIN_RESULTS_DIR}/${dataset}_${DATASET_TIMESTAMP}"
    mkdir -p "$DATASET_RESULTS_DIR"

    echo ""
    echo "========================================="
    echo "DATASET: $dataset"
    echo "Results for $dataset: $DATASET_RESULTS_DIR"
    echo "========================================="

    # Check if dataset is preprocessed
    if [ ! -f "${DATA_ROOT}/${dataset}/meta.txt" ]; then
        echo "⚠️  WARNING: Dataset not preprocessed, skipping"
        continue
    fi

    echo ""
    echo "--- Testing Generated Patterns ---"

    # Test ALL categories and ALL patterns
    for category in "small_dense_4v" "small_sparse_4v" "small_dense_8v" "small_sparse_8v" "medium_dense" "medium_sparse" "large_dense" "large_sparse"; do
        echo ""
        echo "--- Testing Category: $category ---"

        # Find all pattern files in this category
        pattern_files=($(ls "${QUERY_ROOT}/${dataset}/${category}"/query_sample_*v_*.graph 2>/dev/null | sort -V))

        if [ ${#pattern_files[@]} -eq 0 ]; then
            echo "  No pattern files found in $category, skipping"
            continue
        fi

        echo "  Found ${#pattern_files[@]} patterns in $category"

        # Determine how many patterns to test based on category
        if [[ "$category" == *"4v"* ]]; then
            # Test all 20 patterns for 4-vertex (they work well)
            pattern_indices=($(seq 1 20))
            echo "  Testing all 20 patterns (4-vertex category)"
        else
            # Test only 1 pattern for 8v+ (they crash, just verify the crash)
            pattern_indices=(1)
            echo "  Testing only 1 pattern (8v+ category - known issues)"
        fi

        # Test the determined patterns
        for index in "${pattern_indices[@]}"; do

            if [ -z "$index" ]; then
                echo "  Could not extract index from pattern, skipping"
                continue
            fi

            echo ""
            echo "Testing: $category (pattern #$index)"

            # Load the pattern
            pattern_info=$(load_real_pattern "$dataset" "$category" "$index")

            if [ "$pattern_info" == "ERROR_NOT_FOUND" ]; then
                echo "  Pattern file not found, skipping"
                continue
            fi

            IFS=':' read -r vertices edges pattern_binary <<< "$pattern_info"
            pattern_name="${category}_${index}"

            echo "  Pattern: ${vertices}v, ${edges}e"

            # FIXED: Updated thread scaling logic
            # Small/Medium patterns (≤8v): Full scaling 1,4,16,32,64
            # Large patterns (>8v): Limited scaling 1,4,16
            if [ $vertices -gt 8 ]; then
                thread_counts="1 4 16"  # Large patterns: limit threads
                exec_timeout="240"  # 4 minutes
                codegen_timeout="60"  # 1 minute for code generation
            else
                thread_counts="1 4 16 32 64"  # Small/medium: full scaling
                exec_timeout="240"  # 4 minutes
                codegen_timeout="600"  # 3 minutes
            fi

            echo "  Thread counts: $thread_counts"
            echo "  Timeouts: codegen=${codegen_timeout}s, exec=${exec_timeout}s"

            baseline_key="${dataset}_${pattern_name}"

            for threads in $thread_counts; do
                echo -n "  ${threads}t: "

                export OMP_NUM_THREADS=$threads

                # Generate code with better error handling
                echo "Generating code for pattern: $pattern_binary"
                timeout $codegen_timeout ./bin/run "$dataset" "${DATA_ROOT}/${dataset}/" "$pattern_name" "$pattern_binary" 0 4 3 > /tmp/run.log 2>&1
                run_exit=$?
                if [ ! -f ./bin/runner ]; then
                    make runner >/dev/null 2>&1
                fi

                # Check for various failure modes
                if [ $run_exit -eq 124 ]; then
                    echo "❌ TIMEOUT_CODEGEN (${codegen_timeout}s)"
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,TIMEOUT_CODEGEN,Code generation timeout" >> "$MAIN_RESULTS_DIR/comprehensive_results.csv"

                    # Create dataset CSV header if it doesn't exist
                    if [ ! -f "$DATASET_RESULTS_DIR/${dataset}_results.csv" ]; then
                        echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    fi
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,TIMEOUT_CODEGEN,Code generation timeout" >> "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    break
                elif [ $run_exit -ne 0 ]; then
                    echo "❌ CODEGEN_FAILED (exit code: $run_exit)"
                    echo "Error log:"
                    cat /tmp/run.log
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,CODEGEN_FAILED,Code generation crashed with exit code $run_exit" >> "$MAIN_RESULTS_DIR/comprehensive_results.csv"

                    # Create dataset CSV header if it doesn't exist
                    if [ ! -f "$DATASET_RESULTS_DIR/${dataset}_results.csv" ]; then
                        echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    fi
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,CODEGEN_FAILED,Code generation crashed with exit code $run_exit" >> "$DATASET_RESULTS_DIR/${dataset}_results.csv"

                    # Skip to next category if this pattern type consistently fails
                    if [[ "$category" != *"4v"* ]] && [[ $run_exit -ne 0 ]]; then
                        echo "  ⚠️  Skipping remaining patterns in $category due to implementation issues"
                        break 2  # Break out of both threads and pattern loops for this category
                    fi
                    break
                fi

                # Verify runner was built successfully
                if [ ! -f ./bin/runner ]; then
                    echo "❌ RUNNER_NOT_BUILT"
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,RUNNER_NOT_BUILT,Binary not generated" >> "$MAIN_RESULTS_DIR/comprehensive_results.csv"

                    # Create dataset CSV header if it doesn't exist
                    if [ ! -f "$DATASET_RESULTS_DIR/${dataset}_results.csv" ]; then
                        echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    fi
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,RUNNER_NOT_BUILT,Binary not generated" >> "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    break
                fi

                # Execute
                log_file="$DATASET_RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
                timeout $exec_timeout /usr/bin/time -v ./bin/runner $threads "${DATA_ROOT}/${dataset}/" > "$log_file" 2>&1
                exit_code=$?

                if [ $exit_code -eq 124 ]; then
                    echo "❌ TIMEOUT_EXEC (${exec_timeout}s)"
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,TIMEOUT_EXEC,Execution timeout (${exec_timeout}s)" >> "$MAIN_RESULTS_DIR/comprehensive_results.csv"

                    # Create dataset CSV header if it doesn't exist
                    if [ ! -f "$DATASET_RESULTS_DIR/${dataset}_results.csv" ]; then
                        echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    fi
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,N/A,N/A,N/A,TIMEOUT_EXEC,Execution timeout (${exec_timeout}s)" >> "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    continue
                fi

                # Parse results
                load_time=$(grep "LoadTime" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
                exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
                result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*' | head -1)
                peak_mem_kb=$(grep "Maximum resident set size" "$log_file" | grep -o '[0-9]*' | head -1)
                peak_mem_mb=$(echo "scale=1; ${peak_mem_kb:-0} / 1024" | bc -l)

                if [ -n "$exec_time" ] && [ -n "$result_count" ]; then
                    # Calculate speedup
                    if [ $threads -eq 1 ]; then
                        baselines["$baseline_key"]="$exec_time"
                        speedup="1.00"
                        efficiency="100.0"
                    else
                        baseline="${baselines[$baseline_key]}"
                        if [ -n "$baseline" ]; then
                            speedup=$(echo "scale=2; $baseline / $exec_time" | bc -l)
                            efficiency=$(echo "scale=1; $speedup * 100 / $threads" | bc -l)
                        else
                            speedup="N/A"
                            efficiency="N/A"
                        fi
                    fi

                    echo "✅ ${exec_time}s, ${result_count} matches, ${speedup}x"
                    # Write to both main and dataset-specific CSV
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,$load_time,$exec_time,$result_count,$peak_mem_mb,$speedup,$efficiency,SUCCESS,GraphMini-O pattern worked!" >> "$MAIN_RESULTS_DIR/comprehensive_results.csv"

                    # Create dataset CSV header if it doesn't exist
                    if [ ! -f "$DATASET_RESULTS_DIR/${dataset}_results.csv" ]; then
                        echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    fi
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,$load_time,$exec_time,$result_count,$peak_mem_mb,$speedup,$efficiency,SUCCESS,GraphMini-O pattern worked!" >> "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                else
                    echo "❌ FAILED"
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,$peak_mem_mb,N/A,N/A,FAILED,Execution failed" >> "$MAIN_RESULTS_DIR/comprehensive_results.csv"

                    # Create dataset CSV header if it doesn't exist
                    if [ ! -f "$DATASET_RESULTS_DIR/${dataset}_results.csv" ]; then
                        echo "Dataset,Pattern_Type,Pattern_Name,Vertices,Edges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_MB,Speedup,Efficiency,Status,Notes" > "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                    fi
                    echo "$dataset,Patterns,$pattern_name,$vertices,$edges,$threads,N/A,N/A,N/A,$peak_mem_mb,N/A,N/A,FAILED,Execution failed" >> "$DATASET_RESULTS_DIR/${dataset}_results.csv"
                fi
            done  # End of threads loop
        done      # End of pattern index loop
    done          # End of category loop
done              # End of dataset loop

echo ""
echo "========================================="
echo "COMPREHENSIVE TEST COMPLETE - GraphMini-O"
echo "========================================="
echo "Ended at: $(date)"
echo ""
echo "=== SUMMARY ==="
echo "Main results CSV: $MAIN_RESULTS_DIR/comprehensive_results.csv"
echo "Full log: $MAIN_RESULTS_DIR/full_log.txt"
echo ""

# Quick summary
echo "Test outcomes:"
grep -c "SUCCESS" "$MAIN_RESULTS_DIR/comprehensive_results.csv" | xargs echo "  Successful:"
grep -c "TIMEOUT" "$MAIN_RESULTS_DIR/comprehensive_results.csv" | xargs echo "  Timeouts:"
grep -c "FAILED" "$MAIN_RESULTS_DIR/comprehensive_results.csv" | xargs echo "  Failures:"

echo ""
echo "Per-dataset results saved in:"
for dataset in "${DATASETS[@]}"; do
    dataset_dir=$(find "$MAIN_RESULTS_DIR" -name "${dataset}_*" -type d | head -1)
    if [ -n "$dataset_dir" ]; then
        echo "  $dataset: $dataset_dir"
    fi
done

echo ""
echo "=== GraphMini-O Version Info ==="
cd "$PROJECT_ROOT"
echo "Git branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
echo "Git commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo "Test completed on: $(hostname)"