#!/usr/bin/env bash
# 98-shankpit-camp-lan-pi.sh -- make a Raspberry Pi Zero W / 2W the network for a SHANKPIT night in the
# woods: a Wi-Fi access point, a DHCP server, and a DNS server that points the platform's names at the
# game host on the other end of the USB cable. No uplink, no cloud, no captive portal.
#
#     Pi wlan0   192.168.42.1/24   AP "SHANKPIT_CAMP_LAN"  -> phones, laptops   (.10-.150)
#     Pi usb0    192.168.43.1/24   USB gadget (g_ether)    -> the game host     (.10)
#
# The HOST side (Windows/camp box) runs IDUNA + WOTAN (docker-compose.camp.yml / camp-deploy.sh) and
# the game itself. This script only writes the Pi's own config and enables its services.
#
#   sudo ./98-shankpit-camp-lan-pi.sh            apply
#   DRY_RUN=1 sudo ./98-shankpit-camp-lan-pi.sh  print every change, write nothing
#
# NOT VERIFIED: no Pi is attached to the box this was written on, so nothing here has been run on real
# hardware. The configs are the standard hostapd/dnsmasq/g_ether shapes; the first boot is the test.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
AP_IF="${CAMP_AP_IF:-wlan0}"
USB_IF="${CAMP_USB_IF:-usb0}"
AP_IP="192.168.42.1"
USB_IP="192.168.43.1"
HOST_IP="${CAMP_HOST_IP:-192.168.43.10}"
SSID="${CAMP_SSID:-SHANKPIT_CAMP_LAN}"
PSK="${CAMP_PSK:-campvibesonly}"
BOOT_DIR=""

run() { if [ "$DRY_RUN" = 1 ]; then echo "  DRY: $*"; else "$@"; fi; }

say() { echo; echo "== $* =="; }

say "0. sanity"
if [ ! -e /etc/os-release ] || ! grep -qi 'raspbian\|debian' /etc/os-release; then
  echo "  WARNING: this does not look like Raspberry Pi OS. Continuing anyway." >&2
fi
for f in /boot/config.txt /boot/firmware/config.txt; do
  [ -f "$f" ] && BOOT_DIR="$(dirname "$f")" && break
done
if [ -z "$BOOT_DIR" ]; then
  echo "  WARNING: no /boot/config.txt or /boot/firmware/config.txt -- the USB gadget step will be skipped." >&2
fi
echo "  AP ${SSID} on ${AP_IF} (${AP_IP}), host over ${USB_IF} (${USB_IP}) -> ${HOST_IP}"

say "1. packages"
run apt-get update
run apt-get install -y hostapd dnsmasq

say "2. static addresses (dhcpcd hooks so hostapd/dnsmasq never fight over wlan0)"
if [ -f /etc/dhcpcd.conf ] && ! grep -q "SHANKPIT CAMP LAN" /etc/dhcpcd.conf; then
  BACKUP="/etc/dhcpcd.conf.campbak.$(date +%s)"
  run cp /etc/dhcpcd.conf "$BACKUP"
  echo "  backup: $BACKUP"
  if [ "$DRY_RUN" = 1 ]; then
    echo "  DRY: append interface ${AP_IF} / ${USB_IF} blocks to /etc/dhcpcd.conf"
  else
    cat >> /etc/dhcpcd.conf <<EOF

# SHANKPIT CAMP LAN -- static addresses the Pi must always have, uplink or not.
interface ${AP_IF}
    static ip_address=${AP_IP}/24
    nohook wpa_supplicant

interface ${USB_IF}
    static ip_address=${USB_IP}/24
EOF
  fi
else
  echo "  already configured (or no dhcpcd): skipped"
fi

say "3. access point (/etc/hostapd/hostapd.conf)"
run mkdir -p /etc/hostapd
if [ "$DRY_RUN" = 1 ]; then
  echo "  DRY: write hostapd.conf ssid=${SSID} hw_mode=g channel=7 wpa=2"
else
  [ -f /etc/hostapd/hostapd.conf ] && cp /etc/hostapd/hostapd.conf "/etc/hostapd/hostapd.conf.campbak.$(date +%s)"
  cat > /etc/hostapd/hostapd.conf <<EOF
