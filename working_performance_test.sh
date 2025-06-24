#!/bin/bash

echo "=== GraphMini Complete Performance Analysis ==="
cd /Users/williampark/GraphMini/build

# Test configurations
DATASETS=("wiki" "enron" "dblp")
PATTERNS=(
    "triangle 011101110"
    "P1 0111101111011110"
    "P2 0110010111110110110001100"
)
THREAD_COUNTS=(1 2 4 8)

RESULTS_DIR="../complete_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Testing ${#DATASETS[@]} datasets × ${#PATTERNS[@]} patterns × ${#THREAD_COUNTS[@]} thread counts"
echo "Results will be saved to: $RESULTS_DIR"

# CSV header
echo "Dataset,Pattern,Threads,LoadTime_s,ExecutionTime_s,Result_Count,Throughput,VertexMem_MB,MiniGraphMem_MB" > "$RESULTS_DIR/performance_results.csv"

test_count=0
total_tests=$((${#DATASETS[@]} * ${#PATTERNS[@]} * ${#THREAD_COUNTS[@]}))

for dataset in "${DATASETS[@]}"; do
    for pattern_info in "${PATTERNS[@]}"; do
        read pattern_name pattern_binary <<< "$pattern_info"
        
        echo ""
        echo "=== Testing $dataset + $pattern_name ==="
        
        for threads in "${THREAD_COUNTS[@]}"; do
            test_count=$((test_count + 1))
            echo "  [$test_count/$total_tests] $threads threads..."
            
            export OMP_NUM_THREADS=$threads
            
            # First generate code with run
            ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3 > /dev/null 2>&1
            
            # Then execute with runner
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"
            ./bin/runner 1 "../dataset/GraphMini/$dataset" > "$log_file" 2>&1
            
            # Parse results
            load_time=$(grep "LoadTime" "$log_file" | grep -o '[0-9]*\.[0-9]*')
            exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9]*\.[0-9]*')
            result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*')
            throughput=$(grep "Throughput=" "$log_file" | grep -o '[0-9]*\.[0-9]*e*[+-]*[0-9]*')
            vertex_mem=$(grep "VertexSetAllocated=" "$log_file" | grep -o '[0-9]*\.[0-9]*')
            minigraph_mem=$(grep "MiniGraphAllocated=" "$log_file" | grep -o '[0-9]*\.[0-9]*')
            
            if [[ -n "$exec_time" && -n "$result_count" ]]; then
                echo "    ✅ ${exec_time}s, $result_count patterns, ${throughput} patterns/sec"
                echo "$dataset,$pattern_name,$threads,$load_time,$exec_time,$result_count,$throughput,$vertex_mem,$minigraph_mem" >> "$RESULTS_DIR/performance_results.csv"
            else
                echo "    ❌ FAILED - check log"
                echo "$dataset,$pattern_name,$threads,FAILED,FAILED,0,0,0,0" >> "$RESULTS_DIR/performance_results.csv"
            fi
        done
    done
done

echo ""
echo "=== Performance Analysis Complete ==="
echo "Results saved in: $RESULTS_DIR/performance_results.csv"
echo ""
echo "=== Quick Summary ==="
head -5 "$RESULTS_DIR/performance_results.csv"
