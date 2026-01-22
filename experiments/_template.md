# Experiment: [Short Name]

**Status**: Draft | Ready | Running | Complete | Abandoned
**Issue**: #[number]
**Branch**: `experiment/[name]`
**Date Created**: YYYY-MM-DD

---

## Hypothesis

[Clear, falsifiable statement of what you expect to happen]

Example: "Increasing `handleMaxChunksPerSecond` from 250 to 500 will reduce sync time by approximately 40% for a node with `--reserve-capacity-doubling 1`."

---

## Background

[Why this experiment? Link to analysis or prior findings]

See: [analysis/storage-scaling-bottlenecks.md](../analysis/storage-scaling-bottlenecks.md)

---

## Baseline Configuration

```yaml
# bee.yaml or CLI flags for baseline test
reserve-capacity-doubling: 1
# ... other relevant settings
```

### Baseline Metrics to Capture

- [ ] Time to sync reserve to 50% capacity
- [ ] Average chunks/second during sync
- [ ] CPU utilization during sync
- [ ] Memory usage
- [ ] Disk I/O (read/write MB/s)

---

## Experimental Change

### Files Modified

| File | Change Description |
|------|-------------------|
| `path/to/file.go` | [What changed] |

### Code Diff Summary

```go
// Before
handleMaxChunksPerSecond = 250

// After
handleMaxChunksPerSecond = 500
```

### Configuration Changes (if any)

```yaml
# New/modified settings
```

---

## Test Procedure

### Prerequisites

- [ ] Test machine has sufficient disk space (>50 GB free)
- [ ] Bee binary built from experiment branch
- [ ] Network connectivity to Swarm mainnet/testnet
- [ ] Monitoring tools configured

### Remote Execution Instructions

#### 1. Setup

```bash
# Clone and checkout experiment branch
git clone git@github.com:crtahlin/bee.git
cd bee
git checkout experiment/[name]

# Build binary
make binary

# Verify build
./dist/bee version
```

#### 2. Baseline Test (if not already done)

```bash
# Run with baseline configuration
./dist/bee start \
  --config baseline.yaml \
  --verbosity debug

# Let sync run for [duration]
# Collect metrics every [interval]
```

#### 3. Experiment Test

```bash
# Run with experimental binary/configuration
./dist/bee start \
  --config experiment.yaml \
  --verbosity debug

# Let sync run for [duration]
# Collect metrics every [interval]
```

#### 4. Data Collection

Collect from Bee metrics endpoint (`http://localhost:1633/metrics`):

```bash
# Key metrics to capture
curl -s http://localhost:1633/metrics | grep -E "bee_pullsync|bee_reserve"
```

Collect system metrics:

```bash
# CPU/Memory
top -b -n 1 | head -20

# Disk I/O
iostat -x 1 5
```

#### 5. Cleanup

```bash
# Stop bee
# Clear data directory if needed for fresh test
rm -rf ~/.bee/localstore
```

---

## Success Criteria

| Metric | Baseline | Target | Acceptable Range |
|--------|----------|--------|------------------|
| Sync time (to 50% capacity) | X min | Y min | ±10% |
| Chunks/second | X | Y | ±15% |
| CPU usage | X% | ≤X% | No significant increase |

**Success**: [Define what constitutes success]
**Failure**: [Define what constitutes failure]

---

## Results

### Baseline Results

| Metric | Value | Notes |
|--------|-------|-------|
| Sync time | | |
| Chunks/second | | |
| CPU usage | | |

### Experiment Results

| Metric | Value | Notes |
|--------|-------|-------|
| Sync time | | |
| Chunks/second | | |
| CPU usage | | |

### Comparison

| Metric | Baseline | Experiment | Change |
|--------|----------|------------|--------|
| Sync time | | | % |
| Chunks/second | | | % |

---

## Analysis

[Interpret the results. Was the hypothesis confirmed or rejected?]

---

## Conclusions

- [ ] Hypothesis confirmed / rejected / inconclusive
- [ ] Recommended action: merge / iterate / abandon

---

## Follow-up

- [ ] Update related issue #[number]
- [ ] Update analysis document if findings are significant
- [ ] Design follow-up experiment if needed
