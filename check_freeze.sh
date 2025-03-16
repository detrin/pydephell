#!/usr/bin/env bash

set -e

VERSION="1.0.0"
PYTHON_PATH="python"
CORES=8

usage() {
  echo "Usage: $0 [-p python_path] [-c cores] [-h] [-v] [--python python_path] [--cores cores] [--help] [--version]"
  echo "  -p, --python  Specify the Python path (default: python)"
  echo "  -c, --cores   Specify the number of cores (default: 8)"
  echo "  -h, --help    Show help"
  echo "  -v, --version Show version"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--python) PYTHON_PATH="$2"; shift ;;
    -c|--cores) CORES="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "$0 version $VERSION"; exit 0 ;;
    *) usage; exit 1 ;;
  esac
  shift
done

check_package() {
  local pkg_ver=$1
  local pkg=$(echo "$pkg_ver" | awk -F'==' '{print $1}')
  local ver=$(echo "$pkg_ver" | awk -F'==' '{print $2}')
  ./check_package.sh --python "$PYTHON_PATH" --package "$pkg" --version "$ver" --json
}

export -f check_package
export PYTHON_PATH

total_lines=$(pip freeze | wc -l)
pip freeze | parallel --progress --bar --total $total_lines -j $CORES check_package | jq -s .