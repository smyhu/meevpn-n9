import QtQuick 1.1
import com.nokia.meego 1.0
import "strings.js" as S

// User name + password for a profile with auth-user-pass (saved on the phone only).
Sheet {
    id: sheet
    property string profile: ""
    property string profileName: ""
    property bool hasSaved: false
    signal saved()
    signal forgotten()

    acceptButtonText: S.t(uiLang, "save")
    rejectButtonText: S.t(uiLang, "cancelBtn")

    function openFor(file, name) {
        profile = file;
        profileName = name;
        userField.text = vpn.loginUser(file);
        passField.text = "";
        hasSaved = userField.text != "";
        open();
    }

    content: Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: col.height
        clip: true
        Column {
            id: col
            width: parent.width
            spacing: 10
            Label {
                width: parent.width
                text: S.a(uiLang, "loginTitle", sheet.profileName)
                font.pixelSize: 28
                wrapMode: Text.WordWrap
            }
            Item { width: 1; height: 6 }
            Label { text: S.t(uiLang, "user"); font.pixelSize: 20; color: "#8C8C8C" }
            TextField {
                id: userField
                width: parent.width
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }
            Label { text: S.t(uiLang, "password"); font.pixelSize: 20; color: "#8C8C8C" }
            TextField {
                id: passField
                width: parent.width
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
            }
            Label {
                width: parent.width
                text: S.t(uiLang, "loginHint")
                font.pixelSize: 18
                color: "#8C8C8C"
                wrapMode: Text.WordWrap
            }
            Item { width: 1; height: 10 }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: S.t(uiLang, "forget")
                visible: sheet.hasSaved
                onClicked: {
                    vpn.forgetLogin(sheet.profile);
                    sheet.forgotten();
                    sheet.reject();
                }
            }
        }
    }

    onAccepted: {
        if (userField.text == "") return;
        vpn.saveLogin(profile, userField.text, passField.text);
        saved();
    }
}
