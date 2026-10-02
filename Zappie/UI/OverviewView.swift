import SwiftUI

struct OverviewView: View {
    let monitor: PowerMonitor
    /// `ImageRenderer` draws ScrollView contents blank, so render snapshots turn scrolling off.
    var scrolls = true

    private let gap: CGFloat = 18

    var body: some View {
        if let snapshot = monitor.snapshot, let state = monitor.state {
            GeometryReader { geo in
                let page = content(snapshot, state, column: (geo.size.width - 56 - gap * 2) / 3)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                if scrolls {
                    ScrollView { page }
                } else {
                    page
                }
            }
        } else {
            Text(monitor.isSupported ? "전원 정보를 읽는 중…" : "지원하지 않는 기기입니다. 배터리가 있는 Apple Silicon Mac에서만 동작합니다.")
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func content(_ s: PowerSnapshot, _ state: PowerState, column: CGFloat) -> some View {
        let p = PowerPresentation(snapshot: s, state: state)
        let o = OverviewPresentation(snapshot: s, state: state)
        let wide = column * 2 + gap

        return VStack(alignment: .leading, spacing: gap) {
            header(p, updated: s.updateTime)

            HStack(alignment: .top, spacing: gap) {
                Card("전력 흐름") {
                    PowerFlowView(flow: p.flow, style: .large(batteryValue: p.percent, batteryCaption: o.batteryCaption))
                }
                .frame(width: wide)
                compositionCard(o.composition, p)
                    .frame(width: column)
            }
            .fixedSize(horizontal: false, vertical: true)

            historyCard

            HStack(alignment: .top, spacing: gap) {
                adapterCard(o.adapter)
                    .frame(width: column)
                batteryCard(o.batteryTiles)
                    .frame(width: wide)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func header(_ p: PowerPresentation, updated: Date?) -> some View {
        HStack {
            Text("개요").font(.system(size: 22, weight: .bold))
            Badge(text: p.badge, tint: p.badgeTint, size: 12)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Format.updatedAgo(updated, now: context.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func compositionCard(_ c: OverviewPresentation.Composition?, _ p: PowerPresentation) -> some View {
        Card("입력 전력 구성", trailing: c?.totalText) {
            VStack(alignment: .leading, spacing: 14) {
                if let c {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(c.rows, id: \.label) { row in
                                Rectangle()
                                    .fill(row.tint.map(Theme.color) ?? Theme.loss)
                                    .frame(width: geo.size.width * row.fraction)
                            }
                            Spacer(minLength: 0)
                        }
                        .background(Theme.border)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .frame(height: 12)

                    VStack(spacing: 10) {
                        ForEach(c.rows, id: \.label) { row in
                            HStack {
                                Circle()
                                    .fill(row.tint.map(Theme.color) ?? Theme.loss)
                                    .frame(width: 8, height: 8)
                                Text(row.label)
                                Spacer()
                                Text(row.valueText).fontWeight(.semibold)
                            }
                        }
                    }
                    .font(.system(size: 13))
                } else {
                    Text("어댑터가 연결되어 있지 않습니다.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)
                Divider().overlay(Theme.border)
                HStack {
                    Text(p.detailLabel).foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(p.detailValue).fontWeight(.semibold)
                }
                .font(.system(size: 12))
            }
        }
    }

    private var historyCard: some View {
        Card("전력 기록") {
            Text("기록을 모으는 중…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 150)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func adapterCard(_ a: OverviewPresentation.Adapter?) -> some View {
        Card("어댑터") {
            if let a {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.ratedText).font(.system(size: 24, weight: .bold))
                        Spacer()
                        Text(a.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                    VStack(spacing: 6) {
                        keyValue("정격 대비 사용", a.usageText)
                        GeometryReader { geo in
                            Capsule().fill(Theme.border)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Theme.adapter).frame(width: geo.size.width * a.usageFraction)
                                }
                        }
                        .frame(height: 6)
                    }
                    keyValue("협상 전압 × 전류", a.negotiatedText)
                    keyValue("어댑터 손실", a.lossText)
                }
            } else {
                Text("연결 안 됨")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func batteryCard(_ tiles: [OverviewPresentation.Tile]) -> some View {
        Card("배터리") {
            HStack(spacing: 10) {
                ForEach(tiles, id: \.label) { tile in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tile.label).font(.system(size: 11)).foregroundStyle(Theme.secondaryText)
                        Text(tile.value).font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.system(size: 12))
    }
}

struct Card<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder let content: Content

    init(_ title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                if let trailing {
                    Text(trailing).font(.system(size: 15, weight: .semibold))
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}

struct Badge: View {
    let text: String
    let tint: Tint
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.badgeText(tint))
            .padding(.horizontal, size == 11 ? 9 : 10)
            .padding(.vertical, size == 11 ? 3 : 4)
            .background(Theme.color(tint).opacity(0.16), in: Capsule())
    }
}
