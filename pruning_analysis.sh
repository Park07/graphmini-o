#!/bin/bash

echo "=== GraphMini Pruning Strategy Analysis ==="
cd /Users/williampark/GraphMini/build

# Pruning strategies to test
PRUNING_TYPES=(
    "0 None"
    "1 Static"
    "2 Eager"
    "3 Online"
    "4 CostModel"
)

DATASETS=("wiki" "enron")
THREAD_COUNTS=(1 2 4 6 8 12 16)

RESULTS_DIR="../pruning_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Dataset,Pruning_Type,Threads,CodeGen_Time,Execution_Time,Result_Count,Throughput,SearchSpace_Reduction" > "$RESULTS_DIR/pruning_results.csv"

for dataset in "${DATASETS[@]}"; do
    echo ""
    echo "=== Testing $dataset dataset ==="

    for threads in "${THREAD_COUNTS[@]}"; do
        echo "  $threads threads:"
        export OMP_NUM_THREADS=$threads

        baseline_time=""

        for pruning_info in "${PRUNING_TYPES[@]}"; do
            read pruning_id pruning_name <<< "$pruning_info"

            echo "    Testing $pruning_name pruning..."

            # Generate code with specific pruning strategy
            codegen_log="$RESULTS_DIR/${dataset}_${pruning_name}_${threads}t_codegen.log"
            ./bin/run "$dataset" "../dataset/GraphMini/$dataset" "triangle" "011101110" 0 "$pruning_id" 3 > "$codegen_log" 2>&1

            # Execute the generated code
            exec_log="$RESULTS_DIR/${dataset}_${pruning_name}_${threads}t_exec.log"
            ./bin/runner 1 "../dataset/GraphMini/$dataset" > "$exec_log" 2>&1

            # Parse results
            codegen_time=$(grep "CODE_GENERATION_TIME" "$codegen_log" | grep -o '[0-9]*\.[0-9]*')
            exec_time=$(grep "CODE_EXECUTION_TIME" "$exec_log" | grep -o '[0-9]*\.[0-9]*')
            result_count=$(grep "RESULT=" "$exec_log" | grep -o '[0-9]*')
            throughput=$(grep "Throughput=" "$exec_log" | grep -o '[0-9]*\.[0-9]*e*[+-]*[0-9]*')

            if [[ -n "$exec_time" && -n "$result_count" ]]; then
                # Calculate search space reduction vs baseline
                if [[ "$pruning_name" == "None" ]]; then
                    baseline_time=$exec_time
                    reduction="0.0"
                else
                    if [[ -n "$baseline_time" ]]; then
                        reduction=$(echo "scale=2; (1 - $exec_time / $baseline_time) * 100" | bc -l 2>/dev/null || echo "0")
                    else
                        reduction="N/A"
                    fi
                fi

                echo "      ✅ ${exec_time}s (${reduction}% improvement over baseline)"
                echo "$dataset,$pruning_name,$threads,$codegen_time,$exec_time,$result_count,$throughput,$reduction" >> "$RESULTS_DIR/pruning_results.csv"
            else
                echo "      ❌ FAILED"
                echo "$dataset,$pruning_name,$threads,FAILED,FAILED,0,0,0" >> "$RESULTS_DIR/pruning_results.csv"
            fi
        done
    done
done

echo ""
echo "=== Pruning Strategy Analysis Complete ==="
echo "Results saved in: $RESULTS_DIR"

# Quick analysis
echo ""
echo "=== Pruning Effectiveness Summary ==="
tail -n +2 "$RESULTS_DIR/pruning_results.csv" | while IFS=',' read dataset pruning threads codegen exec result throughput reduction; do
    if [[ "$exec" != "FAILED" ]]; then
        echo "$dataset + $pruning ($threads threads): ${exec}s execution, ${reduction}% improvement"
    fi
done
