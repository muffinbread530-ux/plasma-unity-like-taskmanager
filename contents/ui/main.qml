import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import QtQml
import QtQml.Models

PlasmoidItem {
    id: root
    readonly property bool isHorizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.minimumWidth: isHorizontal ? 140 : 32
    Layout.minimumHeight: isHorizontal ? 32 : 140
    preferredRepresentation: fullRepresentation
    TaskManager.TasksModel {
        id: tasksModel
        filterByScreen: true
        filterByVirtualDesktop: false
        filterByActivity: true
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        property bool internalSync: false

        Component.onCompleted: {
            launcherList = plasmoid.configuration.launchers;
        }

        onLauncherListChanged: {
            if (internalSync) return;
            internalSync = true;
            plasmoid.configuration.launchers = launcherList;
            internalSync = false;
        }
    }

    // full representation
    fullRepresentation: Item {
        id: dockContainer
        anchors.fill: parent

        // configuration options
        readonly property bool foldingDisabled: plasmoid.configuration.disableFolding ?? false
        readonly property bool invertFold: plasmoid.configuration.invertFoldDirection ?? false
        readonly property bool enableHoverPop: plasmoid.configuration.enableHoverPop ?? true

        // scroll state
        property real scrollOffset: 0
        Behavior on scrollOffset {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutQuad
            }
        }

        property real targetScrollOffset: 0
        property int draggingIndex: -1
        property int dropTargetIndex: -1
        readonly property bool isReordering: draggingIndex !== -1
        property real hoverScrollSpeed: plasmoid.configuration.hoverScrollSpeed ?? 14

        HoverHandler {
            id: dockHoverHandler
        }

        // edge auto-scroll timer
        Timer {
            id: edgeScrollTimer
            interval: 16
            repeat: true
            running: dockHoverHandler.hovered && dockContainer.isFull
            onTriggered: {
                const edgeThreshold = 55;
                let pos = root.isHorizontal ? dockHoverHandler.point.position.x : dockHoverHandler.point.position.y;
                let maxPos = root.isHorizontal ? dockContainer.dockW : dockContainer.dockH;

                let dir = 0;
                if (pos >= 0 && pos < edgeThreshold) {
                    dir = dockContainer.invertFold ? 1 : -1;
                } else if (pos > maxPos - edgeThreshold && pos <= maxPos) {
                    dir = dockContainer.invertFold ? -1 : 1;
                }

                if (dir === -1) {
                    dockContainer.targetScrollOffset = Math.max(0, Math.min(dockContainer.targetScrollOffset - dockContainer.hoverScrollSpeed, dockContainer.maxScroll));
                    dockContainer.scrollOffset = dockContainer.targetScrollOffset;
                } else if (dir === 1) {
                    dockContainer.targetScrollOffset = Math.min(dockContainer.maxScroll, dockContainer.targetScrollOffset + dockContainer.hoverScrollSpeed);
                    dockContainer.scrollOffset = dockContainer.targetScrollOffset;
                }
            }
        }

        // save launcher order
        function saveLauncherOrder() {
            let updatedLaunchers = [];
            for (let i = 0; i < taskRepeater.count; i++) {
                let item = taskRepeater.itemAt(i);
                if (item && item.launcherUrl && item.launcherUrl !== "") {
                    let strUrl = item.launcherUrl.toString();
                    if (updatedLaunchers.indexOf(strUrl) === -1) {
                        updatedLaunchers.push(strUrl);
                    }
                }
            }
            if (updatedLaunchers.length > 0) {
                plasmoid.configuration.launchers = updatedLaunchers;
            }
        }

        // dock dimensions
        readonly property real dockW: root.width > 0 ? root.width : parent.width
        readonly property real dockH: root.height > 0 ? root.height : parent.height

        // tile sizing
        readonly property real maxTileConfig: plasmoid.configuration.maxTileSize ?? 64
        readonly property real panelThickness: root.isHorizontal ? (dockH - 2) : (dockW - 2)
        readonly property real baseSize: Math.max(24, Math.min(panelThickness, maxTileConfig))

        readonly property real normalStep: baseSize + 4
        readonly property real tileRadius: baseSize * 0.12

        // icon & glassy config
        readonly property real iconSizePct: (plasmoid.configuration.iconSize ?? 80) / 100.0
        readonly property real glassySizePct: (plasmoid.configuration.glassySize ?? 100) / 100.0
        readonly property real glassyBorderMargin: (plasmoid.configuration.glassyBorderMargin ?? 5) / 10.0

        // stack length & folding metrics
        readonly property real stackLen: root.isHorizontal ? (stackArea.width > 0 ? stackArea.width : dockW) : (stackArea.height > 0 ? stackArea.height : dockH)

        readonly property bool isDockOverflowing: (tasksModel.count * normalStep) > stackLen
        readonly property bool autoFoldActive: !foldingDisabled && isDockOverflowing

        // scroll limits
        readonly property bool isFull: autoFoldActive
        readonly property real maxScroll: autoFoldActive ? Math.max(0, ((tasksModel.count - 1) * normalStep) + baseSize - stackLen) : 0

        // dynamic shift & positioning
        readonly property real overflowCount: maxScroll > 0 ? (maxScroll / normalStep) : 0
        readonly property real dynamicShift: Math.max(0, 2 - overflowCount) * (baseSize * 0.8)

        readonly property real shortPanelFactor: Math.max(0.0, 1.0 - (stackLen / (normalStep * 6)))

        readonly property real visualBottom: Math.min(stackLen - baseSize, stackLen - (baseSize * 0.8) + (dynamicShift * (1.0 - shortPanelFactor)))

        readonly property real tiltDist: normalStep * Math.min(5.0, 1.2 + (overflowCount * 0.8) + (shortPanelFactor * 3.0))

        readonly property real dynamicCompression: Math.min(0.95, (overflowCount * 0.45) + (shortPanelFactor * 0.85))
        readonly property real bottomCompressionFactor: dynamicCompression

        readonly property real tiltStart: autoFoldActive ? Math.max(0, visualBottom - (tiltDist * (1.0 - 0.5 * bottomCompressionFactor))) : stackLen
        readonly property real endFoldBoundary: tiltStart + tiltDist

        // bottom unfold trigger
        readonly property bool atBottom: maxScroll > 0 && scrollOffset >= (maxScroll - 2)
        property real bottomUnfold: atBottom ? 1.0 : 0.0
        Behavior on bottomUnfold {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }

        // scroll helper
        function scrollToIndex(idx) {
            if (!autoFoldActive || idx < 0 || idx >= tasksModel.count) return;
            const visibleCenter = (tiltStart / 2) - (baseSize / 2);
            const targetOffset = (idx * normalStep) - visibleCenter;
            targetScrollOffset = Math.max(0, Math.min(targetOffset, maxScroll));
            scrollOffset = targetScrollOffset;
        }

        onMaxScrollChanged: {
            if (targetScrollOffset > maxScroll) {
                targetScrollOffset = maxScroll;
                scrollOffset = maxScroll;
            }
        }

        // context menu
        Platform.Menu {
            id: contextMenu
            property int targetIndex: -1
            property bool targetIsPinned: false
            property bool targetIsWin: false
            property bool targetIsLch: false
            property bool targetIsGroup: false
            property string targetLauncherUrl: ""
            property var targetModelIndex: undefined
            property var dynamicItems: []

            function clearDynamicItems() {
                for (let i = 0; i < dynamicItems.length; i++) {
                    contextMenu.removeItem(dynamicItems[i]);
                    dynamicItems[i].destroy();
                }
                dynamicItems = [];
            }

            Platform.MenuSeparator {
                visible: contextMenu.targetIsGroup
            }

            Platform.MenuItem {
                text: "Open New Window"
                icon.name: "window-new"
                visible: contextMenu.targetIsWin || contextMenu.targetIsGroup
                onTriggered: {
                    if (contextMenu.targetIndex >= 0) {
                        tasksModel.requestNewInstance(contextMenu.targetModelIndex);
                    }
                }
            }

            Platform.MenuSeparator {
                visible: (!contextMenu.targetIsPinned && contextMenu.targetLauncherUrl !== "") || contextMenu.targetIsPinned
            }

            Platform.MenuItem {
                text: "Pin to Dock"
                icon.name: "bookmark-new"
                visible: !contextMenu.targetIsPinned && contextMenu.targetLauncherUrl !== ""
                onTriggered: {
                    if (contextMenu.targetLauncherUrl !== "") {
                        tasksModel.requestAddLauncher(contextMenu.targetLauncherUrl);
                    }
                }
            }

            Platform.MenuItem {
                text: "Unpin from Dock"
                icon.name: "bookmark-remove"
                visible: contextMenu.targetIsPinned
                onTriggered: {
                    if (contextMenu.targetLauncherUrl !== "") {
                        tasksModel.requestRemoveLauncher(contextMenu.targetLauncherUrl);
                    }
                }
            }

            Platform.MenuSeparator {
                visible: contextMenu.targetIsWin || contextMenu.targetIsGroup
            }

            Platform.MenuItem {
                text: contextMenu.targetIsGroup ? "Close All" : "Close"
                icon.name: "window-close"
                visible: contextMenu.targetIsWin || contextMenu.targetIsGroup
                onTriggered: {
                    if (contextMenu.targetIndex >= 0) {
                        tasksModel.requestClose(contextMenu.targetModelIndex);
                    }
                }
            }
        }

        // drag & drop target
        DropArea {
            anchors.fill: parent
            keys: ["text/x-plasmoid-servicename", "text/uri-list", "application/x-desktop"]
            onDropped: (drop) => {
                if (drop.hasUrls && drop.urls.length > 0) {
                    for (let i = 0; i < drop.urls.length; i++) {
                        tasksModel.requestAddLauncher(drop.urls[i]);
                    }
                } else if (drop.hasText && drop.text.length > 0) {
                    tasksModel.requestAddLauncher(drop.text);
                }
            }
        }

        // icon container area
        Item {
            id: stackArea
            anchors.fill: parent
            clip: dockContainer.foldingDisabled

            // task repeater
            Repeater {
                id: taskRepeater
                model: tasksModel

                delegate: Item {
                    id: taskTile
                    required property int index
                    required property var model

                    // spawn animation
                    property real spawnProgress: 0.0
                    Behavior on spawnProgress {
                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    }

                    // reorder animation
                    property real animatedIndex: index
                    Behavior on animatedIndex {
                        enabled: dockContainer.draggingIndex === -1
                        NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }

                    property real dragOffset: 0

                    // model properties
                    readonly property var iconSource: model ? (model.decoration || model.iconName || model.launcherUrl || "application-x-executable") : "application-x-executable"

                    readonly property string launcherUrl: {
                        if (!model) return "";
                        var u = model.LauncherUrl || model.launcherUrl || model.LauncherUrlWithoutIcon || model.launcherUrlWithoutIcon || "";
                        return u ? u.toString() : "";
                    }

                    readonly property bool isActiveWin: model ? (model.isActive ?? model.IsActive ?? false) : false
                    readonly property bool isMinimizedWin: model ? (model.isMinimized ?? model.IsMinimized ?? false) : false
                    readonly property bool isWin: model ? (model.isWindow ?? model.IsWindow ?? false) : false
                    readonly property bool isLch: model ? (model.isLauncher ?? model.IsLauncher ?? false) : false
                    readonly property bool isGroup: model ? (model.IsGroupParent ?? model.isGroupParent ?? false) : false
                    readonly property bool isRunning: isWin || !isLch || isActiveWin || isMinimizedWin
                    readonly property int notificationCount: model ? (model.smartCount ?? model.SmartCount ?? 0) : 0
                    readonly property bool isPlayingAudio: model ? (model.isAudioPlaying ?? model.IsAudioPlaying ?? false) : false

                    onIsActiveWinChanged: {
                        if (isActiveWin && !dockContainer.isReordering && dockContainer.isFull) {
                            dockContainer.scrollToIndex(index);
                        }
                    }

                    Component.onCompleted: {
                        spawnProgress = 1.0;
                        if (isActiveWin && !dockContainer.isReordering && dockContainer.isFull) {
                            dockContainer.scrollToIndex(index);
                        }
                    }

                    readonly property bool isPinned: {
                        if (!model) return false;
                        let configLaunchers = plasmoid.configuration.launchers || [];
                        let currentUrl = launcherUrl ? launcherUrl.toString() : "";
                        if (currentUrl !== "" && configLaunchers.indexOf(currentUrl) !== -1) {
                            return true;
                        }
                        return false;
                    }

                    // index adjustments
                    readonly property real adjustedIndex: {
                        let dragIdx = dockContainer.draggingIndex;
                        let targetIdx = dockContainer.dropTargetIndex;
                        if (dragIdx === -1 || targetIdx === -1) {
                            return animatedIndex;
                        }
                        if (index === dragIdx) return index;
                        if (dragIdx < targetIdx) {
                            if (index > dragIdx && index <= targetIdx) { return index - 1; }
                        } else if (dragIdx > targetIdx) {
                            if (index >= targetIdx && index < dragIdx) { return index + 1; }
                        }
                        return index;
                    }

                    // raw position math
                    readonly property real rawPos: {
                        let stdPos = (adjustedIndex * dockContainer.normalStep) - dockContainer.scrollOffset;
                        let lastIdx = tasksModel.count - 1;
                        let targetPos = (dockContainer.stackLen - dockContainer.baseSize) - ((lastIdx - adjustedIndex) * dockContainer.normalStep);
                        if (targetPos > stdPos) {
                            return stdPos + (targetPos - stdPos) * dockContainer.bottomUnfold;
                        }
                        return stdPos;
                    }

                    readonly property real distFromCenter: Math.abs(rawPos - (dockContainer.tiltStart / 2))

                    // fold boundaries
                    readonly property bool isFoldedStart: dockContainer.autoFoldActive && (rawPos < 0)
                    readonly property bool isFoldedEnd: dockContainer.autoFoldActive && (rawPos > dockContainer.endFoldBoundary)

                    readonly property real foldFactorStart: isFoldedStart ? Math.min(1.0, -rawPos / (dockContainer.normalStep * 0.80)) : 0.0
                    readonly property real startFoldIndex: isFoldedStart ? (-rawPos / dockContainer.normalStep) : 0
                    readonly property real startPos: - Math.min(startFoldIndex * (dockContainer.baseSize * 0.02), dockContainer.baseSize * 0.05)

                    readonly property real baseFoldFactorEnd: dockContainer.autoFoldActive ? Math.max(0.0, Math.min(1.0, (rawPos - dockContainer.tiltStart) / dockContainer.tiltDist)) : 0.0
                    readonly property real foldFactorEnd: baseFoldFactorEnd * (1.0 - dockContainer.bottomUnfold)

                    // bottom tilt offset
                    readonly property real bottomTiltOffset: dockContainer.tiltDist * (baseFoldFactorEnd - 0.5 * dockContainer.bottomCompressionFactor * Math.pow(baseFoldFactorEnd, 2))

                    readonly property real endFoldIndex: isFoldedEnd ? ((rawPos - dockContainer.endFoldBoundary) / dockContainer.normalStep) : 0
                    readonly property real endPos: dockContainer.visualBottom + (endFoldIndex * (dockContainer.baseSize * 0.06))

                    // final positions
                    readonly property real staticPos: {
                        if (!dockContainer.autoFoldActive) return rawPos;
                        if (isFoldedStart) return startPos;
                        if (rawPos > dockContainer.tiltStart) {
                            let foldedPos = isFoldedEnd ? endPos : (dockContainer.tiltStart + bottomTiltOffset);
                            return foldedPos * (1.0 - dockContainer.bottomUnfold) + rawPos * dockContainer.bottomUnfold;
                        }
                        return rawPos;
                    }

                    readonly property real finalPos: dockContainer.invertFold ? (dockContainer.stackLen - dockContainer.baseSize - staticPos) : staticPos

                    // edge fade opacity
                    readonly property real edgeFadeOpacity: {
                        if (dockContainer.autoFoldActive) return 1.0;
                        if (rawPos < 0) return Math.max(0.0, 1.0 + (rawPos / dockContainer.normalStep));
                        let overflowPoint = dockContainer.stackLen - dockContainer.baseSize;
                        if (rawPos > overflowPoint) return Math.max(0.0, 1.0 - ((rawPos - overflowPoint) / dockContainer.normalStep));
                        return 1.0;
                    }

                    readonly property real startEdgeOpacity: {
                        if (!isFoldedStart) return 1.0;
                        let fadeStart = -dockContainer.normalStep * 0.1;
                        let fadeEnd = -dockContainer.normalStep * 0.8;
                        if (rawPos >= fadeStart) return 1.0;
                        if (rawPos <= fadeEnd) return 0.0;
                        return (rawPos - fadeEnd) / (fadeStart - fadeEnd);
                    }

                    readonly property real endFadeStartRaw: dockContainer.endFoldBoundary + (dockContainer.normalStep * 0.5)
                    readonly property real endFadeEndRaw: dockContainer.endFoldBoundary + (dockContainer.normalStep * 6.4)
                    readonly property real endEdgeOpacity: {
                        if (!isFoldedEnd) return 1.0;
                        let op = 1.0;
                        if (rawPos <= endFadeStartRaw) op = 1.0;
                        else if (rawPos >= endFadeEndRaw) op = 0.0;
                        else op = Math.max(0.0, 1.0 - ((rawPos - endFadeStartRaw) / (endFadeEndRaw - endFadeStartRaw)));
                        return op * (1.0 - dockContainer.bottomUnfold) + 1.0 * dockContainer.bottomUnfold;
                    }

                    readonly property real targetOpacity: {
                        if (index === dockContainer.draggingIndex) return 1.0;
                        if (!dockContainer.autoFoldActive) return edgeFadeOpacity;
                        return Math.min(startEdgeOpacity, endEdgeOpacity);
                    }

                    // tilt angle calculation
                    readonly property real tiltSpreadExponent: Math.max(1.0, 1.8 - (dockContainer.overflowCount * 0.2))
                    readonly property real dynamicBottomAngle: Math.min(40, 10 + (dockContainer.overflowCount * 8))
                    readonly property real safeFoldEnd: Math.max(0.0, foldFactorEnd)

                    readonly property real baseAngle: (Math.pow(safeFoldEnd, tiltSpreadExponent) * dynamicBottomAngle) - (foldFactorStart * 40)
                    readonly property real targetAngle: (index === dockContainer.draggingIndex || !dockContainer.autoFoldActive) ? 0 : (dockContainer.invertFold ? -baseAngle : baseAngle)

                    // tile scaling
                    readonly property real targetScale: {
                        if (index === dockContainer.draggingIndex) return 1.12;
                        if (!dockContainer.autoFoldActive) return 1.0;
                        let foldScale = 1.0 - (foldFactorStart * 0.0) - (foldFactorEnd * 0.0);
                        return Math.max(0.75, foldScale);
                    }

                    readonly property bool isFullyUnfolded: foldFactorStart < 0.05 && foldFactorEnd < 0.05
                    readonly property bool isHovered: tileMouseArea.containsMouse && !edgeScrollTimer.running && dockContainer.draggingIndex === -1 && isFullyUnfolded

                    // hover & click scale animation
                    property real interactionScale: {
                        if (tileMouseArea.pressed && !tileMouseArea.isTileDragging) return 0.85;
                        if (dockContainer.enableHoverPop && isHovered) return 1.15;
                        return 1.0;
                    }
                    Behavior on interactionScale {
                        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                    }

                    // tilt animation
                    property real animatedAngle: targetAngle
                    Behavior on animatedAngle {
                        NumberAnimation { duration: 0; easing.type: Easing.OutQuad }
                    }

                    property real animatedScale: targetScale * spawnProgress * interactionScale
                    property real animatedOpacity: targetOpacity * Math.min(1.0, spawnProgress * 2.0)

                    // tile layout & layering
                    opacity: animatedOpacity
                    width: dockContainer.baseSize
                    height: dockContainer.baseSize

                    x: root.isHorizontal ? ((index === dockContainer.draggingIndex) ? (finalPos + dragOffset) : finalPos) : (parent.width - width) / 2
                    y: root.isHorizontal ? (parent.height - height) / 2 : ((index === dockContainer.draggingIndex) ? (finalPos + dragOffset) : finalPos)

                    z: (index === dockContainer.draggingIndex) ? 9999 : (isHovered ? 9998 : (5000 - index))

                    // rotation & scale transform
                    transform: [
                        Rotation {
                            origin.x: dockContainer.baseSize / 2
                            origin.y: dockContainer.baseSize / 2
                            axis { x: root.isHorizontal ? 0 : 1; y: root.isHorizontal ? 1 : 0; z: 0 }
                            angle: taskTile.animatedAngle
                        },
                        Scale {
                            origin.x: dockContainer.baseSize / 2
                            origin.y: dockContainer.baseSize / 2
                            xScale: taskTile.animatedScale
                            yScale: taskTile.animatedScale
                        }
                    ]

                    // tile visuals
                    Item {
                        id: tileBg
                        anchors.fill: parent

                        // icon component
                        Kirigami.Icon {
                            id: appIcon
                            anchors.centerIn: parent
                            width: parent.width * dockContainer.iconSizePct
                            height: parent.height * dockContainer.iconSizePct
                            source: taskTile.iconSource
                        }

                        // dominant color extractor
                        Kirigami.ImageColors {
                            id: iconColors
                            source: appIcon
                        }

                        // glassy border overlay
                        Rectangle {
                            visible: plasmoid.configuration.enableGlassyBorders
                            anchors.centerIn: parent
                            width: parent.width * dockContainer.glassySizePct
                            height: parent.height * dockContainer.glassySizePct
                            radius: (dockContainer.tileRadius + 0.9) * dockContainer.glassySizePct

                            border.width: 0.5
                            border.color: Qt.rgba(1, 1, 1, 0.38)

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, taskTile.isActiveWin ? 0.35 : 0.20) }
                                GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, taskTile.isActiveWin ? 0.12 : 0.05) }
                                GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, taskTile.isActiveWin ? 0.02 : 0.05) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, taskTile.isActiveWin ? 0.10 : 0.20) }
                            }

                            Rectangle {
                                visible: dockContainer.glassyBorderMargin > 0
                                anchors.fill: parent
                                anchors.margins: dockContainer.glassyBorderMargin
                                radius: parent.radius - dockContainer.glassyBorderMargin
                                color: "transparent"
                                border.width: 0.5
                                border.color: Qt.rgba(0, 0, 0, 0.15)
                            }
                        }

                        // audio badge (still broken)
                        Rectangle {
                            visible: taskTile.isPlayingAudio
                            width: dockContainer.baseSize * 0.35
                            height: width
                            radius: width / 2
                            color: Kirigami.Theme.highlightColor
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: - (width * 0.2)
                            z: 30
                            border.width: 1
                            border.color: Kirigami.Theme.backgroundColor

                            Kirigami.Icon {
                                anchors.fill: parent
                                anchors.margins: parent.width * 0.2
                                source: "media-playback-start"
                                color: Kirigami.Theme.backgroundColor
                            }
                        }

                        // notification badge (also broken lmao)
                        Rectangle {
                            visible: taskTile.notificationCount > 0
                            width: dockContainer.baseSize * 0.4
                            height: width
                            radius: width / 2
                            color: Kirigami.Theme.negativeTextColor
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: - (width * 0.2)
                            z: 30

                            border.width: 1
                            border.color: Kirigami.Theme.backgroundColor

                            Text {
                                anchors.centerIn: parent
                                text: taskTile.notificationCount > 99 ? "99+" : taskTile.notificationCount.toString()
                                color: Kirigami.Theme.backgroundColor
                                font.pointSize: Math.max(6, dockContainer.baseSize * 0.15)
                                font.bold: true
                            }
                        }

                        // active window indicator
                        Item {
                            id: indicatorContainer
                            visible: taskTile.isRunning
                            z: 20

                            readonly property int indStyle: plasmoid.configuration.indicatorStyle ?? 0
                            readonly property bool isHoriz: root.isHorizontal
                            readonly property bool isTopStyle: indStyle === 6 || indStyle === 7
                            readonly property color activeColor: {
                                if (plasmoid.configuration.useDominantColor) {
                                    let dom = iconColors.dominant;
                                    if (dom && dom.toString() !== "#00000000" && dom.toString() !== "#000000") {
                                        let lum = (0.299 * dom.r + 0.587 * dom.g + 0.114 * dom.b);
                                        if (lum > 0.20) {
                                            return dom;
                                        }
                                        let ctw = iconColors.closestToWhite;
                                        if (ctw && ctw.toString() !== "#00000000") {
                                            return ctw;
                                        }
                                    }
                                }
                                return Kirigami.Theme.highlightColor;
                            }

                            x: isHoriz ? ((parent.width - width) / 2) : (isTopStyle ? (parent.width - width - 2) : 2)
                            y: isHoriz ? (isTopStyle ? 2 : (parent.height - height - 2)) : ((parent.height - height) / 2)

                            width: {
                                if (indStyle === 0 || indStyle === 3 || indStyle === 5 || indStyle === 6) return taskTile.isActiveWin ? 8 : 6;
                                if (isHoriz) {
                                    if (indStyle === 1) return taskTile.isActiveWin ? dockContainer.baseSize * 0.4 : dockContainer.baseSize * 0.2;
                                    if (indStyle === 2 || indStyle === 7) return taskTile.isActiveWin ? dockContainer.baseSize * 0.6 : dockContainer.baseSize * 0.3;
                                    if (indStyle === 4) return dockContainer.baseSize * 0.8;
                                } else {
                                    if (indStyle === 1) return 4;
                                    if (indStyle === 2 || indStyle === 7 || indStyle === 4) return 3;
                                }
                                return 6;
                            }

                            height: {
                                if (indStyle === 0 || indStyle === 3 || indStyle === 5 || indStyle === 6) return taskTile.isActiveWin ? 8 : 6;
                                if (!isHoriz) {
                                    if (indStyle === 1) return taskTile.isActiveWin ? dockContainer.baseSize * 0.4 : dockContainer.baseSize * 0.2;
                                    if (indStyle === 2 || indStyle === 7) return taskTile.isActiveWin ? dockContainer.baseSize * 0.6 : dockContainer.baseSize * 0.3;
                                    if (indStyle === 4) return dockContainer.baseSize * 0.8;
                                } else {
                                    if (indStyle === 1) return 4;
                                    if (indStyle === 2 || indStyle === 7 || indStyle === 4) return 3;
                                }
                                return 6;
                            }

                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                            Rectangle {
                                id: indicatorRect
                                anchors.fill: parent
                                antialiasing: true
                                radius: {
                                    if (indicatorContainer.indStyle === 5) return 0;
                                    if (indicatorContainer.indStyle === 2 || indicatorContainer.indStyle === 3 || indicatorContainer.indStyle === 7 || indicatorContainer.indStyle === 4) return 1.5;
                                    return 100;
                                }

                                color: taskTile.isActiveWin ? indicatorContainer.activeColor : Qt.rgba(indicatorContainer.activeColor.r, indicatorContainer.activeColor.g, indicatorContainer.activeColor.b, 0.6)

                                transform: Rotation {
                                    origin.x: indicatorContainer.width / 2
                                    origin.y: indicatorContainer.height / 2
                                    angle: indicatorContainer.indStyle === 3 ? 45 : 0
                                }

                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                        }
                    }

                    // mouse interaction & reordering
                    MouseArea {
                        id: tileMouseArea
                        anchors.fill: parent
                        enabled: true
                        hoverEnabled: true
                        cursorShape: isTileDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        preventStealing: false

                        property real pressParentPos: 0
                        property bool isTileDragging: false

                        onPressed: (mouse) => {
                            pressParentPos = mapToItem(dockContainer, mouse.x, mouse.y)[root.isHorizontal ? 'x' : 'y'];
                            isTileDragging = false;
                            taskTile.dragOffset = 0;
                        }

                        onPositionChanged: (mouse) => {
                            if (mouse.buttons & Qt.LeftButton) {
                                let currentParentPos = mapToItem(dockContainer, mouse.x, mouse.y)[root.isHorizontal ? 'x' : 'y'];
                                let deltaPos = currentParentPos - pressParentPos;

                                if (!isTileDragging && Math.abs(deltaPos) > 8) {
                                    isTileDragging = true;
                                    dockContainer.draggingIndex = index;
                                }

                                if (isTileDragging) {
                                    taskTile.dragOffset = deltaPos;
                                    let currentVisualPos = taskTile.finalPos + taskTile.dragOffset;
                                    let effPos = dockContainer.invertFold ? (dockContainer.stackLen - dockContainer.baseSize - currentVisualPos) : currentVisualPos;
                                    let rawTargetPos = effPos + dockContainer.scrollOffset;
                                    let target = Math.round(rawTargetPos / dockContainer.normalStep);
                                    dockContainer.dropTargetIndex = Math.max(0, Math.min(tasksModel.count - 1, target));
                                }
                            }
                        }

                        onReleased: (mouse) => {
                            if (isTileDragging) {
                                if (dockContainer.dropTargetIndex !== -1 && dockContainer.dropTargetIndex !== index) {
                                    let fromIdx = index;
                                    let toIdx = dockContainer.dropTargetIndex;
                                    if (typeof tasksModel.move === "function") {
                                        tasksModel.move(fromIdx, toIdx);
                                    } else if (typeof tasksModel.requestMove === "function") {
                                        tasksModel.requestMove(fromIdx, toIdx);
                                    }
                                    Qt.callLater(dockContainer.saveLauncherOrder);
                                }
                                isTileDragging = false;
                                taskTile.dragOffset = 0;
                                dockContainer.draggingIndex = -1;
                                dockContainer.dropTargetIndex = -1;
                            } else {
                                if (!taskTile.model) return;
                                const idx = tasksModel.index(taskTile.index, 0);
                                if (mouse.button === Qt.LeftButton) {
                                    if (taskTile.isGroup) {
                                        let childCount = tasksModel.rowCount(idx);
                                        if (childCount > 0) {
                                            // window toggle logic
                                            let firstChildIdx = tasksModel.index(0, 0, idx);
                                            if (taskTile.isActiveWin) {
                                                tasksModel.requestToggleMinimized(firstChildIdx);
                                            } else {
                                                tasksModel.requestActivate(firstChildIdx);
                                            }
                                        }
                                    } else if (taskTile.isWin) {
                                        if (taskTile.isActiveWin || taskTile.isMinimizedWin) {
                                            tasksModel.requestToggleMinimized(idx);
                                        } else {
                                            tasksModel.requestActivate(idx);
                                        }
                                    } else {
                                        tasksModel.requestActivate(idx);
                                    }
                                } else if (mouse.button === Qt.MiddleButton) {
                                    tasksModel.requestNewInstance(idx);
                                } else if (mouse.button === Qt.RightButton) {
                                    contextMenu.targetIndex = taskTile.index;
                                    contextMenu.targetIsPinned = taskTile.isPinned;
                                    contextMenu.targetIsWin = taskTile.isWin;
                                    contextMenu.targetIsLch = taskTile.isLch;
                                    contextMenu.targetIsGroup = taskTile.isGroup;
                                    contextMenu.targetLauncherUrl = taskTile.launcherUrl;
                                    contextMenu.targetModelIndex = tasksModel.index(taskTile.index, 0);
                                    contextMenu.clearDynamicItems();
                                    if (taskTile.isGroup) {
                                        let childCount = tasksModel.rowCount(contextMenu.targetModelIndex);
                                        let newItems = [];
                                        for (let i = 0; i < childCount; i++) {
                                            let childIdx = tasksModel.index(i, 0, contextMenu.targetModelIndex);
                                            let winTitle = tasksModel.data(childIdx, Qt.DisplayRole);
                                            if (!winTitle || winTitle === "") {
                                                winTitle = "Window " + (i + 1);
                                            }
                                            let qmlString = 'import QtQuick; import Qt.labs.platform as Platform; Platform.MenuItem {}';
                                            let menuItem = Qt.createQmlObject(qmlString, contextMenu);
                                            menuItem.text = winTitle;
                                            let activateFunc = (function(capturedIdx) {
                                                return function() { tasksModel.requestActivate(capturedIdx); }
                                            })(childIdx);
                                            menuItem.triggered.connect(activateFunc);
                                            contextMenu.insertItem(i, menuItem);
                                            newItems.push(menuItem);
                                        }
                                        contextMenu.dynamicItems = newItems;
                                    }
                                    contextMenu.open();
                                }
                            }
                        }

                        onCanceled: {
                            isTileDragging = false;
                            taskTile.dragOffset = 0;
                            if (dockContainer.draggingIndex === index) {
                                dockContainer.draggingIndex = -1;
                                dockContainer.dropTargetIndex = -1;
                            }
                        }
                    }
                }
            }
        }
    }
}
