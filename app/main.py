#!/usr/bin/python
# -*- coding: utf-8 -*-
# MeeVPN - OpenVPN client app for the Nokia N9 (Harmattan PR1.3).
# Python 2.6 + PySide + QML. OpenVPN itself comes from the openvpn-n9 package;
# starting and stopping needs root, done by the small helper
# /opt/meevpn-n9/bin/meevpn-root (it accepts only start/stop/version).
# Everything else (state, log, profiles, saved logins) is read here as user.
# Designed and written by Claude (Anthropic) together with smyhu for Nokia N9. MIT licence.

import os
import re
import sys
import json
import time
import base64
import subprocess

from PySide.QtCore import QObject, QUrl, QProcess, QSettings, Signal, Slot
from PySide.QtGui import QApplication
from PySide.QtDeclarative import QDeclarativeView

APP_VERSION = '0.1.2'
BASE = '/opt/meevpn-n9'
APP_DIR = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(BASE, 'bin', 'meevpn-root')
OPENVPN = '/opt/openvpn-n9/sbin/openvpn'
PROFILE_DIR = '/home/user/MyDocs/openvpn'
PID_FILE = '/var/run/openvpn-n9.pid'
LOG_FILE = '/var/log/openvpn-n9.log'
STATE_FILE = '/var/run/openvpn-n9/meevpn.state'
TUN_STATS = '/sys/class/net/tun0/statistics/'
LOGINS = os.path.expanduser('~/.config/meevpn/logins.json')
BUS_NAME = 'com.github.smyhu.meevpn'
LANGUAGES = ('pl', 'en')


def read_file(path, default=''):
    try:
        f = open(path)
        try:
            return f.read()
        finally:
            f.close()
    except (IOError, OSError):
        return default


def log_tail(size=65536):
    try:
        f = open(LOG_FILE)
        try:
            f.seek(0, 2)
            n = f.tell()
            f.seek(max(0, n - size))
            data = f.read()
        finally:
            f.close()
    except (IOError, OSError):
        return ''
    return data.decode('utf-8', 'replace')


def session_env():
    if not os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
        for line in read_file('/tmp/session_bus_address.user').splitlines():
            line = line.strip()
            if line.startswith('export '):
                line = line[7:]
            if line.startswith('DBUS_SESSION_BUS_ADDRESS='):
                os.environ['DBUS_SESSION_BUS_ADDRESS'] = line.split('=', 1)[1].strip("'\"")


def phone_language():
    """Phone language from gconf; MEEVPN_LANG=en overrides it."""
    code = os.environ.get('MEEVPN_LANG', '')
    if not code:
        session_env()
        try:
            p = subprocess.Popen(['gconftool-2', '-g', '/meegotouch/i18n/language'],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            code = p.communicate()[0].strip()
        except OSError:
            pass
    code = (code or os.environ.get('LANG', ''))[:2].lower()
    return code if code in LANGUAGES else 'en'


VALID_NAME = re.compile(r'^[A-Za-z0-9_+() -][A-Za-z0-9._+() -]{0,74}\.(ovpn|conf)$')


def parse_profile(path):
    """Server, protocol and whether the profile asks for a user name/password."""
    remote, port, proto, auth = '', '', '', False
    inline = False
    for raw in read_file(path).splitlines():
        line = raw.strip()
        if not line or line[0] in '#;':
            continue
        if line.startswith('<auth-user-pass>'):
            inline = True
        f = line.split()
        key = f[0]
        if key == 'remote' and len(f) > 1 and not remote:
            remote = f[1]
            if len(f) > 2:
                port = f[2]
            if len(f) > 3:
                proto = f[3]
        elif key == 'port' and len(f) > 1 and not port:
            port = f[1]
        elif key == 'proto' and len(f) > 1:
            proto = f[1]
        elif key == 'auth-user-pass':
            # a file name after it = login is already in a file next to the profile
            auth = len(f) == 1 or not os.path.isfile(os.path.join(PROFILE_DIR, f[1]))
    if inline:
        auth = False
    proto = proto.lower()
    kind = 'TCP' if proto.startswith('tcp') else 'UDP'
    return remote, port or '1194', kind, auth


class Logins(object):
    """Saved user names/passwords per profile, only on this phone (~/.config, mode 600).
    The password is only base64-encoded, not encrypted."""

    def load(self):
        try:
            return json.loads(read_file(LOGINS, '{}') or '{}')
        except ValueError:
            return {}

    def save(self, data):
        d = os.path.dirname(LOGINS)
        if not os.path.isdir(d):
            os.makedirs(d, 0700)
        tmp = LOGINS + '.new'
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0600)
        os.write(fd, json.dumps(data))
        os.close(fd)
        os.rename(tmp, LOGINS)

    def get(self, name):
        e = self.load().get(name)
        if not e:
            return None, None
        try:
            return e.get('user', ''), base64.b64decode(e.get('pass', '')).decode('utf-8')
        except (TypeError, UnicodeDecodeError):
            return e.get('user', ''), u''

    def put(self, name, user, password):
        data = self.load()
        if not password and name in data and data[name].get('user') == user:
            return  # empty password field = keep the saved one
        data[name] = {'user': user, 'pass': base64.b64encode(password.encode('utf-8'))}
        self.save(data)

    def forget(self, name):
        data = self.load()
        if name in data:
            del data[name]
            self.save(data)


