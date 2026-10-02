import Charts
import SwiftUI

/// "전력 기록": adapter input and system load over 1 h / 6 h / 24 h.
struct HistoryChartCard: View {
    let history: PowerHistory
    var now: Date = .now
    @State private var range: HistoryRange = .hour

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("전력 기록")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 14) {
                    legend("어댑터 입력", Theme.adapter)
                    legend("시스템 소비", Theme.systemLine)
                }
                .padding(.leading, 4)
                Spacer()
                rangePicker
            }

            let samples = visibleSamples
            if samples.isEmpty {
                Text("기록을 모으는 중…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                HistoryChart(samples: samples, range: range, now: now)
                    .frame(height: 170)
            }
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }

    private var visibleSamples: [PowerSample] {
        let start = now.addingTimeInterval(-range.duration)
        return history.samples(range).filter { $0.date >= start }
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 12, height: 2)
            Text(label)
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.secondaryText)
    }

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryRange.allCases) { item in
                let selected = item == range
                Button {
                    range = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.text : Theme.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(selected ? Theme.border : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
    }
}

private struct HistoryChart: View {
    let samples: [PowerSample]
    let range: HistoryRange
    let now: Date
    @State private var hovered: Date?

    private enum Series: String, Plottable {
        case input = "어댑터 입력"
        case system = "시스템 소비"
    }

    var body: some View {
        let start = now.addingTimeInterval(-range.duration)
        let axisDates = [start, now.addingTimeInterval(-range.duration / 2), now]

        Chart {
            ForEach(samples, id: \.date) { s in
                LineMark(x: .value("시간", s.date), y: .value("전력", s.inputW), series: .value("항목", Series.input))
                    .foregroundStyle(Theme.adapter)
                LineMark(x: .value("시간", s.date), y: .value("전력", s.systemW), series: .value("항목", Series.system))
                    .foregroundStyle(Theme.systemLine)
            }
            .lineStyle(StrokeStyle(lineWidth: 2))

            if let point = nearest {
                RuleMark(x: .value("시간", point.date))
                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(point)
                    }
                PointMark(x: .value("시간", point.date), y: .value("전력", point.inputW))
                    .foregroundStyle(Theme.adapter)
                    .symbolSize(40)
                PointMark(x: .value("시간", point.date), y: .value("전력", point.systemW))
                    .foregroundStyle(Theme.systemLine)
                    .symbolSize(40)
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: start...now)
        .chartYScale(domain: 0...HistoryRange.yAxisMax(for: samples))
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                if let index = value.index as Int?, index < range.axisLabels.count {
                    AxisValueLabel(anchor: anchor(index)) {
                        Text(range.axisLabels[index])
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel {
                    if let w = value.as(Double.self) {
                        Text("\(Int(w)) W")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
            }
        }
        .chartXSelection(value: $hovered)
        .chartPlotStyle { $0.clipped() }
    }

    private var nearest: PowerSample? {
        guard let hovered else { return nil }
        return samples.min { abs($0.date.timeIntervalSince(hovered)) < abs($1.date.timeIntervalSince(hovered)) }
    }

    private func anchor(_ index: Int) -> UnitPoint {
        switch index {
        case 0: .topLeading
        case 2: .topTrailing
        default: .top
        }
    }

    private func tooltip(_ s: PowerSample) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.date, format: .dateTime.hour().minute().second())
                .foregroundStyle(Theme.secondaryText)
            row("어댑터 입력", s.inputW, Theme.adapter)
            row("시스템 소비", s.systemW, Theme.systemLine)
        }
        .font(.system(size: 11))
        .monospacedDigit()
        .padding(8)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
    }

    private func row(_ label: String, _ w: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 8)
            Text(Format.watts(w)).fontWeight(.semibold).foregroundStyle(Theme.text)
        }
    }
}
