import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root
    // 为每个实例生成唯一ID，避免多显示器冲突
    property string instanceId: Math.random().toString(36).substring(2, 10)
    property string scriptPath: {
        var url = Qt.resolvedUrl("volumeAppInfo.py").toString()
        return url.replace("file://", "")
    }
    property string system_volume: "0"
    property bool is_muted: false
    property var app_Info: ({})
    property int totHeight: 200

    pillClickAction: {
        root.getSystemVolume()
        root.getAllAppInfo()
        console.log("[AppVolume] pill clicked")
    }

    Component.onCompleted: {
        root.getSystemVolume()
        root.getAllAppInfo()
    }

    // 使用较短的轮询间隔来模拟实时更新
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            root.getSystemVolume()
            root.getAllAppInfo()
        }
    }

    function getAllAppInfo() {
        Proc.runCommand("getAppVolumes_" + instanceId, ["python3", scriptPath], (out, code) => {
            if (code === 0 && out.trim()) {
                try {
                    const obj = JSON.parse(out.trim())
                    root.app_Info = obj
                    const appCount = Object.keys(root.app_Info).length
                    root.totHeight = 100 + appCount * (40 + Theme.spacingM)
                    console.log("[AppVolume] apps updated, count:", appCount)
                } catch (e) {
                    console.warn("[AppVolume] JSON parse failed:", out, e)
                }
            }
        })
    }

    horizontalBarPill: Component {
        Rectangle{
            id: pill
            implicitWidth: pillRow.implicitWidth + Theme.spacingL
            Row {
                id: pillRow
                spacing: Theme.spacingXS
            }
            DankIcon {
                // if is_mute is false, volume up, else volume off
                name: root.is_muted ? "volume_off" : "volume_up"
                color: Theme.primary
                size: Theme.barIconSize(barThickness)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Rectangle{
            id: pill
            implicitWidth: pillColumn.implicitWidth + Theme.spacingL
            implicitHeight: pillColumn.implicitHeight + Theme.spacingL
            color: "transparent"
            Column {
                id: pillColumn
                spacing: Theme.spacingXS
            }
            DankIcon {
                // if is_mute is false, volume up, else volume off
                name: root.is_muted ? "volume_off" : "volume_up"
                color: Theme.primary
                size: Theme.barIconSize(barThickness)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- 点击后弹出的框 ----
    popoutContent: Component {
        id: popoutContent
        PopoutComponent {
            headerText: "音量控制"
            showCloseButton: true
            // height: 400
            Column {
                id: contentColumn
                width: parent.width
                height: contentColumn.implicitHeight
                spacing: Theme.spacingM
                Column {
                    id: systemContent
                    width: parent.width
                    height: systemVolumeSlider.implicitHeight + Theme.spacingM * 2
                    spacing: Theme.spacingM
                    padding: Theme.spacingM
                    Rectangle {
                        implicitWidth: systemVolumeIcon.implicitWidth
                        implicitHeight: Theme.iconSize
                        // 透明颜色
                        color: "transparent"
                        DankIcon {
                            id: systemVolumeIcon
                            name: root.is_muted ? "volume_off" : "volume_up"
                            color: Theme.primary
                            size: Theme.barIconSize(barThickness) * 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // mute or unmute the system volume
                                if (root.is_muted === true){
                                    Proc.runCommand("toggleMute_" + root.instanceId, ["sh", "-c", `wpctl set-mute @DEFAULT_AUDIO_SINK@ 0`])
                                    root.is_muted = false
                                } else {
                                    Proc.runCommand("toggleUnmute_" + root.instanceId, ["sh", "-c", `wpctl set-mute @DEFAULT_AUDIO_SINK@ 1`])
                                    root.is_muted = true
                                }
                            }
                        }
                    }
                    DankSlider {
                        id: systemVolumeSlider
                        width: parent.width - Theme.iconSize - Theme.spacingL * 2
                        height: 40
                        x: Theme.spacingL + Theme.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        minimum: 0
                        maximum: 100
                        showValue: true
                        unit: "%"
                        thumbOutlineColor: Theme.surfaceContainer
                        valueOverride: parseFloat(root.system_volume)
                        value: parseFloat(root.system_volume)
                        alwaysShowValue: false
                        onSliderValueChanged: newValue => {
                            systemVolumeSlider.value = newValue
                            systemVolumeSlider.valueOverride = newValue
                            const cmd = `wpctl set-volume @DEFAULT_AUDIO_SINK@ ${newValue / 100.0}`
                            Proc.runCommand("setSystemVolume_" + root.instanceId, ["sh", "-c", cmd], (out, code) => {
                                if (code === 0) {
                                    console.log("[AppVolume] Set system volume to", newValue)
                                    root.system_volume = String(newValue)
                                } else {
                                    console.warn("[AppVolume] wpctl failed to set volume:", out)
                                }
                            })
                        }
                        Component.onCompleted: {
                            // 初始化时获取系统音量
                            root.getSystemVolume()
                        }
                    }
                }
                Repeater {
                    id: appContent
                    model: Object.keys(root.app_Info || {})
                    delegate: Column {
                        id: appDelegate
                        width: parent.width
                        required property string modelData
                        property var node: {
                            var info = root.app_Info
                            if (info && appDelegate.modelData && info.hasOwnProperty(appDelegate.modelData)) {
                                return info[appDelegate.modelData]
                            }
                            return ["0", 0, 0]
                        }
                        // 每个应用的图标 + 名字行
                        Row {
                            width: parent.width
                            height: Theme.iconSize
                            spacing: Theme.spacingM
                            DankIcon {
                                id: appVolumeIcon
                                name: (appDelegate.node[2] === 1) ? "volume_off" : "volume_up"
                                color: Theme.primary
                                size: Theme.barIconSize(barThickness) * 1.5
                                // anchors.verticalCenter: parent.verticalCenter
                                x: parent.x
                                y: parent.y + Theme.iconSize / 4
                            }

                            StyledText {
                                text: appDelegate.modelData
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                verticalAlignment: Text.AlignVCenter
                                x: Theme.iconSize + Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const n = appDelegate.node
                                    const isMuted = (n[2] === 0 ? false : true)
                                    const cmd = `wpctl set-mute ${n[0]} ${isMuted ? 0 : 1}`
                                    Proc.runCommand("toggleAppMute_" + root.instanceId, ["sh", "-c", cmd])
                                    console.log("[AppVolume] Toggled mute for", appDelegate.modelData, "to", !isMuted)
                                    // 立即更新图标状态
                                    appVolumeIcon.name = isMuted ? "volume_up" : "volume_off"
                                    // 更新节点状态
                                    appDelegate.node[2] = isMuted ? 0 : 1
                                }
                            }
                        }
                        // 滑动条
                        DankSlider {
                            id: appVolumeSlider
                            width: parent.width - Theme.spacingL * 2 - Theme.iconSize
                            height: 20
                            x: Theme.spacingL + Theme.iconSize
                            minimum: 0
                            maximum: 100
                            showValue: true
                            unit: "%"
                            thumbOutlineColor: Theme.surfaceContainer
                            value: appDelegate.node[1]
                            valueOverride: appDelegate.node[1]
                            alwaysShowValue: false
                            onSliderValueChanged: newValue => {
                                const cmd = `wpctl set-volume ${appDelegate.node[0]} ${newValue / 100.0}`
                                Proc.runCommand("setAppVolume_" + root.instanceId, ["sh", "-c", cmd])
                                console.log("[AppVolume] Executed wpctl command to set volume.", appDelegate.modelData, newValue)
                                appVolumeSlider.value = newValue
                                appVolumeSlider.valueOverride = newValue
                            }
                        }
                        

                    }
                }
            }
        
        }
    }
    function getSystemVolume() {
        const cmd = `wpctl get-volume @DEFAULT_AUDIO_SINK@`
        Proc.runCommand("getVolume_" + instanceId, ["sh", "-c", cmd], (out, code) => {
            if (code === 0) {
                let volString = out.replace(/[^\d.]/g, "");  // 移除非数字和非点号字符
                let vol = parseFloat(volString) * 100.0;
                root.system_volume = String(vol)
                root.is_muted = out.includes("MUTED")
                console.log("[AppVolume] System volume:", vol)
            } else {
                console.warn("[AppVolume] wpctl failed:", out)
            }
        })
    }

    popoutHeight: totHeight
}
