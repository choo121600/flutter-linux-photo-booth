#!/bin/bash
# Ubu4Cut touch auto-recovery watchdog.
#
# The G2Touch USB touchscreen re-enumerates intermittently. Two failure modes:
#   1. Lost grab:  the current event node is no longer held open by any process.
#   2. Limbo:      a stale fd keeps the node "held", OR Frame (re)started while the
#                  device was mid-re-enumeration, so Frame never configured it as a
#                  touchscreen input. The fd looks held but touch is NOT delivered.
#
# The first watchdog only checked (1) and false-passed on (2). This version also
# inspects Frame's own log: if the most recent G2Touch input transition is a
# "Removed device" (rather than "Opened device" / "Device configuration"), touch
# is lost regardless of fd state. After restarting Frame it verifies the
# touchscreen actually re-registered, and retries if it did not.
#
# Only acts when touch is lost, so a working session is never disrupted.
#
# NOTE: this is a safety net, not the real fix. The underlying cause is a
# marginal USB link (device runs at full-speed 12Mbps and re-enumerates every
# few minutes). The durable fix is a powered USB 2.0 hub and/or a better cable.
set -u
BYID="/dev/input/by-id/usb-G2Touch_Multi-Touch_by_G2TSP-event-if00"
MATCH="G2Touch"
last=0; fails=0
log(){ echo "ubu4cut-touch-wd: $*"; }

# 0 if the given node is held open by any process
held(){ local n="$1" fd t; for fd in /proc/[0-9]*/fd/*; do t="$(readlink "$fd" 2>/dev/null)" || continue; [ "$t" = "$n" ] && return 0; done; return 1; }

# 0 if Frame's most recent G2Touch input transition is an add (present),
# 1 if it is a removal (Frame has de-configured the touchscreen)
frame_has_touch(){
  local line
  line="$(snap logs ubuntu-frame -n 400 2>/dev/null | grep -a "$MATCH" \
          | grep -aoE 'Opened device|Device configuration|Removed device' | tail -1)"
  [ "$line" = "Removed device" ] && return 1
  return 0
}

# 0 only if touch is actually being delivered (held AND Frame still has it)
touch_working(){ local n="$1"; held "$n" && frame_has_touch; }

# restart Frame and confirm the touchscreen re-registers; 0 on success
restart_frame(){
  snap restart ubuntu-frame >/dev/null 2>&1 || true
  sleep 15
  snap logs ubuntu-frame -n 80 2>/dev/null | grep -aq "Device configuration:.*$MATCH.*touchscreen"
}

log "started"
while true; do
  sleep 20
  node="$(readlink -f "$BYID" 2>/dev/null)"
  if [ -z "$node" ] || [ ! -e "$node" ]; then continue; fi
  if touch_working "$node"; then fails=0; continue; fi
  now="$(date +%s)"
  if [ "$fails" -ge 3 ]; then
    if [ $((now - last)) -lt 600 ]; then continue; fi
    log "still lost after 3 restarts (hardware/cable?) - backing off 10m"; fails=0
  fi
  if [ $((now - last)) -lt 40 ]; then continue; fi
  log "touch lost (unheld or Frame de-configured) -> restart ubuntu-frame (try $((fails+1)))"
  last="$(date +%s)"
  if restart_frame; then log "touch re-registered after restart"; fails=0
  else log "touch NOT registered after restart (device mid-reenum?) - will retry"; fails=$((fails+1)); fi
done
