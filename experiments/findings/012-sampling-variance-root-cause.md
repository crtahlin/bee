# Sampling Variance Root Cause Analysis

**Date:** 2026-02-08
**Branch:** `fix/2tb-all-fixes`

## Summary

The variance in sampling duration (2m to 43m ChunkLoadDuration) is caused by **pushsync writes not being paused during sampling**.

## Evidence

### Original Benchmark (20 tests)

| Time Window | ChunkLoad Range | Pattern |
|-------------|-----------------|---------|
| 21:42 - 23:00 (evening) | 10-29m | SLOW |
| 23:15 | 2m42s | FAST |
| 23:30 - 00:30 | 5-7m | MEDIUM |
| 01:00 - 02:30 | 16-43m | SLOW |
| 03:00 - 04:00 (night) | 3m | FAST |

### Investigation Tests (5 tests)

| Time Window | ChunkLoad Range | Pattern |
|-------------|-----------------|---------|
| 08:36 - 09:22 (morning) | 2m02s - 2m12s | ALL FAST |

### Correlation Analysis

- Evening hours: High network activity → many incoming pushsync writes → slow sampling
- Night/morning hours: Low network activity → few pushsync writes → fast sampling
- Disk utilization alone doesn't explain variance (Test 3 had 92% disk util but still fast)

## Root Cause

The `pause-sync-during-sampling` feature only pauses **pullsync** operations:

```go
// In pullsync/pullsync.go - PAUSED
if s.store.IsSamplingActive() {
    continue  // Skip ReserveHas
}
```

But **pushsync** is NOT paused:

```go
// In pushsync/pushsync.go - NOT PAUSED
err = ps.store.ReservePutter().Put(ctx, chunkToPut)
// This runs during sampling, causing I/O contention
```

When other nodes push chunks to this node:
1. Pushsync receives the chunk
2. Calls `ReservePutter().Put()` to store it
3. This competes with sampler's `ChunkStore.Get()` calls
4. Results in I/O contention and slow ChunkLoadDuration

## Proposed Fix

Extend pause-sync to include pushsync:

### Option 1: Skip and NAK (Preferred)

```go
// In pushsync/pushsync.go
if ps.store.IsSamplingActive() {
    // Return error so sender will retry later
    return fmt.Errorf("node is sampling, try again later")
}
err = ps.store.ReservePutter().Put(ctx, chunkToPut)
```

**Pros:** Clean, chunks get retried automatically
**Cons:** Slight delay in chunk propagation during sampling

### Option 2: Queue and defer

Queue incoming chunks during sampling, write after sampling completes.

**Pros:** No chunks lost
**Cons:** Memory usage, complexity

## Verification

After implementing the fix:
1. Run benchmark during high-traffic hours (21:00-02:00)
2. ChunkLoadDuration should be consistent (~2-3m)
3. No variance based on time of day

## Impact

With the fix, sampling should complete in 2-3 minutes consistently, regardless of network activity. This is critical for lottery participation during busy periods.
