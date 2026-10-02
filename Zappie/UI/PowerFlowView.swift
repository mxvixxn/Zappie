import SwiftUI

/// `[Adapter] —W→ ● —W→ [System]`, with the battery hanging off the junction.
struct PowerFlowView: View {
    let flow: PowerPresentation.Flow

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                FlowNode(symbol: "powerplug", label: "어댑터", tint: Theme.adapter)
                    .opacity(flow.adapterActive ? 1 : 0.45)
                FlowSegment(text: flow.adapterText, color: flow.adapterActive ? Theme.adapter : Theme.inactive,
                            dashed: !flow.adapterActive)
                Circle()
                    .fill(Theme.color(flow.junctionTint))
                    .frame(width: 10, height: 10)
                FlowSegment(text: flow.systemText, color: Theme.color(flow.systemLineTint), dashed: false)
                FlowNode(symbol: "laptopcomputer", label: "시스템", tint: Theme.text)
            }

            HStack(spacing: 10) {
                Color.clear.frame(width: 80, height: 1)
                VerticalConnector(direction: flow.vertical)
                    .frame(width: 12)
                Text(flow.batteryText)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 80, alignment: .leading)
            }

            FlowNode(symbol: "battery.100", label: "배터리", tint: Theme.battery)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}

private struct FlowNode: View {
    let symbol: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(tint == Theme.text ? 0.10 : 0.16), in: Circle())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 10)
        .frame(width: 76)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
    }
}

private struct FlowSegment: View {
    let text: String
    let color: Color
    let dashed: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 0) {
                Line(axis: .horizontal)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
                    .frame(height: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
}

private struct VerticalConnector: View {
    let direction: PowerPresentation.Flow.Vertical

    var body: some View {
        let color = direction == .idle ? Theme.inactive : Theme.battery
        VStack(spacing: 0) {
            if direction == .up { chevron("chevron.up", color) }
            Line(axis: .vertical)
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: direction == .idle ? [4, 3] : []))
                .frame(width: 2, height: 26)
            if direction == .down { chevron("chevron.down", color) }
        }
    }

    private func chevron(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
    }
}

private struct Line: Shape {
    let axis: Axis

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch axis {
        case .horizontal:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        case .vertical:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        return p
    }
}
