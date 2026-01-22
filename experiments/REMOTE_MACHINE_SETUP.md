# Remote Test Machine Setup

This document describes the requirements and setup for a machine that will run Bee performance experiments.

---

## Hardware Requirements

### Minimum (for basic experiments)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16+ GB |
| Disk | 100 GB SSD | 250+ GB NVMe SSD |
| Network | 100 Mbps | 1 Gbps |

### For Scaled Storage Experiments (`--reserve-capacity-doubling 1`)

| Resource | Minimum |
|----------|---------|
| Disk | 200 GB free (for ~34 GB reserve + overhead + logs) |
| RAM | 16 GB (for increased LevelDB cache) |

---

## Software Requirements

### Operating System

- Linux (Ubuntu 22.04+ recommended) or macOS
- Root/sudo access for some operations

### Required Software

#### 1. Go (version 1.24.0+)

```bash
# Check version
go version

# Install on Ubuntu
wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
```

#### 2. Git

```bash
# Install on Ubuntu
sudo apt update && sudo apt install -y git

# Configure
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

#### 3. Build Tools

```bash
# Ubuntu
sudo apt install -y build-essential make

# macOS (Xcode command line tools)
xcode-select --install
```

#### 4. SSH Key for GitHub Access

```bash
# Generate key if needed
ssh-keygen -t ed25519 -C "your@email.com"

# Add to GitHub: https://github.com/settings/keys
cat ~/.ssh/id_ed25519.pub
```

---

## Monitoring Tools

### Required

#### 1. curl (for API/metrics access)

```bash
sudo apt install -y curl
```

#### 2. jq (for JSON parsing)

```bash
sudo apt install -y jq
```

### Recommended

#### 3. System Monitoring

```bash
# iostat, mpstat for disk/CPU metrics
sudo apt install -y sysstat

# htop for interactive monitoring
sudo apt install -y htop

# iotop for disk I/O by process
sudo apt install -y iotop
```

#### 4. Prometheus (optional, for metrics collection)

```bash
# Download Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar xvfz prometheus-2.48.0.linux-amd64.tar.gz
cd prometheus-2.48.0.linux-amd64

# prometheus.yml config for Bee
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'bee'
    static_configs:
      - targets: ['localhost:1633']
    metrics_path: /metrics
EOF

# Run
./prometheus --config.file=prometheus.yml
```

---

## Repository Setup

### Clone the Fork

```bash
# Clone crtahlin/bee fork
git clone git@github.com:crtahlin/bee.git
cd bee

# Verify remote
git remote -v
# Should show: origin  git@github.com:crtahlin/bee.git
```

### Build Bee

```bash
# Build binary
make binary

# Verify
./dist/bee version
```

---

## Bee Node Configuration

### Data Directory

```bash
# Create data directory
mkdir -p ~/.bee

# Ensure sufficient space
df -h ~/.bee
```

### Blockchain RPC Endpoint

Bee requires an Ethereum RPC endpoint (Gnosis Chain for mainnet). Options:

1. **Public endpoint** (rate limited):
   ```
   --blockchain-rpc-endpoint https://rpc.gnosischain.com
   ```

2. **Run your own Gnosis node** (recommended for experiments)

3. **Use a provider** (Infura, Alchemy with Gnosis support)

### Basic Configuration File

Create `~/.bee.yaml`:

```yaml
# Basic configuration for experiments
api-addr: "127.0.0.1:1633"
p2p-addr: ":1634"
data-dir: "/home/user/.bee"
password: "your-secure-password"
verbosity: "info"
blockchain-rpc-endpoint: "https://rpc.gnosischain.com"
full-node: true
swap-enable: false
mainnet: true

# Storage settings (adjust per experiment)
# reserve-capacity-doubling: 0
# db-block-cache-capacity: 33554432
# db-write-buffer-size: 33554432
# db-open-files-limit: 256
```

---

## Network Requirements

### Firewall Rules

```bash
# Allow P2P port
sudo ufw allow 1634/tcp
sudo ufw allow 1634/udp

# API port (localhost only for security)
# No external rule needed if binding to 127.0.0.1
```

### Port Forwarding (if behind NAT)

- Forward port 1634 TCP/UDP to the test machine
- Or use `--nat-addr` to specify public IP

---

## Pre-Experiment Checklist

Before running any experiment, verify:

```bash
# 1. Go version
go version  # Should be 1.24.0+

# 2. Disk space
df -h ~/.bee  # Should have sufficient free space

# 3. Repository is up to date
cd ~/bee
git fetch origin
git status

# 4. Can build successfully
make binary
./dist/bee version

# 5. Can connect to RPC
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://rpc.gnosischain.com

# 6. Ports are available
sudo lsof -i :1633  # Should be empty
sudo lsof -i :1634  # Should be empty
```

---

## Metrics Collection Scripts

### Collect Bee Metrics

```bash
#!/bin/bash
# save as: collect_metrics.sh

INTERVAL=${1:-60}  # Default 60 seconds
OUTPUT=${2:-metrics.log}

while true; do
    echo "=== $(date -Iseconds) ===" >> $OUTPUT
    curl -s http://localhost:1633/metrics | grep -E "^bee_" >> $OUTPUT
    echo "" >> $OUTPUT
    sleep $INTERVAL
done
```

### Collect System Metrics

```bash
#!/bin/bash
# save as: collect_system.sh

INTERVAL=${1:-60}
OUTPUT=${2:-system.log}

while true; do
    echo "=== $(date -Iseconds) ===" >> $OUTPUT
    echo "--- CPU/Memory ---" >> $OUTPUT
    top -b -n 1 | head -15 >> $OUTPUT
    echo "--- Disk I/O ---" >> $OUTPUT
    iostat -x 1 1 >> $OUTPUT
    echo "" >> $OUTPUT
    sleep $INTERVAL
done
```

### Parse Key Metrics

```bash
#!/bin/bash
# save as: parse_metrics.sh

# Usage: ./parse_metrics.sh < metrics.log

grep -E "bee_reserve_size|bee_pullsync_|bee_storer_" | \
  awk '{print $1, $2}'
```

---

## Resetting Between Experiments

### Full Reset (clear all data)

```bash
# Stop bee first!
rm -rf ~/.bee/localstore
rm -rf ~/.bee/statestore
rm -rf ~/.bee/keys  # Only if you want new identity
```

### Partial Reset (keep identity, clear storage)

```bash
rm -rf ~/.bee/localstore
```

---

## Troubleshooting

### Build Failures

```bash
# Clear Go cache
go clean -cache

# Update dependencies
go mod tidy
go mod download
```

### Bee Won't Start

```bash
# Check logs
journalctl -u bee -f  # If running as service

# Check port conflicts
sudo lsof -i :1633
sudo lsof -i :1634

# Check disk space
df -h
```

### Slow Sync

```bash
# Check peer count
curl -s http://localhost:1633/peers | jq '.peers | length'

# Check topology
curl -s http://localhost:1633/topology | jq '.depth, .population'
```

---

## Contact

For issues with experiment setup, check:
- GitHub Issues: https://github.com/crtahlin/bee/issues
- Experiment files: `experiments/` folder in repository
