#!/usr/bin/env bash
# 74-ami-call-monitor.sh — real, live, human-readable narration of Asterisk call events via AMI
# (Asterisk Manager Interface, TCP 5038), built to close the one real, still-unverified question
# named by a 2026-09-07 survey of the CarePyre SIP Phone's current state: every upstream piece
# (PJSIP registration for ext 1000/1000web, provisioning, QR onboarding, Twilio trunk config) is
# confirmed real and working, but no one has ever watched a real INVITE actually reach a device,
# get answered, and carry a real call end to end — that's genuinely only checkable while someone
# is actively placing/receiving a real call, not something a one-shot script can prove alone.
#
# This script reads the AMI secret directly from /etc/asterisk/manager.conf's own real, generated
# `[parena]` section (set up by sudo-queue/50-install-asterisk-pbx.sh) INSIDE this root session —
# it is never printed to stdout, never logged, never leaves this script's own local TCP
# connection to 127.0.0.1:5038. Matches this monorepo's own standing "secrets from a queued
# script never surface to the agent's own terminal" rule (this script runs under the founder's
# own real root session, not the agent's, exactly like 50-install-asterisk-pbx.sh's own AMI
# secret before it).
#
# Usage:
#   sudo bash sudo-queue/74-ami-call-monitor.sh
# Then, while it's running, place a real test call (dial the CarePyre phone from a real number
# via the Twilio trunk, or dial out from the Android app / webphone to any real number, or just
# open the webphone and let it register) — this script prints each real AMI event as it happens
# in plain English, then Ctrl+C to stop. No AMI event ever crosses this script's own stdout
# verbatim (raw AMI lines are parsed, not echoed), so nothing sensitive (SIP passwords, full
# caller-ID strings beyond what's needed to narrate) leaks into this session's own transcript
# either.

set -euo pipefail

MANAGER_CONF=/etc/asterisk/manager.conf
if [ ! -r "$MANAGER_CONF" ]; then
  echo "error: $MANAGER_CONF not readable -- run this with sudo" >&2
  exit 1
fi

AMI_USER="parena"
AMI_SECRET="$(awk '/^\[parena\]/{f=1} f && /^secret/{print $3; exit}' "$MANAGER_CONF")"
if [ -z "$AMI_SECRET" ]; then
  echo "error: no [parena] manager user found in $MANAGER_CONF -- has sudo-queue/50-install-asterisk-pbx.sh been run?" >&2
  exit 1
fi

echo "Connecting to Asterisk Manager Interface on 127.0.0.1:5038..."

exec 3<>/dev/tcp/127.0.0.1/5038
IFS= read -r -t 5 banner <&3
echo "Connected: $banner"

printf 'Action: Login\r\nUsername: %s\r\nSecret: %s\r\n\r\n' "$AMI_USER" "$AMI_SECRET" >&3

# Read the Login response (2 lines: Response: Success / Message: ...), confirm it, then discard.
login_ok=0
while IFS= read -r -t 5 line <&3; do
  line="${line%$'\r'}"
  [ -z "$line" ] && break
  if [[ "$line" == "Response: Success" ]]; then login_ok=1; fi
done
if [ "$login_ok" != "1" ]; then
  echo "error: AMI login failed -- check the [parena] secret in $MANAGER_CONF" >&2
  exit 1
fi
echo "✓ AMI login succeeded (user: $AMI_USER)"
echo "Now watching for real call events -- place a test call, or just let a phone register. Ctrl+C to stop."
echo "---"

declare -A ev
while IFS= read -r -t 3600 line <&3; do
  line="${line%$'\r'}"
  if [ -z "$line" ]; then
    # A full event block just ended -- narrate it.
    case "${ev[Event]:-}" in
      Newchannel)
        echo "[call] new channel: ${ev[Channel]:-?} (caller: ${ev[CallerIDNum]:-unknown})"
        ;;
      Newstate)
        if [ "${ev[ChannelStateDesc]:-}" = "Ringing" ]; then
          echo "[call] ${ev[Channel]:-?} is ringing"
        elif [ "${ev[ChannelStateDesc]:-}" = "Up" ]; then
          echo "[call] ${ev[Channel]:-?} answered -- call is UP (real audio path should now be flowing)"
        fi
        ;;
      DialEnd)
        echo "[call] dial to ${ev[DestChannel]:-?} ended: ${ev[DialStatus]:-unknown}"
        ;;
      Hangup)
        echo "[call] ${ev[Channel]:-?} hung up (cause: ${ev[Cause-txt]:-unknown})"
        ;;
      ContactStatus)
        echo "[reg]  ${ev[AOR]:-?} contact status: ${ev[ContactStatus]:-?}"
        ;;
    esac
    unset ev
    declare -A ev
    continue
  fi
  key="${line%%:*}"
  val="${line#*: }"
  ev["$key"]="$val"
done

echo "AMI connection closed."
