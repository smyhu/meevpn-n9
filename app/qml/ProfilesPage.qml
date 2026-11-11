import QtQuick 1.1
import com.nokia.meego 1.0
import "strings.js" as S

// .ovpn files in MyDocs/openvpn; tap = use this profile.
Page {
    id: page
    orientationLock: PageOrientation.LockPortrait
    property string current: ""

    function tr(k) { return S.t(uiLang, k) }

    function reload() {
        vpn.makeProfileDir();
        page.current = vpn.selected();
        profiles.clear();
        var items = JSON.parse(vpn.profiles());
        for (var i = 0; i < items.length; i++) profiles.append(items[i]);
    }

    Component.onCompleted: reload()

    Image { source: "background.png"; y: -36; smooth: false }
    Header {
        id: header
        text: tr("profiles")
        subText: S.a(uiLang, "filesN", profiles.count)
    }
    ListModel { id: profiles }

    ListView {
        id: list
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: profiles
        delegate: Item {
            width: list.width
            height: 112
            Rectangle { anchors.fill: parent; color: "white"; opacity: rowMouse.pressed ? 0.12 : 0 }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                enabled: model.valid
                onClicked: {
                    vpn.select(model.file);
                    pageStack.pop();
                }
            }
            Column {
                anchors { left: parent.left; leftMargin: 16; right: loginButton.visible ? loginButton.left : mark.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                Label {
                    width: parent.width
                    text: model.name
                    font.pixelSize: 26
                    font.bold: true
                    color: model.file == page.current ? "#cfeca0" : "white"
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: !model.valid ? page.tr("badName")
                          : (model.remote != "" ? model.remote + " · " + model.proto + " " + model.port : "")
                    font.pixelSize: 18
                    color: !model.valid ? "#ff7a6a" : "#8C8C8C"
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    visible: model.auth && model.valid
                    text: model.user != "" ? S.a(uiLang, "loginAs", model.user) : page.tr("needsLogin")
                    font.pixelSize: 18
                    color: model.user != "" ? "#8C8C8C" : "#cfeca0"
                    elide: Text.ElideRight
                }
            }
            Button {
                id: loginButton
                anchors { right: mark.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 110
                visible: model.auth && model.valid
                text: page.tr("editLogin")
                onClicked: login.openFor(model.file, model.name)
            }
            Image {
                id: mark
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                width: 32; height: 32
                source: "check.png"
                visible: model.file == page.current
            }
        }
    }

    Label {
        anchors { top: header.bottom; left: parent.left; right: parent.right; margins: 24; topMargin: 40 }
        visible: profiles.count == 0
        text: tr("emptyHint")
        font.pixelSize: 22
        color: "#8C8C8C"
        wrapMode: Text.WordWrap
    }

    LoginSheet {
        id: login
        onSaved: page.reload()
        onForgotten: page.reload()
    }

    tools: ToolBarLayout {
        ToolIcon { platformIconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolIcon { platformIconId: "toolbar-refresh"; onClicked: page.reload() }
    }
}
