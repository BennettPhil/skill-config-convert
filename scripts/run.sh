#!/usr/bin/env bash
set -euo pipefail

# config-convert: convert between config formats

FROM_FMT=""
TO_FMT=""
PRETTY=false
INPUT_FILE=""

usage() {
  cat <<'EOF'
Usage: config-convert [OPTIONS] <file>

Convert between config formats: JSON, YAML, TOML, INI.

Options:
  --from <fmt>   Input format (json, yaml, toml, ini). Auto-detected if omitted.
  --to <fmt>     Output format (json, yaml, toml, ini). Required.
  --pretty       Pretty-print output
  --help         Show this help message

Examples:
  config-convert --to yaml config.json
  config-convert --from json --to toml config.json
  cat config.json | config-convert --from json --to yaml -
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)   FROM_FMT="$2"; shift 2 ;;
    --to)     TO_FMT="$2"; shift 2 ;;
    --pretty) PRETTY=true; shift ;;
    --help)   usage; exit 0 ;;
    -*)       echo "Error: unknown option '$1'" >&2; exit 1 ;;
    *)        INPUT_FILE="$1"; shift ;;
  esac
done

if [ -z "$TO_FMT" ]; then
  echo "Error: --to format is required" >&2
  usage >&2
  exit 1
fi

if [ -z "$INPUT_FILE" ]; then
  echo "Error: no input file specified" >&2
  usage >&2
  exit 1
fi

# Auto-detect format from extension
if [ -z "$FROM_FMT" ] && [ "$INPUT_FILE" != "-" ]; then
  ext="${INPUT_FILE##*.}"
  case "$ext" in
    json)        FROM_FMT="json" ;;
    yaml|yml)    FROM_FMT="yaml" ;;
    toml)        FROM_FMT="toml" ;;
    ini|cfg|conf) FROM_FMT="ini" ;;
    *)           echo "Error: cannot detect format from extension '.$ext'. Use --from." >&2; exit 1 ;;
  esac
fi

if [ -z "$FROM_FMT" ]; then
  echo "Error: --from format is required when reading from stdin" >&2
  exit 1
fi

if [ "$INPUT_FILE" != "-" ] && [ ! -f "$INPUT_FILE" ]; then
  echo "Error: file '$INPUT_FILE' does not exist" >&2
  exit 1
fi

# Read input
if [ "$INPUT_FILE" = "-" ]; then
  INPUT_DATA=$(cat)
else
  INPUT_DATA=$(cat "$INPUT_FILE")
fi

# Write to temp file for Python
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
printf '%s' "$INPUT_DATA" > "$TMPFILE"

python3 - "$TMPFILE" "$FROM_FMT" "$TO_FMT" "$PRETTY" << 'PYEOF'
import sys
import json
import configparser
import io

input_file = sys.argv[1]
from_fmt = sys.argv[2]
to_fmt = sys.argv[3]
pretty = sys.argv[4] == "true"

with open(input_file) as f:
    raw = f.read()

# Parse input
data = None

if from_fmt == "json":
    data = json.loads(raw)

elif from_fmt == "yaml":
    try:
        import yaml
    except ImportError:
        print("Error: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
        sys.exit(1)
    data = yaml.safe_load(raw)

elif from_fmt == "toml":
    try:
        import tomllib
    except ImportError:
        try:
            import tomli as tomllib
        except ImportError:
            print("Error: TOML support requires Python 3.11+ or: pip install tomli", file=sys.stderr)
            sys.exit(1)
    data = tomllib.loads(raw)

elif from_fmt == "ini":
    config = configparser.ConfigParser()
    config.read_string(raw)
    data = {}
    for section in config.sections():
        data[section] = dict(config[section])
    if config.defaults():
        data["DEFAULT"] = dict(config.defaults())

else:
    print(f"Error: unsupported input format '{from_fmt}'", file=sys.stderr)
    sys.exit(1)

# Write output
if to_fmt == "json":
    indent = 2 if pretty else None
    print(json.dumps(data, indent=indent))

elif to_fmt == "yaml":
    try:
        import yaml
    except ImportError:
        print("Error: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
        sys.exit(1)
    print(yaml.dump(data, default_flow_style=not pretty, sort_keys=False), end="")

elif to_fmt == "toml":
    # Simple TOML writer
    def write_toml(data, prefix=""):
        lines = []
        tables = []
        for key, value in data.items():
            if isinstance(value, dict):
                tables.append((key, value))
            elif isinstance(value, list):
                for item in value:
                    if isinstance(item, dict):
                        full_key = f"{prefix}{key}" if prefix else key
                        lines.append(f"\n[[{full_key}]]")
                        lines.extend(write_toml(item, ""))
                    else:
                        lines.append(f"{key} = {toml_value(value)}")
                        break
            else:
                lines.append(f"{key} = {toml_value(value)}")
        for key, value in tables:
            full_key = f"{prefix}{key}" if prefix else key
            lines.append(f"\n[{full_key}]")
            lines.extend(write_toml(value, f"{full_key}."))
        return lines

    def toml_value(v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return str(v)
        if isinstance(v, str):
            return f'"{v}"'
        if isinstance(v, list):
            items = ", ".join(toml_value(i) for i in v)
            return f"[{items}]"
        return f'"{v}"'

    lines = write_toml(data)
    print("\n".join(lines).strip())

elif to_fmt == "ini":
    config = configparser.ConfigParser()
    for key, value in data.items():
        if isinstance(value, dict):
            config[key] = {k: str(v) for k, v in value.items()}
        else:
            if "DEFAULT" not in config:
                config["main"] = {}
            config["main"][key] = str(value)
    output = io.StringIO()
    config.write(output)
    print(output.getvalue(), end="")

else:
    print(f"Error: unsupported output format '{to_fmt}'", file=sys.stderr)
    sys.exit(1)

PYEOF
