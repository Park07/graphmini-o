#!/bin/bash

echo "=== graphmini Advanced Experiment Framework (No Pre-processing) ==="

# --- CONFIGURATION ---
# This script is designed to be run from your project root: /Users/williampark/graphmini
# Running on the three requested datasets
DATASETS=("wiki" "dblp" "enron")
THREAD_COUNTS=(1 2 4 8 16)
TIMEOUT=900 # 15 minutes
NUM_QUERIES_PER_CATEGORY=5

# --- PATTERN DEFINITIONS ---
PATTERN_CATEGORIES=(
    "simple_patterns;4;4"      # Your working simple patterns (fast)
    "small_dense;4;4"          # Your working square pattern (medium)
    "medium_sparse;16;24"      # HKU patterns (research-grade)
    "medium_dense;16;24"       # HKU patterns (research-grade)
    "large_sparse;16;24"       # HKU patterns (research-grade)
    "large_dense;16;24"        # HKU patterns (research-grade)
)
# --- SETUP ---
PROJECT_ROOT="/Users/williampark/graphmini"
cd "$PROJECT_ROOT" || { echo "ERROR: Could not cd to project root '$PROJECT_ROOT'. Exiting."; exit 1; }

BRANCH_NAME=$(git branch --show-current | sed 's/[^a-zA-Z0-9]/-/g')
RESULTS_DIR="${PROJECT_ROOT}/unified_results_${BRANCH_NAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved in: $RESULTS_DIR"
echo "Dataset,PatternCategory,QueryFile,QueryVertices,QueryEdges,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Memory_Peak_MB,Status,Notes" > "$RESULTS_DIR/unified_results.csv"

# --- PHASE 1: GENERATE QUERY GRAPHS ---
echo ""
echo "========================================="
echo "PHASE 1: CHECKING/GENERATING QUERY GRAPHS"
echo "========================================="
for dataset in "${DATASETS[@]}"; do
    dataset_file_path="${PROJECT_ROOT}/dataset/GraphMini/${dataset}/snap.txt"
    if [ ! -f "$dataset_file_path" ]; then
        echo "Warning: snap.txt not found for '$dataset' at '$dataset_file_path'. Skipping query generation."
        continue
    fi
    for category_info in "${PATTERN_CATEGORIES[@]}"; do
        IFS=';' read -r category_name target_vertices min_edges <<< "$category_info"
        query_dir="${PROJECT_ROOT}/queries/${dataset}/${category_name}"
        mkdir -p "$query_dir"
        if [ -z "$(ls -A ${query_dir} 2>/dev/null)" ]; then
            echo "Generating ${NUM_QUERIES_PER_CATEGORY} queries for ${dataset} -> ${category_name}..."
echo "Skipping pattern generation"
        else
            echo "Queries for ${dataset} -> ${category_name} already exist. Skipping."
        fi
    done
done

# --- Function to convert a query file to a binary matrix string ---
function file_to_binary_string() {
    local file_path=$1
    if [ ! -f "$file_path" ]; then echo "ERROR_FILE_NOT_FOUND"; return; fi

    local n
    n=$(head -n 1 "$file_path")
    if ! [[ "$n" =~ ^[0-9]+$ ]] || [[ "$n" -eq 0 ]]; then echo "ERROR_INVALID_VERTICES"; return; fi

    # Initialize matrix with zeros
    local matrix=$(printf '0%.0s' $(seq 1 $((n * n))))

    # Use process substitution instead of pipe to avoid subshell
    while IFS=' ' read -r u v; do
        if [[ -n "$u" && -n "$v" ]] && [[ "$u" =~ ^[0-9]+$ ]] && [[ "$v" =~ ^[0-9]+$ ]]; then
            if [[ $u -lt $n && $v -lt $n ]]; then
                local index1=$((u * n + v))
                local index2=$((v * n + u))
                # Fix the string manipulation
                matrix="${matrix:0:$index1}1${matrix:$((index1+1))}"
                matrix="${matrix:0:$index2}1${matrix:$((index2+1))}"
            fi
        fi
    done < <(tail -n +2 "$file_path")

    echo "$matrix"
}

