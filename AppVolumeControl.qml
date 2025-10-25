import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root
    property string system_volume: "0"
    property bool is_muted: false
    property var app_Info: {}
    property var totHeight: 200
    pillClickAction: {
        root.getSystemVolume()
        root.getAllAppInfo()
        console.log("[AppVolume] pill clicked")
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
                font.pixelSize: Theme.iconSize - 6
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Rectangle{
            id: pill
            implicitWidth: pillColumn.implicitWidth + Theme.spacingL
            Column {
                id: pillColumn
                spacing: Theme.spacingXS
            }
            DankIcon {
                // if is_mute is false, volume up, else volume off
                name: root.is_muted ? "volume_off" : "volume_up"
                color: Theme.primary
                font.pixelSize: Theme.iconSize - 6
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
                            font.pixelSize: Theme.iconSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // mute or unmute the system volume
                                if (root.is_muted === true){
                                    Proc.runCommand("toggleMute", ["sh", "-c", `wpctl set-mute @DEFAULT_AUDIO_SINK@ 0`])
                                    root.is_muted = false
                                } else {
                                    Proc.runCommand("toggleUnmute", ["sh", "-c", `wpctl set-mute @DEFAULT_AUDIO_SINK@ 1`])
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
                            const cmd = `wpctl set-volume @DEFAULT_AUDIO_SINK@ ${newValue / 100.0}`
                            Proc.runCommand("setVolume", ["sh", "-c", cmd], (out, code) => {
                                if (code === 0) {
                                    console.log("[AppVolume] Set system volume to", newValue)
                                    root.system_volume = String(newValue)
                                } else {
                                    console.warn("[AppVolume] wpctl failed to set volume:", out)
                                }
                            })
                        }
                        Component.onCompleted: {
                            root.getSystemVolume()
                            root.getAllAppInfo()
                        }
                    }
                }
                Repeater {
                    id: appContent
                    model: Object.keys(root.app_Info)
                    delegate: Column {
                        width: parent.width
                        // padding: Theme.spacingM
                        // 每个应用的图标 + 名字行
                        Row {
                            width: parent.width
                            height: Theme.iconSize
                            spacing: Theme.spacingM
                            DankIcon {
                                id: appVolumeIcon
                                name: (root.app_Info[modelData][2] === 1) ? "volume_off" : "volume_up"
                                color: Theme.primary
                                font.pixelSize: Theme.iconSize
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData
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
                                    const node = root.app_Info[modelData]
                                    const isMuted = (node[2] === 0 ? false : true)
                                    const cmd = `wpctl set-mute ${node[0]} ${isMuted ? 0 : 1}`
                                    Proc.runCommand("toggleMute", ["sh", "-c", cmd])
                                    root.app_Info[modelData][2] = !isMuted
                                    appVolumeIcon.name = isMuted ? "volume_up" : "volume_off"
                                    console.log("[AppVolume] Toggled mute for", modelData, "to", !isMuted)
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
                            value: root.app_Info[modelData][1]
                            valueOverride: root.app_Info[modelData][1]
                            alwaysShowValue: false
                            onSliderValueChanged: newValue => {
                                const cmd = `wpctl set-volume ${root.app_Info[modelData][0]} ${newValue / 100.0}`
                                Proc.runCommand("setVolume", ["sh", "-c", cmd])
                                root.app_Info[modelData][1] = newValue
                                appVolumeSlider.value = newValue
                                appVolumeSlider.valueOverride = newValue
                                console.log("[AppVolume] Executed wpctl command to set volume.", modelData, newValue)
                            }
                        }
                    }
                }
            }
        
        }
    }
    function setVolume(appID, volume) {
        const cmd = "wpctl set-volume " + appID + " " + (volume)
        Proc.runCommand("setAppVolume", ["sh", "-c", cmd], (out, code) => {
            if (code === 0) {
                console.log("[AppVolume] Set volume of", appID, "to", volume)
            } else {
                console.warn("[AppVolume] wpctl failed to set app volume:", out)
            }
        })
    }

    function getSystemVolume() {
        const cmd = `wpctl get-volume @DEFAULT_AUDIO_SINK@`
        console.log("[AppVolume] Getting system volume...")
        Proc.runCommand("getVolume", ["sh", "-c", cmd], (out, code) => {
            if (code === 0) {
                let volString = out.replace(/[^\d.]/g, "");  // 移除非数字和非点号字符
                let vol = parseFloat(volString) * 100.0;
                // volumeSlider.value = vol
                root.system_volume = String(vol)
                console.log("[AppVolume] System volume:", vol)
            } else {
                console.warn("[AppVolume] wpctl failed:", out)
            }
        })
        console.log("[AppVolume] Executed wpctl command to get volume.")
    }

    function getAllAppInfo() {
        console.log("[AppVolume] getting apps volumes")
        Proc.runCommand("getAppVolumes", ["python3", `./volumeAppInfo.py`], (out, code) => {
            // app_Info update
            if (code === 0) {
                root.app_Info = JSON.parse(out)
                console.log("[AppVolume] Retrieved app volumes", Object.keys(root.app_Info), root.totHeight, Object.keys(root.app_Info).length, 40+Theme.spacingM * 2)
                root.totHeight = 40+Theme.spacingM * 2 + Object.keys(root.app_Info).length * (20 + 1.0*Theme.spacingM + Theme.iconSize) + Theme.spacingM * 2
            }
            else {
                console.warn("[AppVolume] Failed to get app volumes:", out, code)
            }
        })
    }
    popoutHeight: totHeight
}