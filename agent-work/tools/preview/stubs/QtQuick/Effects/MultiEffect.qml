import QtQuick
// Qt older than 6.5 has no MultiEffect. A ShaderEffect with its default shaders
// would draw its source unmasked, but the harness's software backend draws no
// shader effects at all, so the layer behind this comes out blank.
ShaderEffect { property var source; property bool maskEnabled; property var maskSource; property real maskThresholdMin; property real maskSpreadAtMin }
