#!/bin/bash

echo "=== GraphMini Medium Dataset Performance Framework ==="
cd build

# Medium datasets
DATASETS=("youtube" "patents" "lj")

# Complete pattern list (8 patterns)
PATTERNS=(
    "triangle 011101110 triangle-3nodes"
    "4cycle 0111101110011110 cycle-4nodes"
    "4clique 0111101111011110 clique-4nodes"
)

# Thread scaling
THREAD_COUNTS=(1 2 4 8 16)
BRANCH_NAME=$(git branch --show-current 2>/dev/null || echo "unknown")
RESULTS_DIR="../unified_results_medium_${BRANCH_NAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "=== Test Configuration ==="
echo "Datasets: ${#DATASETS[@]} ($(echo ${DATASETS[@]}))"
echo "Patterns: ${#PATTERNS[@]} graph mining patterns"
echo "Thread counts: ${#THREAD_COUNTS[@]} ($(echo ${THREAD_COUNTS[@]}))"
echo "Total tests: $((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))"
echo "Results: $RESULTS_DIR"

# Check if datasets are ready
echo ""
echo "=== Checking Dataset Status ==="
all_ready=true
for dataset in "${DATASETS[@]}"; do
    if [[ -f "../dataset/GraphMini/$dataset/meta.txt" ]]; then
        vertices=$(grep "NUM_VERTEX" "../dataset/GraphMini/$dataset/meta.txt" | awk '{print $2}')
        edges=$(grep "NUM_EDGE" "../dataset/GraphMini/$dataset/meta.txt" | awk '{print $2}')
        echo "✅ $dataset: $vertices vertices, $edges edges"
    else
        echo "❌ $dataset: Not processed yet"
        all_ready=false
    fi
done

if [[ "$all_ready" = false ]]; then
    echo ""
    echo "Some datasets not ready. Please process them first:"
    echo "  ./build/bin/prep dataset/GraphMini/youtube/"
    echo "  ./build/bin/prep dataset/GraphMini/patents/"
    echo "  ./build/bin/prep dataset/GraphMini/lj/"
    exit 1
fi

# CSV header
echo "Dataset,Graph_Size,Pattern,Pattern_Size,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Throughput,Memory_Peak_MB,Speedup,Efficiency,Baseline_s,Notes" > "$RESULTS_DIR/unified_results.csv"

# Dataset metadata for medium datasets
declare -A DATASET_SIZES
DATASET_SIZES["youtube"]="1.1M_nodes_3M_edges"
DATASET_SIZES["patents"]="3.8M_nodes_16.5M_edges"
DATASET_SIZES["lj"]="4M_nodes_34.7M_edges"

declare -A pattern_baselines
declare -A pattern_baseline_status

test_count=0
total_tests=$((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))
start_time=$(date +%s)

