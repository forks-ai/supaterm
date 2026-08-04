#!/usr/bin/env bash
set -euo pipefail

run_state_root="${1:?usage: reap-run-state.sh <run-state-root>}"

if [ ! -d "${run_state_root}" ]; then
  exit 0
fi

own_process_group="$(ps -o pgid= -p $$ | tr -d ' ')"
process_table="$(ps -Awwo pid=,pgid=,ucomm=,command= -E)"

# A zmx daemon setsids and outlives both its socket and the app that spawned it,
# so the process table is the only authority on which sessions a run still owns.
session_leaders() {
  awk -v entry="ZMX_DIR=$1" -v own="${own_process_group}" '
    $1 == $2 && $1 != own && index($0 " ", entry " ") { print $1 }
  ' <<<"${process_table}"
}

has_live_app() {
  awk -v entry="SUPATERM_STATE_HOME=$1" '
    $3 == "supaterm" && index($0 " ", entry " ") { found = 1 }
    END { exit !found }
  ' <<<"${process_table}"
}

wait_for_group_exit() {
  local leader="$1" attempts="$2"
  while [ "${attempts}" -gt 0 ]; do
    if ! kill -0 -- "-${leader}" 2>/dev/null; then
      return 0
    fi
    attempts=$((attempts - 1))
    sleep 0.05
  done
  ! kill -0 -- "-${leader}" 2>/dev/null
}

terminate_group() {
  local leader="$1"
  kill -HUP -- "-${leader}" 2>/dev/null || true
  if wait_for_group_exit "${leader}" 10; then
    return 0
  fi
  kill -KILL -- "-${leader}" 2>/dev/null || true
  wait_for_group_exit "${leader}" 40
}

status=0
for state_home in "${run_state_root}"/*; do
  [ -d "${state_home}" ] || continue
  if has_live_app "${state_home}"; then
    continue
  fi

  survivors=0
  for leader in $(session_leaders "${state_home}/zmx"); do
    if terminate_group "${leader}"; then
      printf 'reaped zmx session %s from %s\n' "${leader}" "${state_home}"
    else
      printf 'error: zmx session %s survived in %s\n' "${leader}" "${state_home}" >&2
      survivors=1
    fi
  done

  if [ "${survivors}" -eq 0 ]; then
    rm -rf "${state_home}"
  else
    status=1
  fi
done

exit "${status}"
