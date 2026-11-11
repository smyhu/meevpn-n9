import QtQuick 1.1
import com.nokia.meego 1.0

// "label   value" row of the status block
Item {
    property alias label: l.text
    property alias value: v.text
    property alias valueColor: v.color
    width: parent.width
    height: 44
    Label {
        id: l
        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
        width: 168
        font.pixelSize: 20
        color: "#8C8C8C"
    }
    Label {
        id: v
        anchors { left: l.right; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        font.pixelSize: 24
        color: "white"
        elide: Text.ElideRight
    }
}
