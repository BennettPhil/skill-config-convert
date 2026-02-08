# config-convert

Convert between JSON, YAML, TOML, and INI configuration file formats.

## Quick Start

```bash
echo '{"database": {"host": "localhost", "port": 5432}}' | ./scripts/run.sh --from json --to yaml
```

## Prerequisites

- Bash 4+
- Python 3 (standard library only)

## Usage

```bash
# JSON to YAML
./scripts/run.sh --from json --to yaml config.json

# YAML to TOML
./scripts/run.sh --from yaml --to toml config.yaml

# JSON to INI
echo '{"server": {"host": "localhost"}}' | ./scripts/run.sh --from json --to ini

# Auto-detect from file extension
./scripts/run.sh --to yaml config.json
```
