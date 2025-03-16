import sys
import json
import re

if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <json_file>", file=sys.stderr)
    sys.exit(1)

# Load the JSON data (an array of package objects)
with open(sys.argv[1], "r") as f:
    json_data = json.load(f)

# Build a lookup: package name (lowercase) → check info.
pkg_info = {}
for entry in json_data:
    pkg_name = entry["package"].lower()
    pkg_info[pkg_name] = {
        "pyproject_toml": entry.get("pyproject_toml", False),
        "setup_py": entry.get("setup_py", False)
    }

# Define emoji choices (feel free to change these)
PYPROJECT_YES = "✅"   # Using pyproject.toml
PYPROJECT_NO  = "❌"   # Not using pyproject.toml
SETUP_YES     = "✅"   # Using setup.py
SETUP_NO      = "❌"   # Not using setup.py

# Process pipdeptree output from standard input.
for line in sys.stdin:
    pkg = None
    if "==" in line:
        # Handle the first type of row: pipdeptree==2.25.1
        parts = line.split("==")
        if len(parts) == 2:
            pkg = parts[0].strip().lower()
    elif "installed:" in line:
        # Handle the second type of row: │ ├── numpy [required: >=1.19.5, installed: 1.26.4]
        parts = line.split("installed:")
        if len(parts) == 2:
            pkg_part = parts[0].split(" [required:")[0].strip()
            pkg = pkg_part.split()[-1].lower()

    if pkg and pkg in pkg_info:
        pyproj_emoji = PYPROJECT_YES if pkg_info[pkg]["pyproject_toml"] else PYPROJECT_NO
        setup_emoji  = SETUP_YES if pkg_info[pkg]["setup_py"] else SETUP_NO
        # Append annotations to the line.
        annotation = f" [pyproject.toml: {pyproj_emoji}] [setup.py: {setup_emoji}]"
        line = line.rstrip("\n") + annotation + "\n"
    sys.stdout.write(line)
