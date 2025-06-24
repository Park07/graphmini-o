#!/bin/bash

# patterns from profile.cpp (P1 - P8)
# Tests performance across different network topologies

GRAPHMINI_HOME="/Users/williampark/GraphMini"
cd "$GRAPHMINI_HOME"

echo "Testing across diverse network topologies"

# REAL patterns from GraphMini source code (profile.cpp)
PATTERNS=(
    # Name | Binary | Size | Description
    "triangle 011101110 3 social-triangle"
    "P1 0111101111011110 4 4x4-subgraph"
    "P2 0110010111110110110001100 5 5x5-subgraph"
)

# Datasets with known topological characteristics
DATASETS=(
    # Name | Type | Characteristics
    "wiki social-political sparse-high-degree-variance"
    "enron communication core--moderate-clustering"
    "dblp collaboration scale-free-high-clustering"
)

THREAD_COUNTS=(1 2 4 8)
RESULTS_DIR="baseline_study_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo ""
echo "Network Topology Coverage:"
echo "- Wiki-vote: "
echo "- Enron: "
echo "- DBLP: "
echo ""
echo "Pattern Complexity Coverage:"
echo "- Triangle: 3x3 basic building block"
echo "- P1: 4x4 moderate complexity"
echo "- P2: 5x5 high complexity"

# Setup datasets
setup_dataset() {
    local dataset="$1"

    if [[ ! -f "dataset/GraphMini/$dataset/meta.txt" ]]; then
        echo "Setting up $dataset dataset..."
        mkdir -p "dataset/GraphMini/$dataset"

        case $dataset in
            "wiki")
                echo "  Downloading Wiki-vote network..."
                curl -sL "https://snap.stanford.edu/data/wiki-Vote.txt.gz" | gunzip > "dataset/GraphMini/$dataset/snap.txt"
                ;;
            "enron")
                echo "  Downloading Enron email network..."
                curl -sL "https://snap.stanford.edu/data/email-Enron.txt.gz" | gunzip > "dataset/GraphMini/$dataset/snap.txt"
                ;;
            "dblp")
                echo "  Downloading DBLP collaboration network..."
                curl -sL "https://snap.stanford.edu/data/bigdata/communities/com-dblp.ungraph.txt.gz" | gunzip > "dataset/GraphMini/$dataset/snap.txt"
                ;;
        esac

        echo "  Preprocessing $dataset..."
        cd build && ./bin/prep "../dataset/GraphMini/$dataset" > /dev/null && cd ..
        echo "  ✓ $dataset ready"
    else
        echo "✓ $dataset already preprocessed"
    fi
}

echo ""
echo "=== Dataset Setup ==="
for dataset_info in "${DATASETS[@]}"; do
    dataset=$(echo $dataset_info | cut -d' ' -f1)
    setup_dataset "$dataset"
done

# Results tracking
results_csv="$RESULTS_DIR/baseline_results.csv"
echo "Dataset,Network_Type,Topology,Pattern,Pattern_Size,Threads,Time_s,Result_Count,Throughput,Speedup,Efficiency" > "$results_csv"

echo ""
echo "=== Performance Testing ==="

