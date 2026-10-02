import SwiftUI

/// `[Adapter] —W→ ● —W→ [System]`, with the battery hanging off the junction.
/// `.compact` is the dropdown card (watts on the lines); `.large` is the main window (watts in the nodes).
struct PowerFlowView: View {
    enum Style {
        case compact
        case large(batteryValue: String, batteryCaption: String)
    }

    let flow: PowerPresentation.Flow
    var style: Style = .compact

    var body: some View {
        switch style {
        case .compact:
            compact
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        case let .large(batteryValue, batteryCaption):
            large(batteryValue: batteryValue, caption: batteryCaption)
        }
    }

    private var adapterColor: Color { flow.adapterActive ? Theme.adapter : Theme.inactive }

    private var compact: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                FlowNode(symbol: "powerplug", label: "어댑터", tint: Theme.adapter, size: .compact)
                    .opacity(flow.adapterActive ? 1 : 0.45)
                FlowSegment(text: flow.adapterText, color: adapterColor, dashed: !flow.adapterActive)
                junction(10)
                FlowSegment(text: flow.systemText, color: Theme.color(flow.systemLineTint), dashed: false)
                FlowNode(symbol: "laptopcomputer", label: "시스템", tint: Theme.text, size: .compact)
            }
            HStack(spacing: 10) {
                Color.clear.frame(width: 80, height: 1)
                VerticalConnector(direction: flow.vertical, length: 26)
                    .frame(width: 12)
                Text(flow.batteryText)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 80, alignment: .leading)
            }
            FlowNode(symbol: "battery.100", label: "배터리", tint: Theme.battery, size: .compact)
        }
    }

    private func large(batteryValue: String, caption: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                FlowNode(symbol: "powerplug", label: "어댑터 입력", value: flow.adapterText,
                         tint: Theme.adapter, size: .large)
                    .opacity(flow.adapterActive ? 1 : 0.45)
                FlowSegment(text: nil, color: adapterColor, dashed: !flow.adapterActive)
                    .padding(.horizontal, 2)
                junction(12)
                FlowSegment(text: nil, color: Theme.color(flow.systemLineTint), dashed: false)
                    .padding(.horizontal, 2)
                FlowNode(symbol: "laptopcomputer", label: "시스템 소비", value: flow.systemText,
                         tint: Theme.text, size: .large)
            }
            HStack(spacing: 12) {
                Color.clear.frame(width: 120, height: 1)
                VerticalConnector(direction: flow.vertical, length: 30)
                    .frame(width: 12)
                Text(caption)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 120, alignment: .leading)
            }
            FlowNode(symbol: "battery.100", label: "배터리", value: batteryValue, tint: Theme.battery, size: .large)
        }
    }

    private func junction(_ size: CGFloat) -> some View {
        Circle()
            .fill(Theme.color(flow.junctionTint))
            .frame(width: size, height: size)
    }
}

private struct FlowNode: View {
    enum Size {
        case compact, large

        var width: CGFloat { self == .compact ? 76 : 112 }
        var circle: CGFloat { self == .compact ? 30 : 40 }
        var symbol: CGFloat { self == .compact ? 14 : 18 }
        var label: CGFloat { self == .compact ? 11 : 12 }
        var spacing: CGFloat { self == .compact ? 4 : 6 }
        var padding: CGFloat { self == .compact ? 10 : 14 }
        var radius: CGFloat { self == .compact ? 10 : 12 }
    }

    let symbol: String
    let label: String
    var value: String?
    let tint: Color
    let size: Size

    var body: some View {
        VStack(spacing: size.spacing) {
            Image(systemName: symbol)
                .font(.system(size: size.symbol, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size.circle, height: size.circle)
                .background(tint.opacity(tint == Theme.text ? 0.10 : 0.16), in: Circle())
            Text(label)
                .font(.system(size: size.label))
                .foregroundStyle(Theme.secondaryText)
            if let value {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .padding(.vertical, size.padding)
        .frame(width: size.width)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: size.radius))
        .overlay(RoundedRectangle(cornerRadius: size.radius).stroke(Theme.border))
    }
}

private struct FlowSegment: View {
    let text: String?
    let color: Color
    let dashed: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let text {
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
            }
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
    let length: CGFloat

    var body: some View {
        let color = direction == .idle ? Theme.inactive : Theme.battery
        VStack(spacing: 0) {
            if direction == .up { chevron("chevron.up", color) }
            Line(axis: .vertical)
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: direction == .idle ? [4, 3] : []))
                .frame(width: 2, height: length)
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
