#!/bin/zsh
# Keep the simulator mirror alive until this terminal exits.
set -eu
export npm_config_cache="${npm_config_cache:-${TMPDIR:-/tmp}/CalendarSix-npm-cache}"
SIMULATOR_ID="${1:?Usage: serve_sim.sh <simulator-udid>}"
cleanup_serve_sim() {
  npx --yes serve-sim@latest --kill "$SIMULATOR_ID" >/dev/null 2>&1 || true
}
trap cleanup_serve_sim EXIT INT TERM HUP
cleanup_serve_sim
npx --yes serve-sim@latest "$SIMULATOR_ID"
