#!/bin/sh
# MeeVPN: use the DNS servers pushed by the VPN server (dhcp-option DNS)
# while connected, and give the phone's own back afterwards.
# Called by OpenVPN as --up/--down (script_type=up|down), or by the engine.
# The N9 resolves through a local dnsmasq (2.45, started with -1 = D-Bus);
# the system hands it the upstream servers over D-Bus (SetServers), so we do
# the same. No system file is changed (/etc/resolv.conf stays 127.0.0.1).
RUN=/var/run/openvpn-n9
MARK=$RUN/dns.active

set_servers() {
    # SetServers takes each IPv4 address as uint32 in network byte order
    args=""
    for ip in "$@"; do
        n=$(echo "$ip" | awk -F. 'NF==4 {printf "%.0f", $1 + $2*256 + $3*65536 + $4*16777216}')
        [ -n "$n" ] && args="$args uint32:$n"
    done
    [ -n "$args" ] || return 1
    dbus-send --system --type=method_call --dest=uk.org.thekelleys.dnsmasq \
        /uk/org/thekelleys/dnsmasq uk.org.thekelleys.SetServers $args
}

phone_servers() {
    # the servers of the current Wi-Fi / mobile connection, as written by the system
    f=$(ls -t /var/run/resolv.conf.* 2>/dev/null | head -1)
    [ -n "$f" ] && sed -n 's/^nameserver \([0-9.]*\)$/\1/p' "$f"
}

if [ "$script_type" = up ]; then
    NS=""; i=1
    while :; do
        eval o=\"\$foreign_option_$i\"
        [ -n "$o" ] || break
        case "$o" in
            "dhcp-option DNS "*) NS="$NS ${o#dhcp-option DNS }";;
        esac
        i=$((i+1))
    done
    [ -n "$NS" ] || { echo "meevpn dns: server sent no DNS, phone DNS kept"; exit 0; }
    if set_servers $NS; then
        echo "$NS" > $MARK
        echo "meevpn dns: using$NS"
    else
        echo "meevpn dns: could not set DNS"
    fi
else
    if [ -f $MARK ]; then
        rm -f $MARK
        set_servers $(phone_servers) && echo "meevpn dns: phone DNS restored" || echo "meevpn dns: no phone DNS to restore"
    fi
fi
exit 0
