#!/bin/bash

echo "=== GraphMini Comprehensive Performance Analysis ==="
cd /Users/williampark/GraphMini/build

# Test configurations
DATASETS=("wiki" "enron" "dblp")
PATTERNS=(
    "triangle 011101110 triangle-counting"
    "P1 0111101111011110 4-node-clique"
    "P2 0110010111110110110001100 5-node-pattern"
)
THREAD_COUNTS=(1 2 4 8)

RESULTS_DIR="../comprehensive_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo "Testing ${#DATASETS[@]} datasets × ${#PATTERNS[@]} patterns × ${#THREAD_COUNTS[@]} thread counts = $((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]})) total tests"

# CSV header for results
echo "Dataset,Pattern,Threads,CodeGen_Time,Execution_Time,Result_Count,Memory_MB,Throughput" > "$RESULTS_DIR/performance_results.csv"

test_count=0
for dataset in "${DATASETS[@]}"; do
    for pattern_info in "${PATTERNS[@]}"; do
        read pattern_name pattern_binary pattern_desc <<< "$pattern_info"
        
        echo ""
        echo "=== Testing $dataset + $pattern_name ($pattern_desc) ==="
        
        for threads in "${THREAD_COUNTS[@]}"; do
            test_count=$((test_count + 1))
            echo "  [$test_count] $threads threads..."
            
            export OMP_NUM_THREADS=$threads
            
            # Run with memory monitoring
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
            
            # Time the entire execution
            start_time=$(date +%s.%N)
            
            # Monitor memory usage during execution
            ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3 > "$log_file" 2>&1 &
            run_pid=$!
            
            # Track peak memory usage
            peak_memory=0
            while kill -0 $run_pid 2>/dev/null; do
                current_memory=$(ps -p $run_pid -o rss= 2>/dev/null | tr -d ' ')
                if [[ -n "$current_memory" && $current_memory -gt $peak_memory ]]; then
                    peak_memory=$current_memory
                fi
                sleep 0.1
            done
            
            wait $run_pid
            end_time=$(date +%s.%N)
            total_time=$(echo "$end_time - $start_time" | bc -l)
            
            # Parse results from log
            codegen_time=$(grep "CODE_GENERATION_TIME" "$log_file" | grep -o '[0-9.]*')
            execution_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9.]*')
            result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*')
            
            if [[ -n "$execution_time" && -n "$result_count" ]]; then
                memory_mb=$((peak_memory / 1024))
                throughput=$(echo "scale=0; $result_count / $execution_time" | bc -l 2>/dev/null || echo "0")
                
                echo "    Execution: ${execution_time}s, Results: $result_count, Memory: ${memory_mb}MB"
                echo "$dataset,$pattern_name,$threads,$codegen_time,$execution_time,$result_count,$memory_mb,$throughput" >> "$RESULTS_DIR/performance_results.csv"
            else
                echo "    INCOMPLETE - check $log_file"
                echo "$dataset,$pattern_name,$threads,FAILED,FAILED,0,0,0" >> "$RESULTS_DIR/performance_results.csv"
            fi
        done
    done
done

echo ""
echo "=== Performance Analysis ==="
echo "Results saved in: $RESULTS_DIR"

# Quick analysis
python3 - << 'PYTHON_EOF'
import pandas as pd
import sys

try:
    df = pd.read_csv('performance_results.csv')
    df_success = df[df['Execution_Time'] != 'FAILED']
    
    print("\n=== SUMMARY ===")
    print(f"Successful tests: {len(df_success)}/{len(df)}")
    
    if len(df_success) > 0:
        print("\n=== Performance by Dataset ===")
        dataset_perf = df_success.groupby('Dataset').agg({
            'Execution_Time': 'mean',
            'Memory_MB': 'mean', 
            'Throughput': 'mean'
        }).round(3)
        print(dataset_perf)
        
        print("\n=== Scalability Analysis ===")
        for dataset in df_success['Dataset'].unique():
            for pattern in df_success['Pattern'].unique():
                subset = df_success[(df_success['Dataset'] == dataset) & (df_success['Pattern'] == pattern)]
                if len(subset) > 1:
                    baseline = subset[subset['Threads'] == 1]['Execution_Time'].iloc[0] if len(subset[subset['Threads'] == 1]) > 0 else None
                    if baseline:
                        print(f"\n{dataset} + {pattern}:")
                        for _, row in subset.iterrows():
                            speedup = float(baseline) / float(row['Execution_Time'])
                            efficiency = speedup / row['Threads'] * 100
                            print(f"  {int(row['Threads'])}t: {speedup:.2f}x speedup, {efficiency:.1f}% efficiency")

except Exception as e:
    print(f"Analysis failed: {e}")
PYTHON_EOF

echo ""
echo "=== Files Created ==="
ls -la "$RESULTS_DIR"
