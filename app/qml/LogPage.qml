import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.1
import "strings.js" as S

// OpenVPN log (/var/log/openvpn-n9.log), refreshed every 2 s.
Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    function tr(k) { return S.t(uiLang, k) }

    function reload() {
        var atEnd = flick.contentY >= flick.contentHeight - flick.height - 40;
        var t = vpn.logText();
        logLabel.text = t != "" ? t : tr("logEmpty");
        if (atEnd) flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }

    Timer {
        interval: 2000
        running: Qt.application.active && page.status == PageStatus.Active
        repeat: true
        onTriggered: page.reload()
    }
    Component.onCompleted: {
        reload();
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }

    Image { source: "background.png"; y: -36; smooth: false }
    Header {
        id: header
        text: tr("log")
        subText: "/var/log/openvpn-n9.log"
    }

    Flickable {
        id: flick
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        contentHeight: logLabel.height
        clip: true
        Text {
            id: logLabel
            width: flick.width
            wrapMode: Text.WrapAnywhere
            font.family: "Monospace"
            font.pixelSize: 16
            color: "#c8c8c8"
            textFormat: Text.PlainText
        }
    }
    ScrollDecorator { flickableItem: flick }
    InfoBanner { id: banner; y: 8 }

    tools: ToolBarLayout {
        ToolIcon { platformIconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolButton {
            text: page.tr("copy")
            onClicked: { vpn.copyLog(); banner.text = page.tr("copied"); banner.show(); }
        }
    }
}
