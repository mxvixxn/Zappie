import SwiftUI

/// Top: adapter and battery. Middle: system. Bottom: every USB-C port in parallel.
/// Nodes sit at fixed rows; connectors are drawn behind them as elbow lines with chevrons.
struct PowerTreeView: View {
    /// `.large` for the main window, `.compact` for the menu bar dropdown.
    struct Metrics {
        var sourceWidth: CGFloat
        var systemWidth: CGFloat
        var nodeHeight: CGFloat
        var portHeight: CGFloat
        var gap: CGFloat
        var maxPortWidth: CGFloat
        var portSpacing: CGFloat
        var circle: CGFloat
        var symbol: CGFloat
        var title: CGFloat
        var value: CGFloat
        var detail: CGFloat
        var spacing: CGFloat
        var radius: CGFloat
        var chevron: CGFloat

        static let large = Metrics(sourceWidth: 150, systemWidth: 170, nodeHeight: 112, portHeight: 116, gap: 48,
                                   maxPortWidth: 180, portSpacing: 16, circle: 36, symbol: 16, title: 12, value: 18,
                                   detail: 11, spacing: 5, radius: 12, chevron: 5)
        static let compact = Metrics(sourceWidth: 104, systemWidth: 116, nodeHeight: 74, portHeight: 80, gap: 28,
                                     maxPortWidth: 92, portSpacing: 8, circle: 26, symbol: 12, title: 10, value: 13,
                                     detail: 9.5, spacing: 3, radius: 10, chevron: 4)
    }

    let tree: PowerTree
    var metrics: Metrics = .large

    private var sourceWidth: CGFloat { metrics.sourceWidth }
    private var nodeHeight: CGFloat { metrics.nodeHeight }
    private var portHeight: CGFloat { metrics.portHeight }
    private var gap: CGFloat { metrics.gap }

    private var height: CGFloat { nodeHeight * 2 + portHeight + gap * 2 }

