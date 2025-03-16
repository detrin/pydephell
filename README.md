# pydephell

## Usage

```
$ uv venv
$ PYTHON_PATH=$(uv run python -c "import sys;print(sys.executable)")
$ uv run bash check_freeze.sh -p $PYTHON_PATH > results.json
$ uv run pipdeptree | uv run python annotate_pipdeptree.py results.json 
pipdeptree==2.24.0 [pyproject.toml: ✅] [setup.py: ❌]
├── packaging [required: >=24.1, installed: 24.2] [pyproject.toml: ✅] [setup.py: ❌]
└── pip [required: >=24.2, installed: 25.0.1]
```