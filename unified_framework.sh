#!/bin/bash

echo "=== GraphMini Unified Performance Framework ==="
cd /Users/williampark/GraphMini/build

# Comprehensive datasets
DATASETS=("wiki" "enron" "dblp")

# Real meaningful patterns from graph mining research
PATTERNS=(
    # Basic patterns
    "triangle 011101110 triangle-3nodes"
    "4path 0110100110100110 path-4nodes"
    "4cycle 0111101110011110 cycle-4nodes"
    "4star 0111100010001000 star-4nodes"
    "4clique 0111101111011110 clique-4nodes"

    # Complex patterns
    "5clique 0111110111110111110111110 clique-5nodes"
    "house 0111010101110001000101010 house-5nodes"
    "diamond 0111101111011110 diamond-4nodes"

)

# Thread scaling
THREAD_COUNTS=(1 2 4 8 16)
BRANCH_NAME=$(git branch --show-current)
RESULTS_DIR="../unified_results_${BRANCH_NAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "=== Test Configuration ==="
echo "Datasets: ${#DATASETS[@]} ($(echo ${DATASETS[@]}))"
echo "Patterns: ${#PATTERNS[@]} graph mining patterns"
echo "Thread counts: ${#THREAD_COUNTS[@]} ($(echo ${THREAD_COUNTS[@]}))"
echo "Total tests: $((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))"
echo "Results: $RESULTS_DIR"

# Comprehensive CSV header
echo "Dataset,Graph_Size,Pattern,Pattern_Size,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Throughput,Memory_Peak_MB,Speedup,Efficiency,Baseline_s,Notes" > "$RESULTS_DIR/unified_results.csv"

# Dataset metadata (fix the associative array declaration)
if [[ "${BASH_VERSION%%.*}" -ge 4 ]]; then
    declare -A DATASET_SIZES
    DATASET_SIZES["wiki"]="7K_nodes_100K_edges"
    DATASET_SIZES["enron"]="37K_nodes_184K_edges"
    DATASET_SIZES["dblp"]="317K_nodes_1M_edges"
else
    # Fallback for older bash versions
    echo "Warning: Using bash version < 4, associative arrays not supported"
fi

# FIXED: Use associative array for baselines per pattern+dataset
declare -A pattern_baselines
declare -A pattern_baseline_status