    var body: some View {
        GeometryReader { geo in
            let l = Layout(width: geo.size.width, portCount: tree.ports.count, nodeHeight: nodeHeight, gap: gap,
                           maxPortWidth: metrics.maxPortWidth, portSpacing: metrics.portSpacing)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in drawConnectors(context, l) }

                node(symbol: "powerplug", title: tree.adapterTitle, value: tree.adapterText, tint: Theme.adapter)
                    .opacity(tree.adapterActive ? 1 : 0.45)
                    .frame(width: sourceWidth, height: nodeHeight)
                    .position(x: l.adapterX, y: nodeHeight / 2)

                node(symbol: "battery.100", title: "배터리 \(tree.batteryPercent)", value: tree.batteryText,
                     tint: Theme.battery)
                    .frame(width: sourceWidth, height: nodeHeight)
                    .position(x: l.batteryX, y: nodeHeight / 2)

                node(symbol: "laptopcomputer", title: "시스템", value: tree.systemText, detail: tree.macText,
                     tint: Theme.text)
                    .frame(width: metrics.systemWidth, height: nodeHeight)
                    .position(x: l.centerX, y: l.systemTop + nodeHeight / 2)

                ForEach(Array(tree.ports.enumerated()), id: \.offset) { index, port in
                    node(symbol: port.icon.symbol, title: port.name, value: port.watts, detail: port.detail,
                         tint: port.isInput ? Theme.adapter : port.connected ? Theme.usb : Theme.secondaryText)
                        .opacity(port.active || port.isInput ? 1 : port.connected ? 0.85 : 0.55)
                        .frame(width: l.portWidth, height: portHeight)
                        .position(x: l.portX(index), y: l.portsTop + portHeight / 2)
                }
            }
        }
        .frame(height: height)
    }

    // MARK: - Connectors

    private struct Layout {
        let width: CGFloat
        let portCount: Int
        let nodeHeight: CGFloat
        let gap: CGFloat
        let maxPortWidth: CGFloat
        let portSpacing: CGFloat

        var adapterX: CGFloat { width * 0.25 }
        var batteryX: CGFloat { width * 0.75 }
        var centerX: CGFloat { width / 2 }
        var sourcesBottom: CGFloat { nodeHeight }
        var sourcesBus: CGFloat { nodeHeight + gap / 2 }
        var systemTop: CGFloat { nodeHeight + gap }
        var systemBottom: CGFloat { systemTop + nodeHeight }
        var portsBus: CGFloat { systemBottom + gap / 2 }
        var portsTop: CGFloat { systemBottom + gap }
        var portWidth: CGFloat { min(maxPortWidth, width / CGFloat(max(portCount, 1)) - portSpacing) }

        func portX(_ index: Int) -> CGFloat {
            width * (CGFloat(index) * 2 + 1) / (CGFloat(max(portCount, 1)) * 2)
        }
    }

    private func drawConnectors(_ context: GraphicsContext, _ l: Layout) {
        let inactive = Theme.inactive
        let trunkColor = tree.adapterActive ? Theme.adapter : Theme.battery

        // Sources → system
        stroke(context, [.init(x: l.adapterX, y: l.sourcesBottom), .init(x: l.adapterX, y: l.sourcesBus),
                         .init(x: l.centerX, y: l.sourcesBus)],
               tree.adapterActive ? Theme.adapter : inactive, dashed: !tree.adapterActive)
        let batteryActive = tree.batteryLink != .idle
        stroke(context, [.init(x: l.batteryX, y: l.sourcesBottom), .init(x: l.batteryX, y: l.sourcesBus),
                         .init(x: l.centerX, y: l.sourcesBus)],
               batteryActive ? Theme.battery : inactive, dashed: !batteryActive)
        stroke(context, [.init(x: l.centerX, y: l.sourcesBus), .init(x: l.centerX, y: l.systemTop)],
               trunkColor, dashed: false)

        if tree.adapterActive {
            chevron(context, at: .init(x: l.adapterX, y: (l.sourcesBottom + l.sourcesBus) / 2 + 4), down: true,
                    Theme.adapter)
        }
        switch tree.batteryLink {
        case .charging:
            chevron(context, at: .init(x: l.batteryX, y: l.sourcesBottom + 2), down: false, Theme.battery)
        case .discharging:
            chevron(context, at: .init(x: l.batteryX, y: (l.sourcesBottom + l.sourcesBus) / 2 + 4), down: true,
                    Theme.battery)
        case .idle:
            break
        }
        chevron(context, at: .init(x: l.centerX, y: l.systemTop - 2), down: true, trunkColor)

        // System → ports. Idle branches first so active ones draw on top of the shared bus.
        stroke(context, [.init(x: l.centerX, y: l.systemBottom), .init(x: l.centerX, y: l.portsBus)],
               tree.anyPortConnected ? Theme.usb : inactive, dashed: !tree.usbActive)
        // Draw order: empty, then connected-but-idle, then charging, so stronger lines sit on top.
        func rank(_ p: PowerTree.Port) -> Int { p.active ? 2 : p.connected ? 1 : 0 }
        let order = tree.ports.indices.sorted { rank(tree.ports[$0]) < rank(tree.ports[$1]) }
        // The charger's own port takes no output branch.
        for index in order where !tree.ports[index].isInput {
            let port = tree.ports[index]
            let active = port.active
            let x = l.portX(index)
            stroke(context, [.init(x: l.centerX, y: l.portsBus), .init(x: x, y: l.portsBus),
                             .init(x: x, y: l.portsTop)],
                   port.connected ? Theme.usb : inactive, dashed: !active)
            if active {
                chevron(context, at: .init(x: x, y: l.portsTop - 2), down: true, Theme.usb)
            }
        }
    }

    private func stroke(_ context: GraphicsContext, _ points: [CGPoint], _ color: Color, dashed: Bool) {
        var path = Path()
        path.addLines(points)
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: dashed ? [4, 4] : []))
    }

    private func chevron(_ context: GraphicsContext, at tip: CGPoint, down: Bool, _ color: Color) {
        let size = metrics.chevron
        let dy = down ? -size : size
        var path = Path()
        path.move(to: .init(x: tip.x - size, y: tip.y + dy))
        path.addLine(to: tip)
        path.addLine(to: .init(x: tip.x + size, y: tip.y + dy))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Nodes

    private func node(symbol: String, title: String, value: String, detail: String? = nil,
                      tint: Color) -> some View {
        VStack(spacing: metrics.spacing) {
            Image(systemName: symbol)
                .font(.system(size: metrics.symbol, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: metrics.circle, height: metrics.circle)
                .background(tint.opacity(tint == Theme.text ? 0.10 : 0.16), in: Circle())
            Text(title)
                .font(.system(size: metrics.title))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: metrics.value, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let detail {
                Text(detail)
                    .font(.system(size: metrics.detail))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: metrics.radius))
        .overlay(RoundedRectangle(cornerRadius: metrics.radius).stroke(Theme.border))
    }
}
