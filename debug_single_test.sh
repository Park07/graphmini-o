#!/bin/bash

echo "=== Debugging Single Test ==="

PROJECT_ROOT="/Users/williampark/graphmini-o"
cd "$PROJECT_ROOT"

query_file="queries/wiki/small_sparse/query_sparse_8_1.graph"
test_name="query_sparse_8_1"

echo "Converting pattern..."
pattern_binary=$(python3 query_to_binary.py "$query_file")
echo "Pattern: $pattern_binary"

echo "Testing with 1 thread..."
echo "Command that will run:"
echo "./build/bin/run wiki ./dataset/GraphMini/wiki $test_name '$pattern_binary' 0 4 3"
echo ""

# Test code generation only first
echo "=== Code Generation Test ==="
./build/bin/run wiki ./dataset/GraphMini/wiki $test_name "$pattern_binary" 0 4 3
codegen_exit=$?
echo "Code generation exit: $codegen_exit"

if [ $codegen_exit -eq 0 ]; then
    echo "=== Runner Test ==="
    ./build/bin/runner 1 ./dataset/GraphMini/wiki
    runner_exit=$?
    echo "Runner exit: $runner_exit"
else
    echo "Code generation failed, skipping runner"
fi