test_count=0
total_tests=$((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))

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

        # FIXED: Create unique key for each dataset+pattern combination
        baseline_key="${dataset}_${pattern_name}"

        for threads in "${THREAD_COUNTS[@]}"; do
            test_count=$((test_count + 1))
            echo "  [$test_count/$total_tests] Testing $threads threads..."

            export OMP_NUM_THREADS=$threads

            # Generate code for this pattern
            ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3

            # Execute with memory monitoring
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
            /usr/bin/time -l ./bin/runner 1 "../dataset/GraphMini/$dataset" > "$log_file" 2>&1
            exit_code=$?

            # Parse GraphMini results
            load_time=$(grep "LoadTime" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
            exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*' | head -1)
            result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*' | head -1)
            throughput=$(grep "Throughput=" "$log_file" | grep -o '[0-9]*\.[0-9]*e*[+-]*[0-9]*' | head -1)

            # FIXED: Better memory calculation with floating point
            peak_memory_kb=$(grep "maximum resident set size" "$log_file" | grep -o '[0-9]*' | tail -1)
            if [[ -n "$peak_memory_kb" && "$peak_memory_kb" -gt 0 ]]; then
                peak_memory_mb=$(echo "scale=1; $peak_memory_kb / 1024" | bc -l)
            else
                peak_memory_mb="0"
            fi

            # FIXED: Better baseline management and calculation
            notes=""

            if [[ $threads -eq 1 ]]; then
                # Store baseline for this pattern+dataset combination
                if [[ -n "$exec_time" && "$exec_time" != "0" && $exit_code -eq 0 ]]; then
                    pattern_baselines["$baseline_key"]="$exec_time"
                    pattern_baseline_status["$baseline_key"]="SUCCESS"
                    speedup="1.000"
                    efficiency="100.00"
                    baseline_time="$exec_time"
                    notes="baseline"
                else
                    pattern_baseline_status["$baseline_key"]="FAILED"
                    speedup="N/A"
                    efficiency="N/A"
                    baseline_time="FAILED"
                    notes="baseline_failed"
                fi
            else
                # Use stored baseline for calculations
                baseline_time="${pattern_baselines[$baseline_key]}"
                baseline_status="${pattern_baseline_status[$baseline_key]}"

                if [[ "$baseline_status" == "SUCCESS" && -n "$exec_time" && "$exec_time" != "0" && $exit_code -eq 0 ]]; then
                    # FIXED: Higher precision calculations
                    speedup=$(echo "scale=4; $baseline_time / $exec_time" | bc -l 2>/dev/null)
                    if [[ -n "$speedup" && "$speedup" != "0" ]]; then
                        efficiency=$(echo "scale=3; $speedup / $threads * 100" | bc -l 2>/dev/null)
                        # Round for display but keep precision in CSV
                        speedup_display=$(echo "scale=2; $speedup" | bc -l)
                        efficiency_display=$(echo "scale=1; $efficiency" | bc -l)
                        notes="calculated"
                    else
                        speedup="N/A"
                        efficiency="N/A"
                        speedup_display="N/A"
                        efficiency_display="N/A"
                        notes="calc_error"
                    fi
                elif [[ "$baseline_status" == "FAILED" ]]; then
                    speedup="N/A"
                    efficiency="N/A"
                    speedup_display="N/A"
                    efficiency_display="N/A"
                    notes="no_baseline"
                else
                    speedup="N/A"
                    efficiency="N/A"
                    speedup_display="N/A"
                    efficiency_display="N/A"
                    notes="test_failed"
                fi
            fi

            # FIXED: Better success/failure detection
            if [[ -n "$exec_time" && -n "$result_count" && $exit_code -eq 0 ]]; then
                if [[ $threads -eq 1 ]]; then
                    echo "    ✅ ${exec_time}s, $result_count patterns, baseline established"
                else
                    echo "    ✅ ${exec_time}s, $result_count patterns, ${speedup_display}x speedup, ${efficiency_display}% efficiency"
                fi

                # Get dataset size for CSV
                dataset_size=""
                case $dataset in
                    "wiki") dataset_size="7K_nodes_100K_edges" ;;
                    "enron") dataset_size="37K_nodes_184K_edges" ;;
                    "dblp") dataset_size="317K_nodes_1M_edges" ;;
                    *) dataset_size="unknown" ;;
                esac

                echo "$dataset,$dataset_size,$pattern_name,$pattern_size,$threads,$load_time,$exec_time,$result_count,$throughput,$peak_memory_mb,$speedup,$efficiency,$baseline_time,$notes" >> "$RESULTS_DIR/unified_results.csv"
            else
                echo "    ❌ FAILED (exit_code: $exit_code)"

                # Get dataset size for CSV
                dataset_size=""
                case $dataset in
                    "wiki") dataset_size="7K_nodes_100K_edges" ;;
                    "enron") dataset_size="37K_nodes_184K_edges" ;;
                    "dblp") dataset_size="317K_nodes_1M_edges" ;;
                    *) dataset_size="unknown" ;;
                esac

                echo "$dataset,$dataset_size,$pattern_name,$pattern_size,$threads,FAILED,FAILED,0,0,0,FAILED,FAILED,${baseline_time:-FAILED},test_failed" >> "$RESULTS_DIR/unified_results.csv"
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

# FIXED: Improved analysis with better error handling
cd "$RESULTS_DIR"
python3 - << 'PYTHON_EOF'
import csv
import sys
from collections import defaultdict

