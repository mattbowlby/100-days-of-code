import QtQuick
// Qt older than 6.5 has no MultiEffect; the preview draws without the effect.
Item { property bool maskEnabled; property var maskSource; property real maskThresholdMin; property real maskSpreadAtMin; property var source }
