import QtQuick
QtObject { property var command; property bool running; property var stdout; property var stderr; property var environment; signal exited(int code, int status) }