# OpenVPN 2.5 writes "2026-11-11 20:01:36", older versions "Wed Nov 11 20:01:36 2026"
LOG_TIME = re.compile(r'^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d|\w{3} \w{3} +\d+ \d\d:\d\d:\d\d \d{4}) (us=\d+ )?')
LINK = re.compile(r'(UDPv4|TCPv4_CLIENT|UDP|TCP)[^\n]*link remote: \[AF_INET\]([0-9.]+):(\d+)')
ADDR = re.compile(r'net_addr_v4_add: ([0-9.]+)/(\d+) dev tun')
ERROR_HINTS = ('AUTH_FAILED', 'Options error', 'Cannot resolve', 'RESOLVE: Cannot',
               'TLS Error', 'Exiting due to fatal error', 'Cannot open TUN', 'ERROR:')


def line_time(line):
    m = LOG_TIME.match(line)
    if not m:
        return 0
    t = re.sub(' +', ' ', m.group(1))
    for fmt in ('%Y-%m-%d %H:%M:%S', '%a %b %d %H:%M:%S %Y'):
        try:
            return int(time.mktime(time.strptime(t, fmt)))
        except ValueError:
            pass
    return 0


def strip_time(line):
    return LOG_TIME.sub('', line)


def short_time(line):
    """'2026-11-11 20:01:36 text' -> '20:01:36 text' (the log page is narrow)"""
    m = LOG_TIME.match(line)
    if not m:
        return line
    hms = re.search(r'\d\d:\d\d:\d\d', m.group(1))
    return (hms and hms.group(0) + ' ' or '') + line[m.end():]


