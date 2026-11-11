/* meevpn-root - root helper of the MeeVPN app (Nokia N9, Harmattan PR1.3).
 *
 * The package gives this one binary the Aegis credentials CAP::setuid and
 * CAP::setgid, so it can switch to root when the app (user) starts it.
 * It then runs ONLY the MeeVPN engine, /opt/meevpn-n9/engine.sh, and ONLY
 * with the engine's own commands:
 *     start <profile.ovpn> [dns] [auth]     (profile = file name in MyDocs/openvpn)
 *     stop | version
 * Anything else is refused. The engine starts with a fixed, clean environment
 * (no LD_PRELOAD, no PATH tricks from the caller), in "/", with umask 022.
 * With "auth" the engine reads the user name and password from stdin.
 *
 * No libc: raw ARM EABI syscalls, so the static binary runs on the N9 kernel
 * (2.6.32) whatever the build host's glibc is.
 * Designed and written by Claude (Anthropic) together with smyhu for Nokia N9. MIT licence. */

static long sc1(long n, long a) { register long r7 asm("r7") = n; register long r0 asm("r0") = a;
    asm volatile("svc 0" : "+r"(r0) : "r"(r7) : "memory"); return r0; }
static long sc3(long n, long a, long b, long c) { register long r7 asm("r7") = n; register long r0 asm("r0") = a;
    register long r1 asm("r1") = b; register long r2 asm("r2") = c;
    asm volatile("svc 0" : "+r"(r0) : "r"(r7), "r"(r1), "r"(r2) : "memory"); return r0; }
#define SYS_exit 1
#define SYS_write 4
#define SYS_execve 11
#define SYS_chdir 12
#define SYS_umask 60
#define SYS_setgroups32 206
#define SYS_setuid32 213
#define SYS_setgid32 214

#define ENGINE "/opt/meevpn-n9/engine.sh"

static int len(const char *s) { int n = 0; while (s[n]) n++; return n; }
static int eq(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *a == *b; }
static void err(const char *s) { sc3(SYS_write, 2, (long)s, len(s)); }
static void die(const char *s, int code) { err("meevpn-root: "); err(s); err("\n"); sc1(SYS_exit, code); }

/* profile file name: letters, digits, space . _ - + ( ), no '/', not hidden, ends with .ovpn */
static int valid_profile(const char *s) {
    int n = len(s);
    if (n < 6 || n > 80 || s[0] == '.' || s[0] == '-' || s[0] == ' ') return 0;
    for (int i = 0; i < n; i++) {
        char c = s[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
              c == '.' || c == '_' || c == '-' || c == ' ' || c == '+' || c == '(' || c == ')')) return 0;
    }
    return eq(s + n - 5, ".ovpn") || eq(s + n - 5, ".conf");
}

void cmain(long *sp) {
    int argc = (int)sp[0];
    char **argv = (char **)(sp + 1);
    if (argc < 2) die("usage: meevpn-root start <profile.ovpn> [dns] [auth] | stop | version", 64);

    const char *cmd = argv[1];
    if (eq(cmd, "stop") || eq(cmd, "version")) {
        if (argc != 2) die("this command takes no arguments", 64);
    } else if (eq(cmd, "start")) {
        if (argc < 3 || argc > 5) die("start <profile.ovpn> [dns] [auth]", 64);
        if (!valid_profile(argv[2])) die("invalid profile file name", 64);
        for (int i = 3; i < argc; i++)
            if (!eq(argv[i], "dns") && !eq(argv[i], "auth")) die("unknown start option", 64);
    } else {
        die("command not allowed", 64);
    }

    long g = 0;
    if (sc3(SYS_setgroups32, 1, (long)&g, 0) != 0 || sc1(SYS_setgid32, 0) != 0 || sc1(SYS_setuid32, 0) != 0)
        die("cannot switch to root (Aegis credentials missing - reinstall meevpn-n9 with aegis-dpkg)", 77);
    sc1(SYS_umask, 022);
    sc1(SYS_chdir, (long)"/");

    char *nargv[8];
    int k = 0;
    nargv[k++] = "/bin/sh";
    nargv[k++] = ENGINE;
    for (int i = 1; i < argc; i++) nargv[k++] = argv[i];
    nargv[k] = 0;
    char *envp[] = { "PATH=/usr/sbin:/usr/bin:/sbin:/bin", "HOME=/root", "USER=root",
                     "LOGNAME=root", "SHELL=/bin/sh", "TERM=dumb", "MEEVPN_APP=1", 0 };
    sc3(SYS_execve, (long)nargv[0], (long)nargv, (long)envp);
    die("cannot start the engine", 126);
}
asm(".text\n.global _start\n_start:\n mov r0, sp\n bl cmain\n");
