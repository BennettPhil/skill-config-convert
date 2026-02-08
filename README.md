# config-convert

Converts between config formats: JSON, YAML, TOML, INI.

## Quick Start

```bash
./scripts/run.sh --to yaml config.json
./scripts/run.sh --from json --to toml config.json
```

## Prerequisites

- Python 3
- PyYAML (`pip install pyyaml`) for YAML support
- Python 3.11+ or `pip install tomli` for TOML input
