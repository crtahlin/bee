# Experiments

This folder contains performance experiment definitions for the Bee storage scaling project.

## Structure

Each experiment should have its own markdown file:

```
experiments/
├── README.md                           # This file
├── 001-pullsync-rate-increase.md       # First experiment
├── 002-leveldb-cache-scaling.md        # Second experiment
└── ...
```

## Experiment File Template

Copy `_template.md` to create a new experiment.

## Experiment Lifecycle

1. **Draft**: Experiment designed, not yet implemented
2. **Ready**: Code changes made, branch pushed, awaiting execution
3. **Running**: Currently being executed on test machine
4. **Complete**: Results collected, analysis done
5. **Abandoned**: Experiment cancelled (document why)

## Naming Convention

`NNN-short-description.md` where NNN is a sequential number.

## Related Resources

- Analysis: `../analysis/storage-scaling-bottlenecks.md`
- Issues: https://github.com/crtahlin/bee/issues
