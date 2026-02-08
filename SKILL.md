---
name: config-convert
description: Convert between JSON, YAML, TOML, and INI configuration file formats.
version: 0.1.0
license: Apache-2.0
---

# config-convert

Convert configuration files between JSON, YAML, TOML, and INI formats.

## Purpose

Projects often need config files in different formats — Docker uses YAML, npm uses JSON, Python uses TOML/INI. This skill converts between them so you can transform configs without manual rewriting.

## Quick Start

```bash
./scripts/run.sh --from json --to yaml config.json
```

## Reference Index

- See arguments table below for all options
- Pure Python implementation — uses only the standard library

## Implementation

Single script at `scripts/run.sh` that detects or accepts format flags and converts.

## Arguments

| Flag | Default | Description |
|------|---------|-------------|
| FILE | stdin | Input file path |
| --from | auto | Input format: json, yaml, toml, ini |
| --to | json | Output format: json, yaml, toml, ini |
| --pretty | false | Pretty-print output (for JSON) |
| --help | - | Show usage |