for dataset in "${DATASETS[@]}"; do
    echo ""
    echo "========================================="
    echo "TESTING DATASET: $dataset"
    echo "========================================="

    for pattern_info in "${PATTERNS[@]}"; do
        read pattern_name pattern_binary pattern_desc <<< "$pattern_info"
        pattern_size=$(echo "sqrt(${#pattern_binary})" | bc -l | cut -d'.' -f1)

        echo ""
        echo "--- Pattern: $pattern_name ($pattern_desc, ${pattern_size}x${pattern_size}) ---"

        baseline_key="${dataset}_${pattern_name}"

        for threads in "${THREAD_COUNTS[@]}"; do
            test_count=$((test_count + 1))
            current_time=$(date +%s)
            elapsed_hours=$(( (current_time - start_time) / 3600 ))

            echo "  [$test_count/$total_tests] Testing $threads threads (${elapsed_hours}h elapsed)..."

            export OMP_NUM_THREADS=$threads

            # Generate code for this pattern
            ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3

            # Execute with memory monitoring
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
            /usr/bin/time -l ./bin/runner 1 "../dataset/GraphMini/$dataset" > "$log_file" 2>&1
            exit_code=$?

            # Parse results
            load_time=$(grep "LoadTime" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
            exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
            result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*' | head -1)
            throughput=$(grep "Throughput=" "$log_file" | grep -o '[0-9]*\.[0-9]*e*[+-]*[0-9]*' | head -1)

            # Memory calculation
            peak_memory_kb=$(grep "maximum resident set size" "$log_file" | grep -o '[0-9]*' | tail -1)
            if [[ -n "$peak_memory_kb" && "$peak_memory_kb" -gt 0 ]]; then
                peak_memory_mb=$(echo "scale=1; $peak_memory_kb / 1024" | bc -l)
            else
                peak_memory_mb="0"
            fi

            # Baseline management
            if [[ $threads -eq 1 ]]; then
                if [[ -n "$exec_time" && "$exec_time" != "0" && $exit_code -eq 0 ]]; then
                    pattern_baselines["$baseline_key"]="$exec_time"
                    pattern_baseline_status["$baseline_key"]="SUCCESS"
                    speedup="1.000"
                    efficiency="100.00"
                    baseline_time="$exec_time"
                    notes="baseline"
                    echo "    ✅ ${exec_time}s, $result_count patterns, baseline established"
                else
                    pattern_baseline_status["$baseline_key"]="FAILED"
                    speedup="N/A"
                    efficiency="N/A"
                    baseline_time="FAILED"
                    notes="baseline_failed"
                    echo "    ❌ BASELINE FAILED"
                fi
            else
                baseline_time="${pattern_baselines[$baseline_key]}"
                baseline_status="${pattern_baseline_status[$baseline_key]}"

                if [[ "$baseline_status" == "SUCCESS" && -n "$exec_time" && "$exec_time" != "0" && $exit_code -eq 0 ]]; then
                    speedup=$(echo "scale=4; $baseline_time / $exec_time" | bc -l 2>/dev/null)
                    efficiency=$(echo "scale=3; $speedup / $threads * 100" | bc -l 2>/dev/null)
                    speedup_display=$(echo "scale=2; $speedup" | bc -l)
                    efficiency_display=$(echo "scale=1; $efficiency" | bc -l)
                    notes="calculated"
                    echo "    ✅ ${exec_time}s, $result_count patterns, ${speedup_display}x speedup, ${efficiency_display}% efficiency"
                else
                    speedup="N/A"
                    efficiency="N/A"
                    notes="test_failed"
                    echo "    ❌ FAILED (exit_code: $exit_code)"
                fi
            fi

            # Write to CSV
            dataset_size="${DATASET_SIZES[$dataset]}"
            if [[ -n "$exec_time" && -n "$result_count" && $exit_code -eq 0 ]]; then
                echo "$dataset,$dataset_size,$pattern_name,$pattern_size,$threads,$load_time,$exec_time,$result_count,$throughput,$peak_memory_mb,$speedup,$efficiency,$baseline_time,$notes" >> "$RESULTS_DIR/unified_results.csv"
            else
                echo "$dataset,$dataset_size,$pattern_name,$pattern_size,$threads,FAILED,FAILED,0,0,0,FAILED,FAILED,${baseline_time:-FAILED},test_failed" >> "$RESULTS_DIR/unified_results.csv"
            fi
        done
    done
done

echo ""
echo "========================================="
echo "MEDIUM DATASET TESTING COMPLETE"
echo "========================================="
total_time_hours=$(( ($(date +%s) - start_time) / 3600 ))
echo "Total time: ${total_time_hours}h"
echo "Results: $RESULTS_DIR/unified_results.csv"
echo ""

# Analysis
cd "$RESULTS_DIR"
python3 - << 'PYTHON_EOF'
import csv
from collections import defaultdict

try:
    results = []
    failed_results = []

    with open('unified_results.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['ExecutionTime_s'] != 'FAILED':
                results.append(row)
            else:
                failed_results.append(row)

    print("=== MEDIUM DATASET PERFORMANCE SUMMARY ===")
    print(f"Successful tests: {len(results)}")
    print(f"Failed tests: {len(failed_results)}")

    if results:
        print(f"\n=== Performance by Dataset ===")
        for dataset in ["youtube", "patents", "lj"]:
            dataset_results = [r for r in results if r['Dataset'] == dataset]
            if dataset_results:
                times = [float(r['ExecutionTime_s']) for r in dataset_results]
                avg_time = sum(times) / len(times)
                print(f"{dataset:8s}: {avg_time:8.2f}s avg ({len(times)} tests)")

        print(f"\n=== Thread Scaling ===")
        for threads in [1, 2, 4, 8, 16]:
            thread_results = [r for r in results if int(r['Threads']) == threads]
            if thread_results:
                times = [float(r['ExecutionTime_s']) for r in thread_results]
                avg_time = sum(times) / len(times)
                print(f"{threads:2d} threads: {avg_time:8.2f}s avg")

    if failed_results:
        print(f"\n=== Failed Tests ===")
        for dataset in ["youtube", "patents", "lj"]:
            failed_count = len([r for r in failed_results if r['Dataset'] == dataset])
            if failed_count > 0:
                print(f"{dataset}: {failed_count} failures")

except Exception as e:
    print(f"Analysis error: {e}")
PYTHON_EOF