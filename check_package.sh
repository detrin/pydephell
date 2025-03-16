#!/usr/bin/env bash

set -e

package=""
version=""
PYTHON=""
debug=false
json_output=false

temp_dir=$(mktemp -d -t package_analysis_XXXXXX)

function cleanup {
    rm -rf "$temp_dir"
}

function error_exit {
    echo "ERROR: $1" >&2
    if [ -n "$package" ] && [ -n "$version" ]; then
        echo "Package: $package" >&2
        echo "Version: $version" >&2
    fi
    cleanup
    exit 1
}

trap cleanup EXIT

function usage {
    echo "Usage: $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "  -p, --package PACKAGE   Package name (default: quantarhei)"
    echo "  -v, --version VERSION   Package version (default: latest)"
    echo "  -y, --python PATH       Python executable path (default: /opt/homebrew/bin/python3.12)"
    echo "  -d, --debug             Enable debug mode to show pip output"
    echo "  -j, --json              Output results in JSON format"
    echo "  -h, --help              Show this help message"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--package)
            package="$2"
            shift 2
            ;;
        -v|--version)
            version="$2"
            shift 2
            ;;
        -y|--python)
            PYTHON="$2"
            shift 2
            ;;
        -d|--debug)
            debug=true
            shift
            ;;
        -j|--json)
            json_output=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [ ! -x "$PYTHON" ]; then
    echo "ERROR: Python executable not found or not executable: $PYTHON"
    rm -rf "$temp_dir"
    exit 1
fi

cd "$temp_dir"

get_sdist_url() {
    local package_version="$1"
    local package="${package_version%%==*}"
    local version="${package_version##*==}"
    
    # Fetch package metadata from PyPI
    local json=$(curl -s "https://pypi.org/pypi/${package}/json")
    
    # Extract the URL of the sdist package for the given version
    local url=$(echo "$json" | jq -r --arg version "$version" '
        .releases[$version][] | select(.packagetype == "sdist") | .url'
    )

    # Check if URL was found
    if [[ -n "$url" && "$url" != "null" ]]; then
        echo "$url"
    else
        echo "Error: No source distribution (sdist) found for $package_version" >&2
        return 1
    fi
}

if [ -z "$version" ]; then
    $debug && echo "Fetching latest version info for $package..."
    version=$(curl -s "https://pypi.org/pypi/$package/json" | jq -r '.info.version') || error_exit "Failed to get version information from PyPI"
    
    if [ -z "$version" ] || [ "$version" == "null" ]; then
        error_exit "Failed to retrieve a valid version number"
    fi
    $debug && echo "Latest version: $version"
fi

$debug && echo "Downloading ${package}==${version}..."
sdist_url=$(get_sdist_url $package==$version)
wget -q $sdist_url || error_exit "Failed to download source distribution from $sdist_url"
tar_file=$(basename $sdist_url)

if [ ! -f $tar_file ]; then
    error_exit "Package archive ${package}-${version}.tar.gz not found after download"
fi

$debug && echo "Analyzing package structure..."
tar_output=$(tar -tf $tar_file 2>/dev/null) || error_exit "Failed to extract contents from $tar_file"

pyproject_found=false
setup_found=false

if echo "$tar_output" | grep -q "${package}-${version}/pyproject.toml"; then
    pyproject_found=true
fi

if echo "$tar_output" | grep -q "${package}-${version}/setup.py"; then
    setup_found=true
fi

if $json_output; then
    echo "{\"package\": \"$package\", \"version\": \"$version\", \"pyproject_toml\": $pyproject_found, \"setup_py\": $setup_found}"
else
    echo "Package: $package"
    echo "Version: $version"
    if $pyproject_found; then
        echo "✅ pyproject.toml found in the package"
    else
        echo "❌ pyproject.toml not found in the package"
    fi

    if $setup_found; then
        echo "✅ setup.py found in the package"
    else
        echo "❌ setup.py not found in the package"
    fi
fi