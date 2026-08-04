#!/usr/bin/env bash
set -euo pipefail

run_state_root="${1:?usage: reap-run-state.sh <run-state-root>}"

if [ ! -d "${run_state_root}" ]; then
  exit 0
fi

own_process_group="$(ps -o pgid= -p $$ | tr -d ' ')"

# A zmx daemon setsids and outlives both its socket and the app that spawned it,
# so the process table is the only authority on which sessions a run still owns.
# `ps -E` appends the environment to the command with no delimiter, so the
# environment of a process is what remains once its own argv is stripped off.
# Reading the whole line instead would let a mere argument name a run.
process_table="$(
  {
    ps -Awwo pid=,pgid=,ucomm= | sed 's/^/identity /'
    ps -Awwo pid=,command= | sed 's/^/argv /'
    ps -Awwo pid=,command= -E | sed 's/^/full /'
  } | awk '
    { value = $0; sub(/^[a-z]+[[:space:]]+[0-9]+[[:space:]]+/, "", value) }
    $1 == "identity" {
      leads[$2] = ($2 == $3)
      sub(/^[0-9]+[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      name[$2] = value
      next
    }
    $1 == "argv" { argv[$2] = value; next }
    $1 == "full" { full[$2] = value }
    END {
      for (processID in full) {
        if (!(processID in argv)) continue
        arguments = argv[processID]
        if (substr(full[processID], 1, length(arguments)) != arguments) continue
        printf "%d\t%d\t%s\t%s\n", processID, leads[processID], name[processID],
          substr(full[processID], length(arguments) + 1)
      }
    }
  '
)"

session_leaders() {
  awk -F '\t' -v entry="ZMX_DIR=$1" -v own="${own_process_group}" '
    $3 == "zmx" && $2 == 1 && $1 != own && index($4 " ", " " entry " ") { print $1 }
  ' <<<"${process_table}"
}

has_live_app() {
  awk -F '\t' -v entry="SUPATERM_STATE_HOME=$1" '
    $3 == "supaterm" && index($4 " ", " " entry " ") { found = 1 }
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
