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
    property alias cfg_iconSize: iconSizeSpinbox.value
    property alias cfg_enableGlassyBorders: glassyCheckbox.checked
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
