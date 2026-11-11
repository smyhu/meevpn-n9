import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.1

PageStackWindow {
    id: appWindow
    showStatusBar: true
    initialPage: MainPage { }

    property color accent: "#cfeca0"
    property color tintBorder: "#5f7f45"
    property color red: "#ff7a6a"
    property color dim: "#8C8C8C"

    function showBanner(text) {
        banner.text = text;
        banner.show();
    }

    InfoBanner { id: banner; y: 36 + 8 }

    // black UI: on the AMOLED screen black pixels are switched off
    Component.onCompleted: theme.inverted = true
}
