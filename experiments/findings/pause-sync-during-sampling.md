# Pause Sync During Sampling

**Issue:** https://github.com/crtahlin/bee/issues/20
**Branch:** `fix/2tb-all-fixes`
**Date:** 2026-02-07

## Problem

The reserve sampler (rchash) takes 7-13 minutes due to LevelDB contention:
- Sampler calls `ChunkStore.Get()` millions of times
- Concurrent pullsync calls `ReserveHas()` thousands of times/sec
- Both compete for LevelDB locks and cache

## Solution

Add `samplingActive` atomic flag to pause pullsync during sampling:

1. `ReserveSample()` sets flag to `true` at start
2. Pullsync checks flag before `ReserveHas()` and `Put()` calls
3. If flag is set, skip operations (continue/return early)
4. When sampling completes, flag is cleared via `defer`
5. Skipped chunks will be retried on next sync cycle

## Files Changed

| File | Change |
|------|--------|
| `pkg/storer/storer.go` | Add `samplingActive atomic.Bool` field, extend `Reserve` interface |
| `pkg/storer/reserve.go` | Add `IsSamplingActive()` method |
| `pkg/storer/sample.go` | Set/clear flag around sampling |
| `pkg/pullsync/pullsync.go` | Check flag before Has/Put operations |
| `pkg/storer/mock/mockreserve.go` | Add mock method |

## Expected Results

- Sampler duration: 7-13 min -> <5 min
- Sync pauses during sampling (~5-10 min per round)
- Sync rate recovers after sampling completes

## Verification Steps

1. Start node with new binary
2. Wait for sync to be active
3. Trigger sampler or wait for redistribution round
4. Check logs for sampler duration
5. Verify sync resumes after sampling
