#!/bin/sh
# MeeVPN engine: starts and stops OpenVPN (package openvpn-n9) for the app.
# Run as root only through /opt/meevpn-n9/bin/meevpn-root, which allows:
#   start <profile.ovpn> [dns] [auth]   profile = file name in MyDocs/openvpn
#   stop | version
# With "auth" the user name and password come on stdin (two lines).
# The app reads the state itself (pid file, log, tun0), no root needed.
# Same files as the vpn-start / vpn-stop / vpn-status commands, so both work together.
# Designed and written by Claude (Anthropic) together with smyhu for Nokia N9. MIT licence.
ENGINE_VERSION=0.1.0
OV=/opt/openvpn-n9/sbin/openvpn
STOPPER=/opt/openvpn-n9/sbin/openvpn-n9-stop
DIR=/home/user/MyDocs/openvpn
RUN=/var/run/openvpn-n9
PID=/var/run/openvpn-n9.pid
LOG=/var/log/openvpn-n9.log
ME=/opt/meevpn-n9

running() { [ -f $PID ] && [ -d "/proc/$(cat $PID 2>/dev/null)" ]; }

cmd_start() {
    NAME=$1; shift
    DNS=0; AUTH=0
    for o in "$@"; do case "$o" in dns) DNS=1;; auth) AUTH=1;; esac; done
    P="$DIR/$NAME"
    [ -f "$P" ] || { echo "ERROR no-profile $P"; exit 2; }
    [ -x $OV ] || { echo "ERROR no-openvpn (install openvpn-n9)"; exit 3; }
    if running; then echo "ERROR already-running"; exit 4; fi
    mkdir -p /var/log $RUN
    chmod 755 $RUN
    rm -f $RUN/auth.txt
    if [ $AUTH = 1 ]; then
        read -r U; read -r W
        [ -n "$U" ] || { echo "ERROR no-username"; exit 5; }
        (umask 077; printf '%s\n%s\n' "$U" "$W" > $RUN/auth.txt)
    fi
    # Working copy of the profile: IPv4 only (the N9 has no usable IPv6),
    # no socket-flags (old kernel), saved login instead of a password prompt.
    C=$RUN/profile.ovpn
    (umask 077
     tr -d '\r' < "$P" | sed -e 's/^\(remote [^ ]* [0-9]* udp\) *$/\14/' -e 's/^\(remote [^ ]* [0-9]* tcp\) *$/\14/' \
        -e 's/^proto udp *$/proto udp4/' -e 's/^proto tcp *$/proto tcp4/' -e 's/^proto tcp-client *$/proto tcp4-client/' \
        -e '/^socket-flags/d' > "$C"
     grep -q '^proto ' "$C" || echo "proto udp4" >> "$C"
     if [ $AUTH = 1 ]; then
        sed -i -e "s#^auth-user-pass *\$#auth-user-pass $RUN/auth.txt#" -e "s#^auth-user-pass .*#auth-user-pass $RUN/auth.txt#" "$C"
     fi)
    printf 'profile=%s\ndns=%s\n' "$NAME" "$DNS" > $RUN/meevpn.state
    chmod 644 $RUN/meevpn.state
    if [ $DNS = 1 ]; then
        set -- --script-security 2 --up $ME/dns.sh --down $ME/dns.sh
    else
        set -- --script-security 1 --pull-filter ignore "dhcp-option"
    fi
    $OV --cd "$DIR" --config "$C" --daemon openvpn-n9 --log $LOG --writepid $PID \
        "$@" --pull-filter ignore "block-outside-dns" --pull-filter ignore "remote-cache-lifetime" --pull-filter ignore "ifconfig-ipv6" --pull-filter ignore "route-ipv6"
    rc=$?
    chmod 644 $LOG 2>/dev/null
    if [ $rc != 0 ]; then
        tail -5 $LOG 2>/dev/null
        echo "ERROR openvpn-exit $rc"
        rm -f $RUN/auth.txt
        exit 6
    fi
    echo "OK started $NAME"
}

cmd_stop() {
    $STOPPER
    # openvpn's own --down normally restores DNS; this covers a crashed process
    i=0
    while [ -f $RUN/dns.active ] && [ $i -lt 6 ]; do sleep 1; i=$((i+1)); done
    [ -f $RUN/dns.active ] && script_type=down sh $ME/dns.sh
    rm -f $RUN/auth.txt $RUN/meevpn.state
    echo "OK stopped"
}

case "$1" in
    start) shift; cmd_start "$@";;
    stop) cmd_stop;;
    version) echo "$ENGINE_VERSION";;
    *) echo "ERROR unknown command"; exit 64;;
esac
