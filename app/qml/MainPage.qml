import QtQuick 1.1
import com.nokia.meego 1.0
import "strings.js" as S

// Main view: big connect button, connection details, DNS switch.
Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property string vpnState: "off"      // off | connecting | on
    property bool pending: false          // helper (start/stop) still running
    property string profile: ""
    property string profileLabel: ""
    property variant info: ({})
    property string errorText: ""

    function tr(k) { return S.t(uiLang, k) }

    function loadProfile() {
        page.profile = vpn.selected();
        page.profileLabel = page.profile == "" ? "" : page.profile.replace(/\.(ovpn|conf)$/, "");
    }

    function refresh() {
        var r = JSON.parse(vpn.state());
        page.info = r;
        page.vpnState = r.state;
        if (r.state != "off" && r.profile != "" && r.profile != page.profile) {
            page.profile = r.profile;
            page.profileLabel = r.profile.replace(/\.(ovpn|conf)$/, "");
        }
        if (!r.installed) page.errorText = tr("e_noopenvpn");
        else if (r.error == "auth") page.errorText = tr("e_auth");
        else page.errorText = r.state == "off" ? r.error : "";
    }

    function toggle() {
        if (page.pending) return;
        if (page.vpnState != "off") {
            if (vpn.disconnectVpn()) page.pending = true;
            return;
        }
        if (page.profile == "") {
            pageStack.push(Qt.resolvedUrl("ProfilesPage.qml"));
            return;
        }
        var res = vpn.connectVpn(page.profile);
        if (res == "") { page.pending = true; page.errorText = ""; }
        else if (res == "login") login.openFor(page.profile, page.profileLabel);
        else if (res != "busy") appWindow.showBanner(tr("e_" + res));
    }

    Connections {
        target: vpn
        onActionDone: {
            page.pending = false;
            var code = vpn.exitCode();
            if (code != 0) {
                var out = vpn.output();
                if (out.indexOf("no-openvpn") >= 0) appWindow.showBanner(tr("e_noopenvpn"));
                else appWindow.showBanner(S.a(uiLang, "e_helper", code) + (out != "" ? "\n" + out.split("\n").pop() : ""));
            }
            page.refresh();
        }
    }

    Timer {
        interval: page.vpnState == "on" ? 2000 : 1000
        running: Qt.application.active && page.status == PageStatus.Active
        repeat: true
        triggeredOnStart: true
        onTriggered: page.refresh()
    }

    onStatusChanged: if (status == PageStatus.Active) { loadProfile(); refresh(); }

    // radial gradient, prepared in RGB565 with dithering (as in AuthMee/Lyrion)
    Image { source: "background.png"; y: -36; smooth: false }

    Header {
        id: header
        text: "MeeVPN"
        subText: page.pending ? (page.vpnState == "off" ? tr("connecting") : tr("stopping"))
                 : page.vpnState == "on" ? tr("on") + " · " + S.duration(page.info.since > 0 ? page.info.now - page.info.since : 0)
                 : tr(page.vpnState)
    }

    // the big button
    Item {
        id: button
        width: 300; height: 300
        anchors { horizontalCenter: parent.horizontalCenter; top: header.bottom; topMargin: 14 }

        Image { anchors.fill: parent; source: "ring-off.png"; smooth: true }
        Image {
            id: onRing
            anchors.fill: parent
            source: "ring-on.png"
            smooth: true
            opacity: page.vpnState == "on" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        // pulsing while connecting
        SequentialAnimation {
            running: page.vpnState == "connecting" || (page.pending && page.vpnState == "off")
            loops: Animation.Infinite
            NumberAnimation { target: onRing; property: "opacity"; to: 0.75; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { target: onRing; property: "opacity"; to: 0.1; duration: 700; easing.type: Easing.InOutQuad }
            onRunningChanged: if (!running) onRing.opacity = page.vpnState == "on" ? 1 : 0
        }
        Image {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -18 }
            source: page.vpnState == "on" ? "lock-on.png" : "lock-off.png"
            smooth: true
            scale: mouse.pressed ? 0.94 : 1
        }
        Label {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 66 }
            text: page.vpnState == "on" ? tr("disconnect") : (page.vpnState == "connecting" ? tr("cancel") : tr("connect"))
            font.pixelSize: 22
            font.bold: true
            color: page.vpnState == "on" ? "#cfeca0" : "#7f9f62"
        }
        MouseArea {
            id: mouse
            anchors.centerIn: parent
            width: 240; height: 240
            onClicked: page.toggle()
        }
    }

    Label {
        id: errorLabel
        anchors { top: button.bottom; left: parent.left; right: parent.right; margins: 16; topMargin: -8 }
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        font.pixelSize: 20
        color: "#ff7a6a"
        text: page.errorText
        visible: text != ""
    }

    Column {
        id: rows
        anchors { top: errorLabel.visible ? errorLabel.bottom : button.bottom; topMargin: errorLabel.visible ? 8 : -4; left: parent.left; right: parent.right }

        Item {
            width: parent.width
            height: 44
            InfoRow {
                label: tr("profile")
                value: page.profileLabel != "" ? page.profileLabel + "  ›" : tr("noProfile")
                valueColor: page.profileLabel != "" ? "white" : "#cfeca0"
            }
            Rectangle { anchors.fill: parent; color: "white"; opacity: pmouse.pressed ? 0.12 : 0 }
            MouseArea {
                id: pmouse
                anchors.fill: parent
                enabled: page.vpnState == "off" && !page.pending
                onClicked: pageStack.push(Qt.resolvedUrl("ProfilesPage.qml"))
            }
        }
        InfoRow { label: tr("address"); value: page.info.ip ? page.info.ip : "—" }
        InfoRow { label: tr("server"); value: page.info.server ? page.info.server + " · " + page.info.proto : "—" }
        InfoRow {
            label: tr("traffic")
            value: page.vpnState == "on" && page.info.rx >= 0 ? "↓ " + S.bytes(page.info.rx) + "   ↑ " + S.bytes(page.info.tx) : "—"
        }
        Item {
            width: parent.width
            height: page.vpnState == "connecting" && page.info.detail ? 34 : 0
            clip: true
            Label {
                anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: page.info.detail ? page.info.detail : ""
                font.pixelSize: 16
                color: "#8C8C8C"
                elide: Text.ElideRight
            }
        }
        Rectangle { x: 16; width: parent.width - 32; height: 1; color: "#333333" }
        Item {
            width: parent.width
            height: 84
            Column {
                anchors { left: parent.left; leftMargin: 16; right: dnsSwitch.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                Label { text: tr("dns"); font.pixelSize: 24; width: parent.width; elide: Text.ElideRight }
                Label { text: tr("dnsHint"); font.pixelSize: 18; color: "#8C8C8C"; width: parent.width; elide: Text.ElideRight }
            }
            Switch {
                id: dnsSwitch
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                Component.onCompleted: checked = vpn.dns()
                onCheckedChanged: vpn.setDns(checked)
            }
        }
    }

    LoginSheet {
        id: login
        onSaved: page.toggle()
    }

    QueryDialog {
        id: aboutDialog
        icon: "file:///usr/share/icons/hicolor/80x80/apps/meevpn-n9.png"
        titleText: "MeeVPN " + appVersion
        message: tr("aboutText") + "<br><br>" + tr("credit") +
                 "<br><br>MIT · <a href=\"https://github.com/smyhu/meevpn-n9\" style=\"color:#4DA6FF; text-decoration:underline\">github.com/smyhu/meevpn-n9</a>"
        acceptButtonText: tr("close")
        onLinkActivated: Qt.openUrlExternally(link)
    }

    Menu {
        id: mainMenu
        MenuLayout {
            MenuItem { text: tr("about"); onClicked: aboutDialog.open() }
        }
    }

    tools: ToolBarLayout {
        ToolButton {
            text: tr("profiles")
            enabled: page.vpnState == "off" && !page.pending
            onClicked: pageStack.push(Qt.resolvedUrl("ProfilesPage.qml"))
        }
        ToolButton {
            text: tr("log")
            onClicked: pageStack.push(Qt.resolvedUrl("LogPage.qml"))
        }
        ToolIcon {
            platformIconId: "toolbar-view-menu"
            onClicked: (mainMenu.status == DialogStatus.Closed) ? mainMenu.open() : mainMenu.close()
        }
    }
}
