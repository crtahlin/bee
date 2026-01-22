# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Policy

**IMPORTANT**: This is a fork maintained at `github.com/crtahlin/bee`.
- Only push to and work with `crtahlin` repositories (origin)
- Do NOT add or interact with `ethersphere/bee` (upstream) unless explicitly instructed
- All experimental changes stay in this fork

## Purpose of This Fork

This repository is dedicated to **performance experimentation** with Bee. The goals are:

1. **Identify performance bottlenecks** when scaling storage capacity (via `--reserve-capacity-doubling`)
2. **Design and run experiments** to validate hypotheses about bottlenecks
3. **Implement and test optimizations** to remove bottlenecks
4. **Document findings** with data-driven conclusions

### Key Resources

- **Analysis documents**: `analysis/` folder contains bottleneck analyses
- **Experiment definitions**: `experiments/` folder (create as needed)
- **GitHub Issues**: Track individual bottlenecks and experiments at `github.com/crtahlin/bee/issues`

---

## Experiment Workflow

### 1. Hypothesis Formation

Before any code change, document:
- **What**: The specific bottleneck being addressed
- **Why**: Evidence suggesting this is a bottleneck (from analysis or profiling)
- **Hypothesis**: Expected improvement with specific change
- **Metrics**: How to measure success (sync time, throughput, latency, CPU/memory usage)

### 2. Experiment Design

Create an experiment file in `experiments/` with:

```markdown
# Experiment: [Short Name]

## Hypothesis
[Clear statement of what you expect to happen]

## Baseline
- Configuration: [current settings]
- Expected metrics: [what to measure before]

## Change
- Files modified: [list]
- Nature of change: [description]
- Branch: [experiment branch name]

## Test Procedure
[Step-by-step instructions for the test machine agent]

## Success Criteria
[Quantitative thresholds for success/failure]
```

### 3. Code Changes

- Create a feature branch: `experiment/[short-name]`
- Make minimal, focused changes
- Commit with clear messages referencing the experiment
- Push to `origin` (crtahlin/bee)

### 4. Test Machine Instructions

Write instructions in experiment files that a **remote agent** can follow. Include:

```markdown
## Remote Execution Instructions

### Prerequisites
- [ ] Bee binary built from branch `experiment/[name]`
- [ ] Test environment configured
- [ ] Monitoring tools ready

### Setup
[Commands to set up the test environment]

### Execution
[Exact commands to run the experiment]

### Data Collection
[What metrics to capture and how]

### Cleanup
[How to reset for next experiment]

### Results Reporting
[Format for reporting results back]
```

### 5. Results Analysis

After experiment completion:
- Document actual results vs. hypothesis
- Update analysis documents with findings
- Close or update related GitHub issues
- Decide: merge improvement, iterate, or abandon

---

## Branching Strategy for Experiments

```
master                    # Stable baseline (synced with upstream releases)
├── experiment/pullsync-rate    # Individual experiment branches
├── experiment/leveldb-cache
├── experiment/reduce-locks
└── perf/combined-optimizations # Validated improvements combined
```

### Branch Naming
- `experiment/[bottleneck-name]` - Single hypothesis tests
- `perf/[description]` - Validated performance improvements
- `analysis/[topic]` - Analysis-only changes (documentation)

### Commit Rules
- **NEVER mention Claude, AI, or automated generation in commit messages**
- Write commit messages as if written by a human developer
- Follow conventional commits format (feat:, fix:, docs:, perf:, refactor:)
- No "Co-Authored-By" or "Generated with" footers

---

## Communication with Test Machine Agent

When writing instructions for the remote test machine, assume the agent:
- Has access to the `crtahlin/bee` repository
- Can build Go binaries
- Can run Bee nodes (possibly in a cluster)
- Can collect metrics (CPU, memory, disk I/O, network)
- Can access Bee's metrics endpoint (`/metrics`)
- Needs explicit, unambiguous instructions

### Instruction Template for Remote Agent

