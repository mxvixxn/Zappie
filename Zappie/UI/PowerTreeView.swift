import SwiftUI

/// Top: adapter and battery. Middle: system. Bottom: every USB-C port in parallel.
/// Nodes sit at fixed rows; connectors are drawn behind them as elbow lines with chevrons.
struct PowerTreeView: View {
    let tree: PowerTree

    private let sourceWidth: CGFloat = 150
    private let nodeHeight: CGFloat = 112
    private let portHeight: CGFloat = 116
    private let gap: CGFloat = 48

    private var height: CGFloat { nodeHeight * 2 + portHeight + gap * 2 }

    var body: some View {
        GeometryReader { geo in
            let l = Layout(width: geo.size.width, portCount: tree.ports.count, nodeHeight: nodeHeight, gap: gap)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in drawConnectors(context, l) }

                node(symbol: "powerplug", title: "어댑터", value: tree.adapterText, tint: Theme.adapter)
                    .opacity(tree.adapterActive ? 1 : 0.45)
                    .frame(width: sourceWidth, height: nodeHeight)
                    .position(x: l.adapterX, y: nodeHeight / 2)

                node(symbol: "battery.100", title: "배터리 \(tree.batteryPercent)", value: tree.batteryText,
                     tint: Theme.battery)
                    .frame(width: sourceWidth, height: nodeHeight)
                    .position(x: l.batteryX, y: nodeHeight / 2)

                node(symbol: "laptopcomputer", title: "시스템", value: tree.systemText, detail: tree.macText,
                     tint: Theme.text)
                    .frame(width: sourceWidth + 20, height: nodeHeight)
                    .position(x: l.centerX, y: l.systemTop + nodeHeight / 2)

                ForEach(Array(tree.ports.enumerated()), id: \.offset) { index, port in
                    node(symbol: "cable.connector", title: port.name, value: port.watts, detail: port.detail,
                         tint: port.active ? Theme.usb : Theme.secondaryText)
                        .opacity(port.active ? 1 : 0.55)
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

        var adapterX: CGFloat { width * 0.25 }
        var batteryX: CGFloat { width * 0.75 }
        var centerX: CGFloat { width / 2 }
        var sourcesBottom: CGFloat { nodeHeight }
        var sourcesBus: CGFloat { nodeHeight + gap / 2 }
        var systemTop: CGFloat { nodeHeight + gap }
        var systemBottom: CGFloat { systemTop + nodeHeight }
        var portsBus: CGFloat { systemBottom + gap / 2 }
        var portsTop: CGFloat { systemBottom + gap }
        var portWidth: CGFloat { min(180, width / CGFloat(max(portCount, 1)) - 16) }

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
               tree.usbActive ? Theme.usb : inactive, dashed: !tree.usbActive)
        let order = tree.ports.indices.sorted { !tree.ports[$0].active && tree.ports[$1].active }
        for index in order {
            let active = tree.ports[index].active
            let x = l.portX(index)
            stroke(context, [.init(x: l.centerX, y: l.portsBus), .init(x: x, y: l.portsBus),
                             .init(x: x, y: l.portsTop)],
                   active ? Theme.usb : inactive, dashed: !active)
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
        let dy: CGFloat = down ? -5 : 5
        var path = Path()
        path.move(to: .init(x: tip.x - 5, y: tip.y + dy))
        path.addLine(to: tip)
        path.addLine(to: .init(x: tip.x + 5, y: tip.y + dy))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Nodes

    private func node(symbol: String, title: String, value: String, detail: String? = nil,
                      tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(tint == Theme.text ? 0.10 : 0.16), in: Circle())
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}