total_tests=$((${#PATTERNS[@]} * ${#DATASETS[@]} * ${#THREAD_COUNTS[@]}))
test_count=0

for dataset_info in "${DATASETS[@]}"; do
    dataset=$(echo $dataset_info | cut -d' ' -f1)
    network_type=$(echo $dataset_info | cut -d' ' -f2)
    topology=$(echo $dataset_info | cut -d' ' -f3)

    echo ""
    echo "Testing $dataset ($network_type network, $topology characteristics)"

    for pattern_info in "${PATTERNS[@]}"; do
        pattern_name=$(echo $pattern_info | cut -d' ' -f1)
        pattern_binary=$(echo $pattern_info | cut -d' ' -f2)
        pattern_size=$(echo $pattern_info | cut -d' ' -f3)
        pattern_desc=$(echo $pattern_info | cut -d' ' -f4)

        echo "  Pattern: $pattern_name (${pattern_size}x${pattern_size} $pattern_desc)"

        baseline_time=""

        for threads in "${THREAD_COUNTS[@]}"; do
            test_count=$((test_count + 1))
            echo "    [$test_count/$total_tests] $threads threads..."

            export OMP_NUM_THREADS=$threads

            # Run GraphMini with timeout
            cd build
            timeout 300 ./bin/prof_runner "$dataset" "../dataset/GraphMini/$dataset" "$pattern_name" "$pattern_binary" 0 4 3 > "../$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log" 2>&1
            exit_code=$?
            cd ..

            # Parse results
            log_file="$RESULTS_DIR/${dataset}_${pattern_name}_${threads}t.log"

            if [[ $exit_code -eq 0 ]]; then
                runtime=$(grep "CODE_EXECUTION_TIME" "$log_file" | grep -o '[0-9.]*')
                result_count=$(grep "RESULT=" "$log_file" | grep -o '[0-9]*')

                if [[ -n "$runtime" && -n "$result_count" ]]; then
                    throughput=$(echo "scale=0; $result_count / $runtime" | bc -l 2>/dev/null || echo "0")

                    # Calculate performance metrics
                    if [[ $threads -eq 1 ]]; then
                        baseline_time=$runtime
                        speedup="1.00"
                        efficiency="100.0"
                    else
                        speedup=$(echo "scale=2; $baseline_time / $runtime" | bc -l 2>/dev/null || echo "0")
                        efficiency=$(echo "scale=1; $speedup / $threads * 100" | bc -l 2>/dev/null || echo "0")
                    fi

                    echo "      ${runtime}s, ${result_count} patterns, ${speedup}x speedup, ${efficiency}% efficiency"
                    echo "$dataset,$network_type,$topology,$pattern_name,$pattern_size,$threads,$runtime,$result_count,$throughput,$speedup,$efficiency" >> "$results_csv"
                else
                    echo "      PARSE_ERROR"
                    echo "$dataset,$network_type,$topology,$pattern_name,$pattern_size,$threads,PARSE_ERROR,0,0,0,0" >> "$results_csv"
                fi
            elif [[ $exit_code -eq 124 ]]; then
                echo "      TIMEOUT (>5min)"
                echo "$dataset,$network_type,$topology,$pattern_name,$pattern_size,$threads,TIMEOUT,0,0,0,0" >> "$results_csv"
            else
                echo "      FAILED"
                echo "$dataset,$network_type,$topology,$pattern_name,$pattern_size,$threads,FAILED,0,0,0,0" >> "$results_csv"
            fi

            # Clean up log to save space
            rm -f "$log_file"
        done
    done
done

# Generate comprehensive analysis
echo ""
echo "=== Analysis and Summary ==="

python3 - << EOF
import pandas as pd

# Read results
df = pd.read_csv('$results_csv')
df_success = df[(df['Time_s'] != 'FAILED') & (df['Time_s'] != 'TIMEOUT') & (df['Time_s'] != 'PARSE_ERROR')]

print("\\n" + "="*60)
print("GRAPHMINI BASELINE PERFORMANCE STUDY")
print("="*60)

print(f"\\nTotal tests: {len(df)}")
print(f"Successful: {len(df_success)}")
print(f"Failed: {len(df) - len(df_success)}")

if len(df_success) > 0:
    print("\\n=== PERFORMANCE BY NETWORK TOPOLOGY ===")
    topo_summary = df_success.groupby(['Dataset', 'Network_Type']).agg({
        'Time_s': 'mean',
        'Speedup': 'max',
        'Efficiency': 'mean'
    }).round(3)
    print(topo_summary)

    print("\\n=== SCALABILITY BY PATTERN COMPLEXITY ===")
    pattern_summary = df_success.groupby(['Pattern', 'Pattern_Size']).agg({
        'Time_s': 'mean',
        'Efficiency': 'mean',
        'Speedup': 'max'
    }).round(3)
    print(pattern_summary)

    print("\\n=== BEST PERFORMANCE CONFIGURATIONS ===")
    best_configs = df_success.loc[df_success.groupby(['Dataset', 'Pattern'])['Efficiency'].idxmax()]
    for _, row in best_configs.iterrows():
        print(f"{row['Dataset']:8} + {row['Pattern']:8}: {row['Threads']}t, {row['Time_s']:8.3f}s, {row['Efficiency']:5.1f}% efficiency")

    print("\\n=== KEY FINDINGS ===")
    print("1. Network Topology:")
    avg_by_type = df_success.groupby('Network_Type')['Efficiency'].mean()
    for net_type, eff in avg_by_type.items():
        print(f"   {net_type}: {eff:.1f}% average efficiency")

    print("\\n2. Pattern Complexity Impact:")
    avg_by_pattern = df_success.groupby('Pattern_Size')['Time_s'].mean()
    for size, time in avg_by_pattern.items():
        print(f"   {size}x{size} patterns: {time:.3f}s average runtime")

    print("\\n3. Scalability Characteristics:")
    max_speedup = df_success.groupby('Dataset')['Speedup'].max()
    for dataset, speedup in max_speedup.items():
        print(f"   {dataset}: {speedup:.2f}x maximum speedup")

print(f"\\nDetailed results saved in: $RESULTS_DIR")
print("\\n" + "="*60)
print("BASELINE ESTABLISHED FOR ALGORITHM COMPARISON")
print("="*60)
EOF


echo "Results saved in: $RESULTS_DIR"