class Vpn(QObject):
    # PySide 1.0.7 signal arguments cannot be read in QML: the signals only
    # say "something happened", QML then asks for the details.
    actionDone = Signal()
    busyChanged = Signal()

    def __init__(self):
        QObject.__init__(self)
        self.settings = QSettings('meevpn', 'meevpn')
        self.logins = Logins()
        self.proc = None
        self.out = ''
        self.code = 0
        self.lastAction = ''

    # ---- profiles ----
    def _profile_files(self):
        try:
            names = os.listdir(PROFILE_DIR)
        except OSError:
            return []
        out = []
        for n in sorted(names, key=lambda s: s.lower()):
            if n.lower().endswith('.ovpn') or n.lower().endswith('.conf'):
                out.append(n)
        return out

    @Slot(result=unicode)
    def profiles(self):
        items = []
        for n in self._profile_files():
            remote, port, kind, auth = parse_profile(os.path.join(PROFILE_DIR, n))
            user = self.logins.get(n)[0] if auth else None
            items.append({'file': n.decode('utf-8', 'replace'), 'name': os.path.splitext(n)[0].decode('utf-8', 'replace'),
                          'remote': remote, 'port': port, 'proto': kind, 'auth': auth,
                          'user': user or '', 'valid': bool(VALID_NAME.match(n))})
        return unicode(json.dumps(items))

    @Slot(result=unicode)
    def profileDir(self):
        return unicode(PROFILE_DIR)

    @Slot(result=bool)
    def makeProfileDir(self):
        try:
            if not os.path.isdir(PROFILE_DIR):
                os.makedirs(PROFILE_DIR)
            return True
        except OSError:
            return False

    @Slot(result=unicode)
    def selected(self):
        files = self._profile_files()
        cur = self.settings.value('profile', '')
        if isinstance(cur, unicode):
            cur = cur.encode('utf-8')
        cur = cur and str(cur) or ''
        if cur in files:
            return unicode(cur, 'utf-8', 'replace')
        return unicode(files[0], 'utf-8', 'replace') if files else u''

    @Slot(unicode)
    def select(self, name):
        self.settings.setValue('profile', name)

    @Slot(result=bool)
    def dns(self):
        return self.settings.value('dns', 'false') in ('true', True)

    @Slot(bool)
    def setDns(self, on):
        self.settings.setValue('dns', 'true' if on else 'false')

    @Slot(unicode, result=unicode)
    def loginUser(self, name):
        return self.logins.get(name.encode('utf-8'))[0] or u''

    @Slot(unicode, unicode, unicode)
    def saveLogin(self, name, user, password):
        self.logins.put(name.encode('utf-8'), user, password)

    @Slot(unicode)
    def forgetLogin(self, name):
        self.logins.forget(name.encode('utf-8'))

    # ---- state (no root needed) ----
    @Slot(result=unicode)
    def state(self):
        pid = read_file(PID_FILE).strip()
        alive = pid.isdigit() and os.path.isdir('/proc/' + pid)
        st = {}
        for l in read_file(STATE_FILE).splitlines():
            if '=' in l:
                k, v = l.split('=', 1)
                st[k] = v
        log = log_tail()
        r = {'state': 'off', 'profile': st.get('profile', '').decode('utf-8', 'replace'),
             'ip': '', 'server': '', 'proto': '', 'since': 0, 'rx': -1, 'tx': -1,
             'error': '', 'detail': '', 'installed': os.path.exists(OPENVPN),
             'busy': self.proc is not None, 'now': int(time.time())}
        lines = log.splitlines()
        # the part of the log after the last (re)connect attempt
        start = 0
        for i in range(len(lines) - 1, -1, -1):
            if 'process restarting' in lines[i] or ' OpenVPN 2.' in lines[i]:
                start = i
                break
        tail = lines[start:]
        if alive:
            ok = [l for l in tail if 'Initialization Sequence Completed' in l]
            r['state'] = 'on' if ok else 'connecting'
            if ok:
                r['since'] = line_time(ok[-1])
        else:
            # show an error only when OpenVPN ended by itself (not stopped by the user,
            # not still shutting down); warnings about pushed options are not errors
            stopped = [l for l in tail if 'SIGTERM[hard' in l or 'SIGINT[hard' in l]
            ended = [l for l in tail if 'process exiting' in l or 'Exiting due to fatal error' in l]
            if ended and not stopped:
                for l in reversed(tail):
                    if '[PUSH-OPTIONS]' in l:
                        continue
                    for h in ERROR_HINTS:
                        if h in l:
                            r['error'] = 'auth' if h == 'AUTH_FAILED' else strip_time(l)[:160]
                            break
                    if r['error']:
                        break
        if alive or r['state'] != 'off':
            text = u'\n'.join(tail)
            m = None
            for m in LINK.finditer(text):
                pass
            if m:
                r['server'] = m.group(2) + ':' + m.group(3)
                r['proto'] = 'TCP' if m.group(1).startswith('TCP') else 'UDP'
            a = None
            for a in ADDR.finditer(text):
                pass
            if a and r['state'] == 'on':
                r['ip'] = a.group(1)
            if tail:
                r['detail'] = strip_time(tail[-1])[:120]
        if r['state'] == 'on':
            rx = read_file(TUN_STATS + 'rx_bytes').strip()
            tx = read_file(TUN_STATS + 'tx_bytes').strip()
            if rx.isdigit():
                r['rx'] = int(rx)
            if tx.isdigit():
                r['tx'] = int(tx)
        return unicode(json.dumps(r))

    @Slot(result=unicode)
    def logText(self):
        lines = log_tail(24576).splitlines()[-250:]
        return u'\n'.join(short_time(l) for l in lines)

    @Slot()
    def copyLog(self):
        QApplication.clipboard().setText(log_tail(65536))

    # ---- actions (root helper) ----
    def _run(self, args, stdin=None):
        if self.proc is not None:
            return False
        self.out = ''
        proc = QProcess(self)
        proc.setProcessChannelMode(QProcess.MergedChannels)
        proc.finished.connect(self._done)
        proc.error.connect(self._error)
        self.proc = proc
        self.busyChanged.emit()
        proc.start(HELPER, args)
        if stdin is not None:
            proc.write(stdin)
        proc.closeWriteChannel()
        return True

    def _finish(self, code):
        proc, self.proc = self.proc, None
        if proc is not None:
            self.out += str(proc.readAll()).decode('utf-8', 'replace')
            proc.deleteLater()
        self.code = code
        print 'meevpn:', self.lastAction, code, self.out.strip()
        self.busyChanged.emit()
        self.actionDone.emit()

    def _done(self, code, status=None):
        if self.proc is None:
            return
        if self.proc.exitStatus() != QProcess.NormalExit:
            code = -1
        self._finish(code)

    def _error(self, err):
        if self.proc is not None and self.proc.state() == QProcess.NotRunning:
            self.out += u'cannot start ' + HELPER
            self._finish(-2)

    @Slot(unicode, result=unicode)
    def connectVpn(self, name):
        """'' = started, 'login' = profile needs a user name first, else an error key."""
        n = name.encode('utf-8')
        if not VALID_NAME.match(n):
            return u'badname'
        path = os.path.join(PROFILE_DIR, n)
        if not os.path.isfile(path):
            return u'noprofile'
        auth = parse_profile(path)[3]
        args = ['start', n]
        if self.dns():
            args.append('dns')
        stdin = None
        if auth:
            user, password = self.logins.get(n)
            if not user:
                return u'login'
            args.append('auth')
            stdin = (user + u'\n' + password + u'\n').encode('utf-8')
        self.lastAction = 'start'
        return u'' if self._run(args, stdin) else u'busy'

    @Slot(result=bool)
    def disconnectVpn(self):
        self.lastAction = 'stop'
        return self._run(['stop'])

    @Slot(result=bool)
    def isBusy(self):
        return self.proc is not None

    @Slot(result=int)
    def exitCode(self):
        return self.code

    @Slot(result=unicode)
    def output(self):
        return self.out.strip()

    @Slot(result=unicode)
    def action(self):
        return unicode(self.lastAction)


