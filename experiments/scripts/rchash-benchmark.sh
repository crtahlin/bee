#!/bin/bash
#
# rchash benchmark script - runs multiple sampling tests with pauses
#
# Usage: ./rchash-benchmark.sh <node> <count> <pause_minutes>
#   node: "local" or "2tb"
#   count: number of tests (default: 20)
#   pause_minutes: pause between tests (default: 10)
#

NODE="${1:-local}"
COUNT="${2:-20}"
PAUSE_MIN="${3:-10}"
PAUSE_SEC=$((PAUSE_MIN * 60))

RESULTS_DIR="/home/crtah/GitHub/crtahlin/bee/experiments/results/rchash-benchmark-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

if [ "$NODE" = "local" ]; then
    OVERLAY="8cf664b88691fcb82c8a5738fcebd4573ae45a79c0b4293e3d6151a1dc76f455"
    DEPTH=9
    API_CMD="curl -s"
    API_BASE="http://localhost:1633"
    LOG_CMD="tail -20 /home/crtah/GitHub/crtahlin/bee/experiments/data/B1_20260122_150919/bee.log | grep 'sampler finished'"
elif [ "$NODE" = "2tb" ]; then
    OVERLAY="7d1a08042e221329d55d76e4f9a426915301997ae33de1f9864418d5ae30f89a"
    DEPTH=9
    API_CMD="ssh beenode2tb wget -qO-"
    API_BASE="http://localhost:1633"
    LOG_CMD="ssh beenode2tb \"grep 'sampler finished' /home/beenode2tb/bee-data/logs/bee-*.log | tail -1\""
else
    echo "Unknown node: $NODE (use 'local' or '2tb')"
    exit 1
fi

RESULTS_FILE="$RESULTS_DIR/${NODE}-results.txt"
SUMMARY_FILE="$RESULTS_DIR/${NODE}-summary.txt"

echo "=== rchash Benchmark ===" | tee "$RESULTS_FILE"
echo "Node: $NODE" | tee -a "$RESULTS_FILE"
echo "Overlay: $OVERLAY" | tee -a "$RESULTS_FILE"
echo "Depth: $DEPTH" | tee -a "$RESULTS_FILE"
echo "Count: $COUNT" | tee -a "$RESULTS_FILE"
echo "Pause: ${PAUSE_MIN}min" | tee -a "$RESULTS_FILE"
echo "Started: $(date)" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

for i in $(seq 1 $COUNT); do
    echo "--- Test $i/$COUNT at $(date) ---" | tee -a "$RESULTS_FILE"

    # Generate unique anchor for each test
    ANCHOR2=$(echo -n "benchmark_test_${i}_$(date +%s)" | sha256sum | cut -d' ' -f1)

    # Run rchash and time it
    START_TIME=$(date +%s.%N)

    if [ "$NODE" = "local" ]; then
        RESPONSE=$(curl -s "$API_BASE/rchash/$DEPTH/$OVERLAY/$ANCHOR2" 2>&1)
    else
        RESPONSE=$(ssh beenode2tb "wget -qO- '$API_BASE/rchash/$DEPTH/$OVERLAY/$ANCHOR2'" 2>&1)
    fi

    END_TIME=$(date +%s.%N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)

    echo "Duration: ${DURATION}s" | tee -a "$RESULTS_FILE"

    # Get sampler stats from log
    sleep 2
    if [ "$NODE" = "local" ]; then
        STATS=$(tail -20 /home/crtah/GitHub/crtahlin/bee/experiments/data/B1_20260122_150919/bee.log | grep 'sampler finished' | tail -1)
    else
        STATS=$(ssh beenode2tb "grep 'sampler finished' /home/beenode2tb/bee-data/logs/bee-*.log 2>/dev/null | tail -1")
    fi
    echo "Stats: $STATS" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"

    # Pause before next test (skip pause after last test)
    if [ $i -lt $COUNT ]; then
        echo "Pausing for ${PAUSE_MIN} minutes..." | tee -a "$RESULTS_FILE"
        sleep $PAUSE_SEC
    fi
done

echo "=== Benchmark Complete ===" | tee -a "$RESULTS_FILE"
echo "Finished: $(date)" | tee -a "$RESULTS_FILE"

# Extract durations for summary
echo "=== Duration Summary ===" > "$SUMMARY_FILE"
grep "Duration:" "$RESULTS_FILE" | awk '{print $2}' | sed 's/s//' >> "$SUMMARY_FILE"

echo ""
echo "Results saved to: $RESULTS_DIR"
