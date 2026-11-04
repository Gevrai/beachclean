#!/usr/bin/env bash
# Usage: tools/offscreen.sh <cmd...>  -- run a command (typically godot) inside a headless sway so
# windows render on the real GPU without showing on the desktop. Sets WAYLAND_DISPLAY/XDG_RUNTIME_DIR
# for the command; it must pass `--display-driver wayland` to godot itself (screenshot.sh does).
# Owns sway lifetime: kills the command and sway on exit/INT/TERM; a watchdog covers SIGKILL.
repo="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v sway >/dev/null 2>&1; then echo "install sway: sudo dnf install sway"; exit 1; fi
mkdir -p "$repo/.logs"
# Short path: unix socket paths max out at 108 chars.
rt="$(mktemp -d /tmp/sw.XXXXXX)"
chmod 700 "$rt"
sway_pid=""
cmd_pid=""
cleanup() {
  trap - EXIT INT TERM
  if [ -n "$cmd_pid" ] && kill -0 "$cmd_pid" 2>/dev/null; then
    kill -TERM "$cmd_pid" 2>/dev/null
    for _ in $(seq 1 30); do kill -0 "$cmd_pid" 2>/dev/null || break; sleep 0.1; done
    kill -KILL "$cmd_pid" 2>/dev/null
  fi
  if [ -n "$sway_pid" ]; then
    kill "$sway_pid" 2>/dev/null
    for _ in $(seq 1 20); do kill -0 "$sway_pid" 2>/dev/null || break; sleep 0.1; done
    kill -KILL "$sway_pid" 2>/dev/null
    wait "$sway_pid" 2>/dev/null
  fi
  rm -rf "$rt"
}
trap cleanup EXIT
trap 'exit 143' INT TERM
self=$$
XDG_RUNTIME_DIR="$rt" WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 \
  sway -c "$repo/tools/sway-headless.conf" >"$repo/.logs/sway.log" 2>&1 &
sway_pid=$!
# Watchdog: if this script is SIGKILLed (no trap runs), still take sway and the temp dir down.
( while kill -0 "$self" 2>/dev/null; do sleep 1; done
  kill "$sway_pid" 2>/dev/null; sleep 1; kill -KILL "$sway_pid" 2>/dev/null; rm -rf "$rt" ) >/dev/null 2>&1 &
for _ in $(seq 1 50); do
  [ -S "$rt/wayland-1" ] && break
  sleep 0.1
done
if [ ! -S "$rt/wayland-1" ]; then echo "sway did not start (log: .logs/sway.log)"; exit 1; fi
# Run the command in the background and wait, so INT/TERM traps fire immediately.
XDG_RUNTIME_DIR="$rt" WAYLAND_DISPLAY=wayland-1 "$@" &
cmd_pid=$!
wait "$cmd_pid"
rc=$?
cmd_pid=""
exit "$rc"
