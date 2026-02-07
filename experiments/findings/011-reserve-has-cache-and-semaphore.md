# Reserve Has-Cache and Pullsync Semaphore

**Branch:** `fix/2tb-all-fixes`
**Date:** 2026-02-07
**Related commits:**
- `e09ddc51` - perf: add semaphore for ReserveHas and increase recalc to 1min

## Problem

During high-capacity node operation (doubling 5-6), two LevelDB contention issues were observed:

### Issue 1: ReserveHas LevelDB Contention

When pullsync processes offers from peers, it calls `ReserveHas()` for each chunk to check if already stored. With hundreds of concurrent pullsync goroutines:

- Each `ReserveHas()` call does a LevelDB lookup
- LevelDB cache uses an LRU with a mutex (`lru.Promote`)
- Hundreds of concurrent lookups cause massive lock contention
- Result: 1000%+ CPU usage from mutex spinning

**Evidence from profiling:**
```
leveldb/cache/lru.Promote holding mutex
hundreds of goroutines contending
```

### Issue 2: Has() During Put() Contention

Within `Reserve.Put()`, every chunk insertion calls `Has()` first to check for duplicates. Combined with pullsync's `ReserveHas()` calls, this compounds the LevelDB contention.

## Solution

### 1. In-Memory Has-Cache (`reserve.go`)

Added an in-memory cache for Has() lookups:

```go
type Reserve struct {
    // ... existing fields ...

    // In-memory cache for Has() lookups to avoid LevelDB contention
    hasCache    map[string]struct{}
    hasCacheMtx sync.RWMutex
    hasCacheOn  bool
}
```

**Key implementation details:**

- **Startup:** Cache is built by iterating all chunks in reserve (takes ~30s for 100M chunks)
- **Has():** Returns immediately from cache with RLock (concurrent reads)
- **Put():** Updates cache with Lock after successful insertion
- **Eviction:** Cache entries removed when chunks are evicted
- **Key format:** `addr.ByteString() + string(batchID) + string(stampHash)`

**Cache maintenance in Put():**
```go
// Track old cache entry for removal on collision
if r.hasCacheOn {
    oldCacheKey = hasCacheKey(oldStampIndex.ChunkAddress, oldStampIndex.BatchID, oldStampIndex.StampHash)
}

// ... put logic ...

// Update cache: remove old entry if collision, add new entry
if r.hasCacheOn {
    r.hasCacheMtx.Lock()
    if oldCacheKey != "" {
        delete(r.hasCache, oldCacheKey)
    }
    r.hasCache[hasCacheKey(chunk.Address(), chunk.Stamp().BatchID(), stampHash)] = struct{}{}
    r.hasCacheMtx.Unlock()
}
```

### 2. Pullsync Semaphore (`pullsync.go`)

Added a semaphore to limit concurrent ReserveHas calls:

```go
const (
    // maxConcurrentHasChecks limits concurrent ReserveHas calls across all sync sessions.
    // Without this, hundreds of concurrent pullsync goroutines can saturate the LevelDB
    // cache mutex (lru.Promote) causing 1000%+ CPU from lock contention.
    // 128 allows high parallelism while preventing runaway contention.
    maxConcurrentHasChecks = 128
)

type Syncer struct {
    // ... existing fields ...
    hasSem  chan struct{} // semaphore limiting concurrent ReserveHas calls
}
```

**Usage in Sync():**
```go
// Acquire semaphore to limit concurrent LevelDB lookups.
select {
case s.hasSem <- struct{}{}:
case <-ctx.Done():
    return 0, 0, ctx.Err()
}
have, err = s.store.ReserveHas(a, batchID, stampHash)
<-s.hasSem
```

## Files Changed

| File | Change |
|------|--------|
| `pkg/storer/internal/reserve/reserve.go` | Add hasCache, hasCacheMtx, hasCacheOn fields; modify New(), Has(), Put(), EvictBatchBin() |
| `pkg/storer/storer.go` | Add ReserveHasCache option |
| `pkg/pullsync/pullsync.go` | Add hasSem semaphore, wrap ReserveHas calls |
| `cmd/bee/cmd/start.go` | Add `--reserve-has-cache` CLI flag |

## Configuration

Enable cache via CLI:
```bash
bee start --reserve-has-cache
```

Or in config.yaml:
```yaml
reserve-has-cache: true
```

## Trade-offs

### Pros
- Eliminates LevelDB contention for Has() lookups
- CPU usage drops from 1000%+ to normal levels
- Sync throughput increases significantly
- Semaphore provides fallback protection even without cache

### Cons
- Memory overhead: ~100 bytes per chunk (for 100M chunks = ~10GB)
- Startup time: ~30s to build cache
- Cache must be kept in sync with LevelDB (handled in Put/Evict)

## Results

**Before (without cache/semaphore):**
- CPU: 1000%+ during sync
- Offer rate: throttled by contention
- Sync time: significantly delayed

**After (with cache + semaphore):**
- CPU: normal levels
- Offer rate: full throughput
- Sync completes in expected time

## Lessons Learned

1. **LevelDB LRU cache is a hidden bottleneck** - The internal cache mutex becomes a bottleneck under high concurrent read load

2. **Map lookups beat LevelDB for simple Has()** - For existence checks, an in-memory map with RWMutex is orders of magnitude faster than LevelDB

3. **Semaphores as safety net** - Even with the cache, the semaphore provides protection if cache misses occur or for nodes without enough memory

4. **Memory vs CPU trade-off** - For high-capacity nodes, trading ~10GB RAM for eliminating CPU contention is worthwhile

## Related Findings

- `010-recalc-cpu-spike-leveldb-contention.md` - Initial discovery of LevelDB contention
- `008-lottery-sample-performance.md` - Sampler also affected by LevelDB contention
