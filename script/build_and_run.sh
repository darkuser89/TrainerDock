#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--smoke|--debug|--logs|--telemetry|--launcher-only) ;; *) echo 'Usage: build_and_run.sh [run|--build-only|--verify|--smoke|--debug|--logs|--telemetry|--launcher-only]' >&2;exit 2;; esac
BUILD="${TRAINERDOCK_BUILD_DIR:-${MHT_BUILD_DIR:-$HOME/Library/Developer/TrainerDock}}"
export PYTHONDONTWRITEBYTECODE=1
# Only terminate this launcher for a requested relaunch. Games remain user-owned.
if [[ "$MODE" != --build-only ]]; then
    pkill -x TrainerDock 2>/dev/null || true
fi
if [[ "$MODE" == --launcher-only ]]; then
    python3 -B "$ROOT/script/build.py" --build-dir "$BUILD" --launcher-only
else
    python3 -B "$ROOT/script/build.py" --build-dir "$BUILD"
fi
APP="$BUILD/TrainerDock.app"
case "$MODE" in
    --build-only) ;;
    --debug) lldb -- "$APP/Contents/MacOS/TrainerDock" ;;
    --smoke) open -n "$APP" --args --smoke ;;
    --verify) open -n "$APP"; sleep 2; pgrep -x TrainerDock >/dev/null ;;
    --launcher-only) open -n "$APP"; sleep 2; pgrep -x TrainerDock >/dev/null ;;
    --logs|--telemetry) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "TrainerDock"' ;;
    run) open -n "$APP" ;;
esac
