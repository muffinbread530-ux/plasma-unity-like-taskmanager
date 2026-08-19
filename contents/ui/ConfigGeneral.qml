import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias cfg_invertFoldDirection: invertFoldCheckbox.checked
    property alias cfg_disableFolding: disableFoldingCheckbox.checked
    property alias cfg_enableHoverPop: hoverPopCheckbox.checked
    property alias cfg_hoverScrollSpeed: hoverScrollSpinbox.value
    property alias cfg_maxTileSize: maxTileSizeSpinbox.value
    property alias cfg_iconSize: iconSizeSpinbox.value
    property alias cfg_enableGlassyBorders: glassyCheckbox.checked
    property alias cfg_glassySize: glassySizeSpinbox.value
    property alias cfg_glassyBorderMargin: borderMarginSpinbox.value
    property alias cfg_useDominantColor: domColorCheckbox.checked
    property alias cfg_indicatorStyle: indicatorStyleCombobox.currentIndex

    implicitWidth: formLayout.implicitWidth
    implicitHeight: formLayout.implicitHeight

    Kirigami.FormLayout {
        id: formLayout
        anchors.left: parent.left
        anchors.right: parent.right

        Controls.CheckBox {
            id: invertFoldCheckbox
            Kirigami.FormData.label: "Behavior:"
            text: "Invert Icon Scroll Direction"
        }

        Controls.CheckBox {
            id: disableFoldingCheckbox
            text: "Disable 3D Folding (Use Flat Scrolling)"
        }

        Controls.CheckBox {
            id: hoverPopCheckbox
            text: "Enable Hover Pop Animation"
        }

        Controls.SpinBox {
            id: hoverScrollSpinbox
            Kirigami.FormData.label: "Hover Scroll Speed:"
            from: 1
            to: 50
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        Controls.SpinBox {
            id: maxTileSizeSpinbox
            Kirigami.FormData.label: "Max Tile Size:"
            textFromValue: function(value, locale) { return value + " px"; }
            from: 24
            to: 256
            value: 64
        }

        Controls.SpinBox {
            id: iconSizeSpinbox
            Kirigami.FormData.label: "Icon Size:"
            textFromValue: function(value, locale) { return value + " %"; }
            from: 10
            to: 100
        }

        Controls.CheckBox {
            id: glassyCheckbox
            text: "Enable Glassy Borders"
        }

        Controls.SpinBox {
            id: glassySizeSpinbox
            Kirigami.FormData.label: "Glassy Border Size:"
            textFromValue: function(value, locale) { return value + " %"; }
            from: 10
            to: 100
            // 100% is the persistent default instead of the SpinBox minimum (10%).
            value: 100
            enabled: glassyCheckbox.checked
        }

        Controls.SpinBox {
            id: borderMarginSpinbox
            Kirigami.FormData.label: "Spacing Between Borders:"
            from: 0
            to: 50
            // Stored in tenths of a pixel: 5 = 0.5 px.
            value: 5
            enabled: glassyCheckbox.checked
            textFromValue: function(value, locale) { return (value / 10).toFixed(1) + " px"; }
            valueFromText: function(text, locale) { return Math.round(parseFloat(text) * 10); }
        }

        Controls.CheckBox {
            id: domColorCheckbox
            text: "Use Dominant Icon Color for Indicators"
        }

        Controls.ComboBox {
            id: indicatorStyleCombobox
            Kirigami.FormData.label: "Indicator Style:"
            model: [
                "0: Dot (Bottom/Left)",
                "1: Pill (Bottom/Left)",
                "2: Line (Bottom/Left)",
                "3: Diamond (Bottom/Left)",
                "4: Wide Line (Bottom/Left)",
                "5: Square (Bottom/Left)",
                "6: Top Dot (Top/Right)",
                "7: Top Line (Top/Right)"
            ]
        }
    }
}
