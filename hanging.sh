#!/bin/bash

echo "=== Debugging the Hanging Issue ==="
echo "The mutex fix prevented the crash, but now it's hanging"
echo ""

cd /Users/williampark/GraphMini/build

echo "=== Test 1: Single Thread (No Parallelism) ==="
echo "This will tell us if it's a threading issue or algorithmic complexity"

export OMP_NUM_THREADS=1
echo "Testing with 1 thread..."
timeout 30 ./bin/runner 1 "../dataset/GraphMini/wiki" > single_thread_test.log 2>&1
exit_code=$?

if [ $exit_code -eq 0 ]; then
    result=$(grep "RESULT=" single_thread_test.log | grep -o '[0-9]*')
    time=$(grep "CODE_EXECUTION_TIME" single_thread_test.log | grep -o '[0-9]*\.[0-9]*')
    echo "✅ Single thread WORKS: Result=$result, Time=${time}s"
    echo "→ Issue is definitely threading-related"
elif [ $exit_code -eq 124 ]; then
    echo "❌ Single thread TIMEOUT (30s)"
    echo "→ Issue might be algorithmic complexity, not just threading"
else
    echo "❌ Single thread FAILED: Exit code $exit_code"
fi

echo ""
echo "=== Test 2: Different Thread Counts ==="
echo "Find which thread count causes the hang"

for threads in 1 2 4 8; do
    echo "Testing $threads threads (15s timeout)..."
    export OMP_NUM_THREADS=$threads

    timeout 15 ./bin/runner 1 "../dataset/GraphMini/wiki" > "test_${threads}t.log" 2>&1
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        result=$(grep "RESULT=" "test_${threads}t.log" | grep -o '[0-9]*')
        time=$(grep "CODE_EXECUTION_TIME" "test_${threads}t.log" | grep -o '[0-9]*\.[0-9]*')
        echo "  ✅ $threads threads: Result=$result, Time=${time}s"
    elif [ $exit_code -eq 124 ]; then
        echo "  ❌ $threads threads: TIMEOUT"
    else
        echo "  ❌ $threads threads: FAILED"
    fi
done

echo ""
echo "=== Test 3: Simpler Pattern on Same Dataset ==="
echo "Test if wiki dataset + 4 threads works with simpler patterns"

export OMP_NUM_THREADS=4

# Test triangle (simple 3-node pattern)
echo "Testing triangle pattern..."
./bin/run wiki ../dataset/GraphMini/wiki triangle 011101110 0 4 0 > /dev/null 2>&1
timeout 10 ./bin/runner 1 "../dataset/GraphMini/wiki" > triangle_4t_test.log 2>&1
if [ $? -eq 0 ]; then
    result=$(grep "RESULT=" triangle_4t_test.log | grep -o '[0-9]*')
    echo "  ✅ Triangle works: $result"
else
    echo "  ❌ Even triangle hangs with 4 threads"
fi

# Test 4clique (4-node pattern)
echo "Testing 4clique pattern..."
./bin/run wiki ../dataset/GraphMini/wiki 4clique 0111101111011110 0 4 0 > /dev/null 2>&1
timeout 20 ./bin/runner 1 "../dataset/GraphMini/wiki" > clique_4t_test.log 2>&1
if [ $? -eq 0 ]; then
    result=$(grep "RESULT=" clique_4t_test.log | grep -o '[0-9]*')
    echo "  ✅ 4clique works: $result"
else
    echo "  ❌ 4clique also hangs"
fi

echo ""
echo "=== Test 4: House Pattern on Smaller Dataset ==="
echo "Test if house pattern works on smaller datasets"

export OMP_NUM_THREADS=4

# Test house on enron (smaller dataset)
echo "Testing house on enron dataset..."
./bin/run enron ../dataset/GraphMini/enron house 0111010101110001000101010 0 4 0 > /dev/null 2>&1
timeout 30 ./bin/runner 1 "../dataset/GraphMini/enron" > house_enron_test.log 2>&1
if [ $? -eq 0 ]; then
    result=$(grep "RESULT=" house_enron_test.log | grep -o '[0-9]*')
    time=$(grep "CODE_EXECUTION_TIME" house_enron_test.log | grep -o '[0-9]*\.[0-9]*')
    echo "  ✅ House on enron works: Result=$result, Time=${time}s"
else
    echo "  ❌ House pattern hangs on all datasets with 4 threads"
fi

echo ""
echo "=== ANALYSIS ==="
echo "Based on the test results:"
echo ""

# Analyze the results
if [ -f "single_thread_test.log" ] && grep -q "RESULT=" single_thread_test.log; then
    echo "✅ Single thread works → Threading issue confirmed"
    echo "🔍 Likely causes:"
    echo "   1. Deadlock in mutex usage"
    echo "   2. Race condition causing infinite loop"
    echo "   3. OpenMP scheduling issue with complex patterns"
    echo ""
    echo "🛠️  Potential fixes:"
    echo "   1. Check for recursive mutex calls"
    echo "   2. Add timeout to mutex locks"
    echo "   3. Use different OpenMP scheduling (dynamic vs static)"
    echo "   4. Consider lock-free data structures"
else
    echo "❌ Even single thread has issues → Algorithmic problem"
    echo "🔍 Likely causes:"
    echo "   1. Infinite loop in pattern matching algorithm"
    echo "   2. Exponential complexity explosion with house pattern"
    echo "   3. Memory allocation causing virtual memory thrashing"
fi

echo ""
echo "=== Immediate Actions ==="
echo "1. If single thread works:"
echo "   → Focus on threading/mutex issues"
echo "   → Try different OpenMP settings"
echo ""
echo "2. If single thread also hangs:"
echo "   → Review algorithm for infinite loops"
echo "   → Check house pattern complexity"
echo ""
echo "3. Quick test commands:"
echo "   export OMP_PROC_BIND=false"
echo "   export OMP_SCHEDULE=dynamic"
echo "   ./bin/runner 1 \"../dataset/GraphMini/wiki\""