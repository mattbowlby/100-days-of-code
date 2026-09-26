import QtQuick
Item {
  property var model: []
  property Component delegate
  property var instances: []
  Component.onCompleted: {
    var out = []
    for (var i = 0; i < model.length; i++) out.push(delegate.createObject(this, { modelData: model[i] }))
    instances = out
  }
}
