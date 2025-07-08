#!/bin/bash

echo "=== GraphMini Correctness Verification ==="

# Test configurations
DATASETS=("wiki" "enron") 
PATTERNS=("triangle 011101110")
THREAD_COUNTS=(1 2 4 8)

RESULTS_DIR="correctness_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# CSV for results comparison
echo "Branch,Dataset,Pattern,Threads,Result_Count,Execution_Time,Success" > "$RESULTS_DIR/correctness_comparison.csv"

# Function to test a specific configuration
test_configuration() {
    local branch="$1"
    local dataset="$2" 
    local pattern_name="$3"
    local pattern_binary="$4"
    local threads="$5"
    
    export OMP_NUM_THREADS=$threads
    cd build
    
    log_file="../$RESULTS_DIR/${branch}_${dataset}_${pattern_name}_${threads}t.log"
    ./bin/runner 1 "../dataset/GraphMini/$dataset" > "$log_file" 2>&1
    
    # Parse results
    result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*')
    exec_time=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9.]*')
    
    if [[ -n "$result_count" ]]; then
        echo "$branch,$dataset,$pattern_name,$threads,$result_count,$exec_time,SUCCESS" >> "../$RESULTS_DIR/correctness_comparison.csv"
        echo "  ✅ $branch: $result_count results in ${exec_time}s"
    else
        echo "$branch,$dataset,$pattern_name,$threads,FAILED,FAILED,FAILED" >> "../$RESULTS_DIR/correctness_comparison.csv"
        echo "  ❌ $branch: FAILED"
    fi
    
    cd ..
}

echo "Current branch: $(git branch --show-current)"
echo "Testing current implementation..."

for dataset in "${DATASETS[@]}"; do
    for pattern_info in "${PATTERNS[@]}"; do
        read pattern_name pattern_binary <<< "$pattern_info"
        echo ""
        echo "=== Testing $dataset + $pattern_name ==="
        
        for threads in "${THREAD_COUNTS[@]}"; do
            echo "  $threads threads..."
            test_configuration "modified" "$dataset" "$pattern_name" "$pattern_binary" "$threads"
        done
    done
done

echo ""
echo "=== Results Summary ==="
cat "$RESULTS_DIR/correctness_comparison.csv"

echo ""
echo "=== Next: Test Original Implementation ==="
echo "1. Switch to clean branch: git checkout main"
echo "2. Build original: cd build && make clean && make runner"  
echo "3. Run this script again to compare results"
echo ""
echo "Results saved in: $RESULTS_DIR"