class Window(object):
    """Only one copy of the app; a second start brings the first to the front."""

    def __init__(self):
        self.view = None
        self.bus = None
        try:
            import dbus
            import dbus.service
            from dbus.mainloop.glib import DBusGMainLoop
        except ImportError, e:
            print 'meevpn: no D-Bus:', e
            return
        DBusGMainLoop(set_as_default=True)
        session_env()
        bus = dbus.SessionBus()
        if bus.request_name(BUS_NAME, dbus.bus.NAME_FLAG_DO_NOT_QUEUE) != dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER:
            self.bus = bus
            return
        owner = self

        class Service(dbus.service.Object):
            @dbus.service.method(BUS_NAME, in_signature='', out_signature='')
            def top(self):
                owner.top()

        self.service = Service(bus, '/')

    def running_elsewhere(self):
        if not self.bus:
            return False
        try:
            self.bus.get_object(BUS_NAME, '/').top(dbus_interface=BUS_NAME)
        except Exception, e:
            print 'meevpn: cannot reach the running copy:', e
        return True

    def top(self):
        if self.view:
            self.view.showFullScreen()
            self.view.raise_()
            self.view.activateWindow()


def main():
    os.environ.setdefault('DISPLAY', ':0')
    app = QApplication(sys.argv)
    app.setApplicationName('meevpn')
    app.setOrganizationName('meevpn')

    window = Window()
    if window.running_elsewhere():
        return

    view = QDeclarativeView()
    vpn = Vpn()
    ctx = view.rootContext()
    ctx.setContextProperty('uiLang', phone_language())
    ctx.setContextProperty('appVersion', APP_VERSION)
    ctx.setContextProperty('vpn', vpn)
    view.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    view.setSource(QUrl.fromLocalFile(os.path.join(APP_DIR, 'qml', 'main.qml')))
    view.showFullScreen()
    window.view = view
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()
