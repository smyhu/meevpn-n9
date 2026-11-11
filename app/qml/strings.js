.pragma library
// UI texts (pl, en). The language comes from the phone setting (uiLang, main.py).
// A missing entry falls back to English.

var texts = {
    "off":          { "pl": "Rozłączono", "en": "Disconnected" },
    "connecting":   { "pl": "Łączenie…", "en": "Connecting…" },
    "on":           { "pl": "Połączono", "en": "Connected" },
    "stopping":     { "pl": "Rozłączanie…", "en": "Disconnecting…" },
    "connect":      { "pl": "POŁĄCZ", "en": "CONNECT" },
    "disconnect":   { "pl": "ROZŁĄCZ", "en": "DISCONNECT" },
    "cancel":       { "pl": "PRZERWIJ", "en": "CANCEL" },
    "profile":      { "pl": "Profil", "en": "Profile" },
    "address":      { "pl": "Adres VPN", "en": "VPN address" },
    "server":       { "pl": "Serwer", "en": "Server" },
    "time":         { "pl": "Czas", "en": "Time" },
    "traffic":      { "pl": "Przesłano", "en": "Traffic" },
    "noProfile":    { "pl": "brak – dodaj plik .ovpn", "en": "none – add an .ovpn file" },
    "dns":          { "pl": "DNS z serwera VPN", "en": "DNS from the VPN server" },
    "dnsHint":      { "pl": "Działa od następnego połączenia", "en": "Applies from the next connection" },
    "profiles":     { "pl": "Profile", "en": "Profiles" },
    "log":          { "pl": "Dziennik", "en": "Log" },
    "about":        { "pl": "O programie", "en": "About" },
    "aboutText":    { "pl": "Klient OpenVPN dla Nokii N9. Profile .ovpn z folderu MyDocs/openvpn, logowanie nazwą i hasłem, dziennik połączenia. Silnik: OpenVPN 2.5 z pakietu openvpn-n9.",
                      "en": "OpenVPN client for the Nokia N9. .ovpn profiles from the MyDocs/openvpn folder, user name and password login, connection log. Engine: OpenVPN 2.5 from the openvpn-n9 package." },
    "credit":       { "pl": "Zaprojektowany i napisany przez Claude (Anthropic) wspólnie ze smyhu dla Nokii N9.",
                      "en": "Designed and written by Claude (Anthropic) together with smyhu for the Nokia N9." },
    "close":        { "pl": "Zamknij", "en": "Close" },
    "filesN":       { "pl": "MyDocs/openvpn · plików: %1", "en": "MyDocs/openvpn · files: %1" },
    "emptyHint":    { "pl": "Skopiuj plik .ovpn od dostawcy VPN do folderu openvpn w pamięci telefonu (MyDocs/openvpn), np. przez USB. Pojawi się tutaj.",
                      "en": "Copy the .ovpn file from your VPN provider to the openvpn folder in the phone memory (MyDocs/openvpn), e.g. over USB. It will show up here." },
    "badName":      { "pl": "Zmień nazwę pliku: tylko litery a–z, cyfry, spacja i . _ - + ( )",
                      "en": "Rename the file: only letters a–z, digits, space and . _ - + ( )" },
    "needsLogin":   { "pl": "wymaga nazwy i hasła", "en": "needs user name and password" },
    "loginAs":      { "pl": "login: %1", "en": "login: %1" },
    "editLogin":    { "pl": "Login", "en": "Login" },
    "loginTitle":   { "pl": "Logowanie: %1", "en": "Login: %1" },
    "user":         { "pl": "Nazwa użytkownika", "en": "User name" },
    "password":     { "pl": "Hasło", "en": "Password" },
    "loginHint":    { "pl": "Zapisane tylko w tym telefonie. Puste hasło = bez zmiany.",
                      "en": "Saved only on this phone. Empty password = keep the saved one." },
    "forget":       { "pl": "Usuń zapisany login", "en": "Forget saved login" },
    "save":         { "pl": "Zapisz", "en": "Save" },
    "back":         { "pl": "Wróć", "en": "Back" },
    "cancelBtn":    { "pl": "Anuluj", "en": "Cancel" },
    "copy":         { "pl": "Kopiuj", "en": "Copy" },
    "copied":       { "pl": "Dziennik skopiowany do schowka", "en": "Log copied to the clipboard" },
    "logEmpty":     { "pl": "Dziennik jest pusty", "en": "The log is empty" },
    "e_auth":       { "pl": "Serwer odrzucił nazwę lub hasło", "en": "The server rejected the user name or password" },
    "e_noopenvpn":  { "pl": "Brak pakietu openvpn-n9 – zainstaluj go (MeeRevive)", "en": "The openvpn-n9 package is missing – install it (MeeRevive)" },
    "e_helper":     { "pl": "Nie udało się uruchomić VPN (kod %1)", "en": "Could not start the VPN (code %1)" },
    "e_badname":    { "pl": "Nazwa pliku profilu ma niedozwolone znaki", "en": "The profile file name has characters that are not allowed" },
    "e_noprofile":  { "pl": "Nie znaleziono pliku profilu", "en": "Profile file not found" }
};

function t(lang, key) {
    var e = texts[key];
    if (!e) return key;
    return e[lang] !== undefined ? e[lang] : (e["en"] !== undefined ? e["en"] : key);
}

function a(lang, key, arg) { return t(lang, key).replace("%1", arg); }

function bytes(n) {
    if (n < 0) return "—";
    if (n < 1024) return n + " B";
    if (n < 1048576) return (n / 1024).toFixed(0) + " kB";
    if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB";
    return (n / 1073741824).toFixed(2) + " GB";
}

function duration(s) {
    if (s < 0) s = 0;
    var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, x = s % 60;
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":" + (x < 10 ? "0" : "") + x;
}
