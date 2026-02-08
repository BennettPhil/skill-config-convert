#!/usr/bin/env bash
set -euo pipefail

# run.sh — Convert between config file formats
# Usage: ./run.sh [OPTIONS] [FILE]

FROM_FMT="auto"
TO_FMT="json"
PRETTY=false
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM_FMT="$2"; shift 2 ;;
    --to) TO_FMT="$2"; shift 2 ;;
    --pretty) PRETTY=true; shift ;;
    --help)
      echo "Usage: run.sh [OPTIONS] [FILE]"
      echo ""
      echo "Convert between config file formats."
      echo ""
      echo "Options:"
      echo "  --from FORMAT   Input format: json, yaml, toml, ini, auto (default: auto)"
      echo "  --to FORMAT     Output format: json, yaml, toml, ini (default: json)"
      echo "  --pretty        Pretty-print output"
      echo "  --help          Show this help"
      echo ""
      echo "Supported: JSON, YAML, TOML, INI"
      exit 0
      ;;
    -*) echo "Error: unknown option: $1" >&2; exit 2 ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"; shift
      else
        echo "Error: unexpected argument: $1" >&2; exit 2
      fi
      ;;
  esac
done

# Read input
if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: file not found: $INPUT_FILE" >&2
    exit 2
  fi
  INPUT=$(cat "$INPUT_FILE")

  # Auto-detect format from extension
  if [[ "$FROM_FMT" == "auto" ]]; then
    case "$INPUT_FILE" in
      *.json) FROM_FMT="json" ;;
      *.yaml|*.yml) FROM_FMT="yaml" ;;
      *.toml) FROM_FMT="toml" ;;
      *.ini|*.cfg|*.conf) FROM_FMT="ini" ;;
      *) echo "Error: cannot auto-detect format. Use --from flag." >&2; exit 2 ;;
    esac
  fi
elif [[ -t 0 ]]; then
  echo "Error: no input provided" >&2
  exit 2
else
  INPUT=$(cat)
  if [[ "$FROM_FMT" == "auto" ]]; then
    # Try to guess from content
    if echo "$INPUT" | head -1 | grep -q '^{'; then
      FROM_FMT="json"
    elif echo "$INPUT" | head -1 | grep -q '^\['; then
      # Could be INI or TOML
      if echo "$INPUT" | grep -q '^\[.*\]$'; then
        FROM_FMT="ini"
      fi
    else
      echo "Error: cannot auto-detect format from stdin. Use --from flag." >&2
      exit 2
    fi
  fi
fi

if [[ -z "$INPUT" ]]; then
  echo "Error: empty input" >&2
  exit 2
fi

# Use Python for conversion since it has json/configparser in stdlib
python3 << PYEOF
import json, sys, configparser, io, re

input_text = '''$( echo "$INPUT" | sed "s/'/'\\''/g" )'''
from_fmt = "$FROM_FMT"
to_fmt = "$TO_FMT"
pretty = $( [[ "$PRETTY" == "true" ]] && echo "True" || echo "False" )

def parse_json(text):
    return json.loads(text)

def parse_yaml(text):
    # Simple YAML parser for flat/nested key-value
    result = {}
    current_section = result
    indent_stack = [(0, result)]

    for line in text.strip().split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        indent = len(line) - len(line.lstrip())

        # Pop stack to find parent
        while len(indent_stack) > 1 and indent_stack[-1][0] >= indent:
            indent_stack.pop()
        current = indent_stack[-1][1]

        if ':' in stripped:
            key, _, val = stripped.partition(':')
            key = key.strip()
            val = val.strip()

            if val == '' or val == '|' or val == '>':
                # Nested section
                new_dict = {}
                current[key] = new_dict
                indent_stack.append((indent, new_dict))
            else:
                # Remove quotes
                if (val.startswith('"') and val.endswith('"')) or \
                   (val.startswith("'") and val.endswith("'")):
                    val = val[1:-1]
                # Type coercion
                if val.lower() == 'true':
                    val = True
                elif val.lower() == 'false':
                    val = False
                elif val.isdigit():
                    val = int(val)
                else:
                    try:
                        val = float(val)
                    except ValueError:
                        pass
                current[key] = val

    return result