try:
    # Read CSV manually
    results = []
    failed_results = []

    with open('unified_results.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['ExecutionTime_s'] != 'FAILED':
                results.append(row)
            else:
                failed_results.append(row)

    print("=== UNIFIED PERFORMANCE SUMMARY ===")
    print(f"Successful tests: {len(results)}")
    print(f"Failed tests: {len(failed_results)}")

    if results:
        print(f"\n=== Performance by Dataset ===")
        datasets = defaultdict(list)
        for row in results:
            dataset = row['Dataset']
            exec_time = float(row['ExecutionTime_s'])
            datasets[dataset].append(exec_time)

        for dataset, times in datasets.items():
            avg_time = sum(times) / len(times)
            min_time = min(times)
            max_time = max(times)
            print(f"{dataset:6s}: {avg_time:.4f}s avg ({min_time:.4f}s - {max_time:.4f}s)")

        print(f"\n=== Speedup Analysis ===")
        # Group by pattern+dataset to find best speedup for each
        best_speedups = {}
        speedup_data = defaultdict(list)

        for row in results:
            speedup_str = row['Speedup']
            if speedup_str not in ['N/A', 'FAILED', '']:
                try:
                    speedup = float(speedup_str)
                    key = f"{row['Dataset']}_{row['Pattern']}"
                    speedup_data[key].append(speedup)

                    if key not in best_speedups or speedup > best_speedups[key]:
                        best_speedups[key] = speedup
                except ValueError:
                    continue

        print("Best speedup per pattern+dataset:")
        for key, speedup in sorted(best_speedups.items(), key=lambda x: x[1], reverse=True):
            print(f"  {key:20s}: {speedup:.3f}x")

        print(f"\n=== Efficiency Analysis ===")
        # Analyze efficiency patterns by thread count
        efficiency_by_threads = defaultdict(list)

        for row in results:
            efficiency_str = row['Efficiency']
            threads = int(row['Threads'])
            if efficiency_str not in ['N/A', 'FAILED', '']:
                try:
                    efficiency = float(efficiency_str)
                    efficiency_by_threads[threads].append(efficiency)
                except ValueError:
                    continue

        print("Average efficiency by thread count:")
        for threads in sorted(efficiency_by_threads.keys()):
            efficiencies = efficiency_by_threads[threads]
            avg_eff = sum(efficiencies) / len(efficiencies)
            min_eff = min(efficiencies)
            max_eff = max(efficiencies)
            print(f"  {threads:2d} threads: {avg_eff:5.1f}% avg ({min_eff:.1f}% - {max_eff:.1f}%)")

        print(f"\n=== Memory Usage ===")
        memory_usage = []
        for row in results:
            mem_str = row['Memory_Peak_MB']
            if mem_str not in ['0', 'FAILED', '']:
                try:
                    memory_usage.append(float(mem_str))
                except ValueError:
                    continue

        if memory_usage:
            avg_mem = sum(memory_usage) / len(memory_usage)
            print(f"Memory range: {min(memory_usage):.1f} - {max(memory_usage):.1f} MB")
            print(f"Average memory: {avg_mem:.1f} MB")

        print(f"\n=== Baseline Status Analysis ===")
        baseline_status = defaultdict(int)
        for row in results + failed_results:
            notes = row.get('Notes', '')
            baseline_status[notes] += 1

        for status, count in baseline_status.items():
            print(f"  {status:15s}: {count:3d} tests")

    else:
        print("No successful results to analyze!")

    if failed_results:
        print(f"\n=== Failed Tests Breakdown ===")
        failed_by_pattern = defaultdict(int)
        for row in failed_results:
            pattern = row['Pattern']
            failed_by_pattern[pattern] += 1

        for pattern, count in sorted(failed_by_pattern.items()):
            print(f"  {pattern:10s}: {count} failures")

except Exception as e:
    print(f"Analysis error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_EOF