```markdown
## Task: [Experiment Name]

### Objective
[One sentence describing what to test]

### Branch to Use
`experiment/[name]`

### Build Instructions
```bash
git fetch origin
git checkout experiment/[name]
make binary
```

### Configuration
[bee.yaml or CLI flags to use]

### Test Steps
1. [Step 1]
2. [Step 2]
...

### Metrics to Collect
- [ ] Metric 1: [how to get it]
- [ ] Metric 2: [how to get it]

### Expected Duration
[How long the test should run]

### Report Back
Please provide:
1. [Specific data point]
2. [Specific data point]
3. Any errors or unexpected behavior
```

---

## Project Overview

Swarm Bee is a Go-based implementation of the Swarm distributed storage network, a decentralized peer-to-peer storage and communication system. The project follows strict Go coding standards and emphasizes modularity, testing, and performance.

## Development Commands

### Building and Testing
```bash
# Build the project
make build

# Build the binary (creates dist/bee)
make binary

# Run all tests with race detection
make test-race

# Run tests with coverage
make test cover=true

# Run integration tests
make test-integration

# Run CI tests (excluding flaky tests)
make test-ci

# Run only flaky tests
make test-ci-flaky
```

### Linting and Code Quality
```bash
# Run linter
make lint

# Format code using gofumpt and gci
make format

# Install formatters
make install-formatters

# Check for trailing whitespace
make check-whitespace
```

### Local Development and Testing
```bash
# Install beekeeper testing framework
make beekeeper

# Setup local testing environment
make beelocal

# Deploy local test cluster
make deploylocal

# Run comprehensive local tests
make testlocal

# Complete local test setup and execution
make testlocal-all
```

### Protocol Buffers
```bash
# Install protobuf tools
make protobuftools

# Generate protobuf files
make protobuf
```

### Docker
```bash
# Build Docker image
make docker-build PLATFORM=linux/amd64 BEE_IMAGE=ethersphere/bee:latest
```

## Architecture Overview

### Core Package Structure
- `pkg/api/` - HTTP API endpoints and handlers (~87 files)
- `pkg/p2p/` - Peer-to-peer networking layer
- `pkg/storage/` - Storage layer abstractions
- `pkg/crypto/` - Cryptographic utilities
- `pkg/feeds/` - Content addressing and feeds
- `pkg/postage/` - Postage stamp system
- `pkg/accounting/` - Payment and accounting
- `pkg/file/` - File handling and operations
- `pkg/bmt/` - Binary Merkle Tree implementation
- `cmd/bee/` - CLI application entry point

### Key Components
- **Swarm Node**: Main node implementation with P2P networking
- **API Server**: RESTful API for client interactions (OpenAPI spec available)
- **Storage Engine**: Distributed storage with chunking and redundancy
- **Postage System**: Incentive layer for storage payments
- **P2P Networking**: LibP2P-based peer discovery and communication
- **Content Addressing**: Merkle tree-based content identification

### Configuration
- Uses Go modules with `go 1.24.0` requirement
- Configuration via CLI flags, environment variables, and config files
- Supports both full and light node modes

## Development Guidelines

### Code Standards
- Follow [Effective Go](https://golang.org/doc/effective_go.html) and [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- Use separate test packages when possible (e.g., `package_test`)
- Every package should have clear godoc documentation
- Treat each package as a standalone library

### Error Handling
- Always propagate errors up the call stack
- Use `fmt.Errorf` with `%w` verb for error wrapping
- Don't log and return errors simultaneously
- Package-specific errors should be prefixed with package name

### Logging
- Use structured logging with key-value pairs
- Log levels: Error, Warning, Info, Debug (with V-levels)
- Error/Warning for operators, Debug for developers
- Never log sensitive information (keys, tokens, passwords)
- Use `/loggers` API endpoint for runtime log level changes

### Concurrency
- Define goroutine termination strategy before creation
- Every channel must have an owning goroutine
- Use readonly/writeonly channels where possible

### Testing
- Tests must pass with `make test-race`
- Integration tests use `-tags=integration`
- Flaky tests should be marked with "FLAKY" suffix

### Commit Messages
- Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- Use imperative mood, max 72 characters
- Include meaningful context in commit body

## Important Notes

- The project uses semantic versioning for API but NOT for the main application
- Breaking changes expected with minor version bumps
- Two versioning schemes: main Bee version and API version (in openapi/Swarm.yaml)
- Always run `make lint` before submitting changes
- Docker images available at `ethersphere/bee`