def parse_toml(text):
    result = {}
    current = result
    for line in text.strip().split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if stripped.startswith('[') and stripped.endswith(']'):
            section = stripped[1:-1].strip()
            parts = section.split('.')
            current = result
            for part in parts:
                if part not in current:
                    current[part] = {}
                current = current[part]
        elif '=' in stripped:
            key, _, val = stripped.partition('=')
            key = key.strip()
            val = val.strip()
            if (val.startswith('"') and val.endswith('"')) or \
               (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            elif val.lower() == 'true':
                val = True
            elif val.lower() == 'false':
                val = False
            elif val.isdigit():
                val = int(val)
            else:
                try:
                    val = float(val)
                except ValueError:
                    pass
            current[key] = val
    return result

def parse_ini(text):
    cp = configparser.ConfigParser()
    cp.read_string(text)
    result = {}
    for section in cp.sections():
        result[section] = dict(cp[section])
    if cp.defaults():
        result['DEFAULT'] = dict(cp.defaults())
    return result

def to_json(data, pretty=False):
    indent = 2 if pretty else None
    return json.dumps(data, indent=indent, default=str)

def to_yaml(data, indent=0):
    lines = []
    prefix = '  ' * indent
    if isinstance(data, dict):
        for key, val in data.items():
            if isinstance(val, dict):
                lines.append(f'{prefix}{key}:')
                lines.append(to_yaml(val, indent + 1))
            elif isinstance(val, bool):
                lines.append(f'{prefix}{key}: {str(val).lower()}')
            elif isinstance(val, (int, float)):
                lines.append(f'{prefix}{key}: {val}')
            else:
                lines.append(f'{prefix}{key}: "{val}"')
    return '\n'.join(lines)

def to_toml(data, section=''):
    lines = []
    scalars = {}
    sections = {}
    for key, val in data.items():
        if isinstance(val, dict):
            sections[key] = val
        else:
            scalars[key] = val

    if section:
        lines.append(f'[{section}]')

    for key, val in scalars.items():
        if isinstance(val, bool):
            lines.append(f'{key} = {str(val).lower()}')
        elif isinstance(val, (int, float)):
            lines.append(f'{key} = {val}')
        else:
            lines.append(f'{key} = "{val}"')

    for key, val in sections.items():
        new_section = f'{section}.{key}' if section else key
        lines.append('')
        lines.append(to_toml(val, new_section))

    return '\n'.join(lines)

def to_ini(data):
    cp = configparser.ConfigParser()
    for section, values in data.items():
        if isinstance(values, dict):
            cp[section] = {k: str(v) for k, v in values.items()}
        else:
            if 'DEFAULT' not in dict(cp):
                cp['main'] = {}
            cp['main'][section] = str(values)
    output = io.StringIO()
    cp.write(output)
    return output.getvalue().strip()

# Parse input
try:
    if from_fmt == 'json':
        data = parse_json(input_text)
    elif from_fmt == 'yaml':
        data = parse_yaml(input_text)
    elif from_fmt == 'toml':
        data = parse_toml(input_text)
    elif from_fmt == 'ini':
        data = parse_ini(input_text)
    else:
        print(f'Error: unknown input format: {from_fmt}', file=sys.stderr)
        sys.exit(2)
except Exception as e:
    print(f'Error parsing {from_fmt}: {e}', file=sys.stderr)
    sys.exit(1)

# Output
try:
    if to_fmt == 'json':
        print(to_json(data, pretty))
    elif to_fmt == 'yaml':
        print(to_yaml(data))
    elif to_fmt == 'toml':
        print(to_toml(data))
    elif to_fmt == 'ini':
        print(to_ini(data))
    else:
        print(f'Error: unknown output format: {to_fmt}', file=sys.stderr)
        sys.exit(2)
except Exception as e:
    print(f'Error converting to {to_fmt}: {e}', file=sys.stderr)
    sys.exit(1)
PYEOF