# SHANKPIT CAMP LAN. 2.4GHz channel 7 for reach through tents and trees; this is a camp, not a cafe.
interface=${AP_IF}
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${PSK}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
fi
if [ -f /etc/default/hostapd ] && ! grep -q '^DAEMON_CONF="/etc/hostapd/hostapd.conf"' /etc/default/hostapd; then
  say "  point /etc/default/hostapd at the config"
  run sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
fi

say "4. DHCP + DNS (/etc/dnsmasq.d/shankpit-camp.conf)"
run mkdir -p /etc/dnsmasq.d
if [ "$DRY_RUN" = 1 ]; then
  echo "  DRY: write dnsmasq drop-in (dhcp-range wlan0/usb0, address=/${HOST_IP} for platform names)"
else
  cat > /etc/dnsmasq.d/shankpit-camp.conf <<EOF
# SHANKPIT CAMP LAN. Two jobs: hand out addresses, and point the platform's own names at the host
# across the USB cable -- so the SHANKPIT client and a phone app need no /etc/hosts surgery.
interface=${AP_IF}
interface=${USB_IF}
bind-interfaces
listen-address=127.0.0.1,${AP_IP},${USB_IP}
dhcp-range=${AP_IF},192.168.42.10,192.168.42.150,255.255.255.0,12h
dhcp-range=${USB_IF},192.168.43.10,192.168.43.20,255.255.255.0,12h

# The host is the camp's IDUNA/WOTAN. Every name below resolves to it, with no internet to ask.
address=/iduna.local/${HOST_IP}
address=/wotan.local/${HOST_IP}
address=/okemily.com/${HOST_IP}
address=/www.okemily.com/${HOST_IP}
address=/iduna.okemily.com/${HOST_IP}
address=/wotan.okemily.com/${HOST_IP}
# Everything else: fail fast and honestly instead of hanging on a dead uplink.
address=/#/${HOST_IP}
EOF
fi

say "5. USB gadget (the 'xbox' cable): dwc2 + g_ether"
if [ -n "$BOOT_DIR" ] && [ -f "$BOOT_DIR/config.txt" ]; then
  if grep -q '^dtoverlay=dwc2' "$BOOT_DIR/config.txt"; then
    echo "  dtoverlay=dwc2 already present"
  else
    run sh -c "printf '\n# SHANKPIT CAMP LAN: USB gadget (g_ether) so the game host gets a wired link\ndtoverlay=dwc2\n' >> '$BOOT_DIR/config.txt'"
  fi
  if [ -f "$BOOT_DIR/cmdline.txt" ] && ! grep -q 'modules-load=dwc2,g_ether' "$BOOT_DIR/cmdline.txt"; then
    run sed -i 's/$/ modules-load=dwc2,g_ether/' "$BOOT_DIR/cmdline.txt"
    echo "  appended modules-load=dwc2,g_ether to cmdline.txt (one line, as the firmware requires)"
  fi
  if [ -f /etc/modules ] && ! grep -q '^dwc2' /etc/modules; then
    run sh -c "printf 'dwc2\ng_ether\n' >> /etc/modules"
  fi
else
  echo "  SKIPPED: no boot config found"
fi

say "6. services"
run systemctl unmask hostapd
run systemctl enable hostapd dnsmasq
if [ "$DRY_RUN" = 1 ]; then
  echo "  DRY: systemctl restart hostapd dnsmasq"
else
  systemctl restart dnsmasq || true
  systemctl restart hostapd  || true
fi

say "7. verify"
cat <<EOF
  systemctl status hostapd --no-pager | head -5
  systemctl status dnsmasq --no-pager | head -5
  iw dev ${AP_IF} info | head -5
  ip -4 addr show ${USB_IF}
  # from the host, after the cable is in and the gadget has come up:
  ping -c1 ${USB_IP} && curl -s http://${HOST_IP}:8080/ | head -3
EOF
echo
echo "The Pi is the network. The host (${HOST_IP}) is IDUNA, WOTAN and the game."
