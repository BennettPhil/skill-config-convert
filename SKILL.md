---
name: config-convert
description: Converts between config formats - JSON, YAML, TOML, and INI
version: 0.1.0
license: Apache-2.0
---

# config-convert

Converts configuration files between JSON, YAML, TOML, and INI formats. Pipe in one format, get another out.

## Purpose

Projects often need config in different formats — Docker Compose wants YAML, package.json is JSON, Cargo.toml is TOML, and legacy tools want INI. This tool converts between them without manual rewriting.

## Instructions

When a user needs to convert a config file:

1. Run `./scripts/run.sh --from <format> --to <format> <file>`
2. If `--from` is omitted, the format is detected from the file extension
3. Output goes to stdout; redirect to save
4. Use `--pretty` for formatted output

## Inputs

- `<file>`: Input config file (or `-` for stdin)
- `--from <fmt>`: Input format: json, yaml, toml, ini (auto-detected if omitted)
- `--to <fmt>`: Output format: json, yaml, toml, ini (required)
- `--pretty`: Pretty-print output
- `--help`: Show usage

## Outputs

Converted config to stdout in the target format.

## Constraints

- Requires Python 3 with PyYAML (`pip install pyyaml`) for YAML support
- TOML requires Python 3.11+ (uses `tomllib`) or `pip install tomli`
- INI conversion is lossy for deeply nested structures (flattens to sections)
