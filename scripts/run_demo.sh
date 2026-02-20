#!/usr/bin/env bash
set -euo pipefail

data_dir="${DELTA_OUTPUT_DIR:-data}"
if [[ -z "${DELTA_OUTPUT_DIR:-}" && -n "${WSL_DISTRO_NAME:-}" && "${PWD}" == /mnt/* ]]; then
  data_dir="$HOME/delta-demo-data"
fi

export DELTA_OUTPUT_DIR="$data_dir"

if [[ "$DELTA_OUTPUT_DIR" != "data" ]]; then
  if [[ ! -e data ]]; then
    ln -s "$DELTA_OUTPUT_DIR" data
  elif [[ ! -L data ]]; then
    echo "data exists and is not a symlink; leaving it unchanged." >&2
  fi
fi

if [[ -n "${VIRTUAL_ENV:-}" ]]; then
  uv sync --active
  python simulate_data.py
else
  uv sync
  uv run python simulate_data.py
fi

npx @taleshaper/shaper &
server_pid=$!
trap 'kill "$server_pid"' EXIT

sleep 1
npx @taleshaper/shaper dev
