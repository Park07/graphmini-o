#!/bin/bash

cd /Users/williampark/GraphMini/build

# Comprehensive datasets
DATASETS=("wiki" "enron" "dblp")

# Real meaningful patterns from graph mining research
PATTERNS=(
    # Basic patterns
    "triangle 011101110 triangle-3nodes"
    "4path 0110100110100110 path-4nodes"
    "4cycle 0110100110100110 cycle-4nodes"
    "4star 0111100010001000 star-4nodes"
    "4clique 0111101111011110 clique-4nodes"

    # Complex patterns
    "5clique 0111110111110111110111110 clique-5nodes"
    "house 0111110001111100001000 house-5nodes"
    "diamond 011110110001100001000000 diamond-6nodes"
)

# Thread scaling
THREAD_COUNTS=(1 2 4 8 16)

RESULTS_DIR="../unified_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "=== Test Configuration ==="
echo "Datasets: ${#DATASETS[@]} ($(echo ${DATASETS[@]}))"
echo "Patterns: ${#PATTERNS[@]} graph mining patterns"
echo "Thread counts: ${#THREAD_COUNTS[@]} ($(echo ${THREAD_COUNTS[@]}))"
echo "Total tests: $((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))"
echo "Results: $RESULTS_DIR"

# Comprehensive CSV header
echo "Dataset,Graph_Size,Pattern,Pattern_Size,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Throughput,Memory_Peak_MB,Speedup,Efficiency" > "$RESULTS_DIR/unified_results.csv"

# Dataset metadata
declare -A DATASET_SIZES
DATASET_SIZES["wiki"]="7K_nodes_100K_edges"
DATASET_SIZES["enron"]="37K_nodes_184K_edges"
DATASET_SIZES["dblp"]="317K_nodes_1M_edges"

test_count=0
total_tests=$((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))

for dataset in "${DATASETS[@]}"; do
    echo ""
    echo "========================================="
    echo "TESTING DATASET: $dataset (${DATASET_SIZES[$dataset]})"
    echo "========================================="

    for pattern_info in "${PATTERNS[@]}"; do
        read pattern_name pattern_binary pattern_desc <<< "$pattern_info"
        pattern_size=$(echo "sqrt(${#pattern_binary})" | bc -l | cut -d'.' -f1)

        echo ""
        echo "--- Pattern: $pattern_name ($pattern_desc, ${pattern_size}x${pattern_size}) ---"

        # Get baseline performance (1 thread)
        baseline_time=""

        for threads in "${THREAD_COUNTS[@]}"; do
            test_count=$((test_count + 1))
            echo "  [$test_count/$total_tests] Testing $threads threads..."

            export OMP_NUM_THREADS=$threads

            # Generate code for this pattern
            ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3 > /dev/null 2>&1

            # Execute with memory monitoring
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
            /usr/bin/time -l ./bin/runner 1 "../dataset/GraphMini/$dataset" > "$log_file" 2>&1

            # Parse GraphMini results
            load_time=$(grep "LoadTime" "$log_file" | grep -o '[0-9]*\.[0-9]*')
            exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*')
            result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*')
            throughput=$(grep "Throughput=" "$log_file" | grep -o '[0-9]*\.[0-9]*e*[+-]*[0-9]*')

            # Parse system memory usage
            peak_memory_kb=$(grep "maximum resident set size" "$log_file" | grep -o '[0-9]*' | tail -1)
            peak_memory_mb=$((${peak_memory_kb:-0} / 1024))

            # Calculate speedup and efficiency
            if [[ $threads -eq 1 ]]; then
                baseline_time=$exec_time
                speedup="1.00"
                efficiency="100.0"
            elif [[ -n "$baseline_time" && -n "$exec_time" ]]; then
                speedup=$(echo "scale=2; $baseline_time / $exec_time" | bc -l 2>/dev/null || echo "0")
                efficiency=$(echo "scale=1; $speedup / $threads * 100" | bc -l 2>/dev/null || echo "0")
            else
                speedup="N/A"
                efficiency="N/A"
            fi

            if [[ -n "$exec_time" && -n "$result_count" ]]; then
                echo "    ✅ ${exec_time}s, $result_count patterns, $speedup x speedup, ${efficiency}% efficiency"
                echo "$dataset,${DATASET_SIZES[$dataset]},$pattern_name,$pattern_size,$threads,$load_time,$exec_time,$result_count,$throughput,$peak_memory_mb,$speedup,$efficiency" >> "$RESULTS_DIR/unified_results.csv"
            else
                echo "    ❌ FAILED"
                echo "$dataset,${DATASET_SIZES[$dataset]},$pattern_name,$pattern_size,$threads,FAILED,FAILED,0,0,0,0,0" >> "$RESULTS_DIR/unified_results.csv"
            fi
        done
    done
done

echo ""
echo "========================================="
echo "UNIFIED ANALYSIS COMPLETE"
echo "========================================="
echo "Results: $RESULTS_DIR/unified_results.csv"
echo ""

cd "$RESULTS_DIR"
python3 - << 'PYTHON_EOF'
import csv
import sys

try:
    # Read CSV manually to avoid pandas issues
    results = []
    with open('unified_results.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['ExecutionTime_s'] != 'FAILED':
                results.append(row)

    print("=== UNIFIED PERFORMANCE SUMMARY ===")
    print(f"Successful tests: {len(results)}")

    if results:
        print("\n=== Performance by Dataset Size ===")
        datasets = {}
        for row in results:
            dataset = row['Dataset']
            if dataset not in datasets:
                datasets[dataset] = []
            datasets[dataset].append(float(row['ExecutionTime_s']))

        for dataset, times in datasets.items():
            avg_time = sum(times) / len(times)
            print(f"{dataset}: {avg_time:.4f}s average")

        print("\n=== Best Speedups ===")
        best_speedups = {}
        for row in results:
            key = f"{row['Dataset']}_{row['Pattern']}"
            speedup = row['Speedup']
            if speedup != 'N/A' and speedup != '0':
                if key not in best_speedups or float(speedup) > float(best_speedups[key]):
                    best_speedups[key] = speedup

        for key, speedup in best_speedups.items():
            print(f"{key}: {speedup}x maximum speedup")

        print("\n=== Memory Usage Patterns ===")
        memory_usage = [int(row['Memory_Peak_MB']) for row in results if row['Memory_Peak_MB'] != '0']
        if memory_usage:
            print(f"Memory range: {min(memory_usage)}-{max(memory_usage)} MB")
            print(f"Average memory: {sum(memory_usage)/len(memory_usage):.1f} MB")
        else:
            print("Memory usage tracking needs investigation")

except Exception as e:
    print(f"Analysis error: {e}")
    print("Check the CSV file manually")
PYTHON_EOF