# --- PHASE 2: RUN EXPERIMENTS ---
echo ""
echo "========================================="
echo "PHASE 2: RUNNING EXPERIMENTS"
echo "========================================="
# Calculate total tests based on actual datasets and categories being tested
total_tests=0
for dataset in "${DATASETS[@]}"; do
    for category_info in "${PATTERN_CATEGORIES[@]}"; do
        IFS=';' read -r category_name _ _ <<< "$category_info"
        query_dir="${PROJECT_ROOT}/queries/${dataset}/${category_name}"
        if [ -d "$query_dir" ]; then
            patterns_in_category=$(find "$query_dir" -name "*.graph" 2>/dev/null | wc -l)
            total_tests=$((total_tests + patterns_in_category))
        fi
    done
done
total_tests=$((total_tests * ${#THREAD_COUNTS[@]}))
test_count=0

cd "${PROJECT_ROOT}/build" || { echo "ERROR: Could not cd to build directory. Exiting."; exit 1; }

for dataset in "${DATASETS[@]}"; do
    dataset_runner_path="../dataset/GraphMini/${dataset}"
    for category_info in "${PATTERN_CATEGORIES[@]}"; do
        IFS=';' read -r category_name _ _ <<< "$category_info"
        query_dir="../queries/${dataset}/${category_name}"

        for query_file in ${query_dir}/*.graph; do
            if [ ! -f "$query_file" ]; then continue; fi
            for threads in "${THREAD_COUNTS[@]}"; do
                test_count=$((test_count + 1))
                test_name=$(basename "$query_file" .graph)
                log_file="$RESULTS_DIR/${dataset}_${category_name}_${test_name}_${threads}t.log"

                echo "[Test ${test_count}/${total_tests}] DATASET: ${dataset}, PATTERN: ${category_name}/${test_name}, THREADS: ${threads}"

                pattern_binary=$(file_to_binary_string "$query_file")
                query_vertices=$(head -n 1 "$query_file")
                query_edges=$(tail -n +2 "$query_file" | wc -l | xargs)

                if [[ "$pattern_binary" == "ERROR"* ]]; then
                    echo "  -> Status: SKIPPED, Notes: Bad query file."
                    echo "$dataset,$category_name,$(basename "$query_file"),$query_vertices,$query_edges,$threads,N/A,N/A,N/A,0,SKIPPED,Bad_query_file" >> "$RESULTS_DIR/unified_results.csv"
                    continue
                fi

                # Generate code for the new pattern
                ./bin/run "$dataset" "$dataset_runner_path" "$test_name" "$pattern_binary" 0 4 3 > /dev/null 2>&1

                # Execute the runner with the new pattern
                export OMP_NUM_THREADS=$threads
                /usr/bin/time -l ./bin/runner 1 "$dataset_runner_path" > "$log_file" 2>&1
                exit_code=$?

                status="SUCCESS"; notes=""
                if [ $exit_code -eq 124 ]; then status="TIMEOUT"; notes="Query exceeded ${TIMEOUT}s limit"; fi
                if [ $exit_code -ne 0 ] && [ $exit_code -ne 124 ]; then status="FAILED"; notes="Program crashed (exit code ${exit_code})"; fi

                load_time=$(grep "LoadTime" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
                exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
                result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*' | head -1)
                peak_mem_kb=$(grep "maximum resident set size" "$log_file" | grep -o '[0-9]*' | tail -1)
                peak_mem_mb=$(echo "scale=1; ${peak_mem_kb:-0} / 1024" | bc -l)

                if [ "$status" != "SUCCESS" ]; then
                    load_time="N/A"; exec_time="N/A"; result_count="N/A"
                fi

                echo "  -> Status: ${status}, Time: ${exec_time:-N/A}s, Results: ${result_count:-N/A}"
                echo "$dataset,$category_name,$(basename "$query_file"),$query_vertices,$query_edges,$threads,$load_time,$exec_time,$result_count,$peak_mem_mb,$status,$notes" >> "$RESULTS_DIR/unified_results.csv"
            done
        done
    done
done

echo ""
echo "========================================="
echo "ADVANCED ANALYSIS COMPLETE"
echo "Results are in: $RESULTS_DIR/unified_results.csv"
echo "========================================="