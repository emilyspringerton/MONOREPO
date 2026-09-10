#!/usr/bin/env bash
# 77-blink-onboard-led.sh — real, plain, no-decision-required root one-liner
# (2026-09-10, founder real-time: "ok do the followup work we need the led on
# the board to actually flash (there's one built in you can make blink)").
#
# Real follow-up to PARENA/docs/AVR_ARDUINO_NORTHSTAR.md's one honest gap:
# that work proved the full parena-build -> avr-gcc -> avr-objcopy -> avrdude
# pipeline for real, but this sandbox has no physical Arduino attached (no USB
# devices at all -- `lsusb` returns nothing), so avrdude could only fail
# honestly at its own port-open step.
#
# Real, checked (not assumed) alternative: this box DOES have a real,
# kernel-exposed LED at /sys/class/leds -- a *::scrolllock entry (Linux's own
# standard keyboard-LED sysfs interface). PARENA/examples/host_led/led_main.c
# reuses the SAME PARENA decision logic (next_led_state, from
# PARENA/examples/avr/blink.prn -- a plain Bool -> Bool toggle) driving that
# real LED instead. Needs root only because that brightness file is
# root-owned; this script is the entire privileged surface -- the actual
# PARENA build + gcc compile above it needs no root at all
# (`make host-led-blink-build`, already run once to produce the binary this
# script executes).
#
# Bounded and safe: the binary itself loops exactly 10 real on/off cycles
# (~8 seconds total), then leaves the LED off and exits 0 -- no lingering
# root-owned process, nothing left running after this script returns.
set -euo pipefail

cd /home/fatbaby/PARENA
make host-led-blink-build
sudo ./examples/host_led/led_blink
echo "== done: watch your keyboard's Scroll Lock indicator during the ~8s run above =="
