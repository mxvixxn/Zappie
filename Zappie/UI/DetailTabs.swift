import SwiftUI

/// Shared page chrome for the non-overview tabs.
struct TabPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title).font(.system(size: 22, weight: .bold))
                content
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HistoryTab: View {
    let monitor: PowerMonitor

    var body: some View {
        TabPage(title: "기록") {
            HistoryChartCard(history: monitor.history, chartHeight: 320, showsSummary: true)
            Text("기록은 메모리에만 보관되며 앱을 종료하면 사라집니다.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

struct AdapterTab: View {
    let monitor: PowerMonitor

    var body: some View {
        TabPage(title: "어댑터") {
            let rows = monitor.snapshot.map(DetailRows.adapter) ?? []
            if rows.isEmpty {
                Card("어댑터 정보") {
                    Text("어댑터가 연결되어 있지 않습니다.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                DetailList(title: "어댑터 정보", rows: rows)
            }
        }
    }
}

struct BatteryTab: View {
    let monitor: PowerMonitor

    var body: some View {
        TabPage(title: "배터리") {
            if let s = monitor.snapshot, let state = monitor.state {
                Card("센서") {
                    BatteryTiles(tiles: OverviewPresentation(snapshot: s, state: state).batteryTiles)
                }
                DetailList(title: "용량과 전력", rows: DetailRows.battery(s, state: state))
            }
        }
    }
}

struct SettingsTab: View {
    let monitor: PowerMonitor
    @AppStorage(AppSettings.pollIntervalKey) private var pollInterval = 1
    @AppStorage(AppSettings.labelStyleKey) private var labelStyle = MenuBarLabelStyle.watts
    @AppStorage(AppSettings.liveWattsKey) private var liveWatts = true
    @AppStorage(AppSettings.heatAlertsKey) private var heatAlerts = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        TabPage(title: "설정") {
            Card("일반") {
                VStack(alignment: .leading, spacing: 16) {
                    setting("실시간 전력", note: liveWattsNote) {
                        if monitor.liveWattsCheck.disabled {
                            Button("다시 켜기") { monitor.resetLiveWattsCheck() }
                        } else {
                            Toggle("실시간 전력", isOn: $liveWatts)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }
                    Divider().overlay(Theme.border)
                    setting("갱신 주기", note: liveWatts ? nil : "배터리 드라이버 자체의 갱신 간격(1~60초)보다 빨라지지는 않습니다.") {
                        Picker("갱신 주기", selection: $pollInterval) {
                            ForEach(AppSettings.pollIntervals, id: \.self) { Text("\($0)초").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    Divider().overlay(Theme.border)
                    setting("메뉴 막대 표시") {
                        Picker("메뉴 막대 표시", selection: $labelStyle) {
                            ForEach(MenuBarLabelStyle.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    Divider().overlay(Theme.border)
                    setting("온도 경고 알림", note: "배터리가 40 °C를 넘으면 알립니다(45 °C 이상은 높은 경고). 같은 경고는 30분에 한 번만 보냅니다. Zappie는 충전을 직접 멈추지 않습니다.") {
                        Toggle("온도 경고 알림", isOn: $heatAlerts)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    Divider().overlay(Theme.border)
                    setting("로그인 시 실행", note: loginError) {
                        Toggle("로그인 시 실행", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            .frame(maxWidth: 640)
        }
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                try LaunchAtLogin.set(enabled)
                loginError = nil
            } catch {
                loginError = "설정하지 못했습니다: \(error.localizedDescription)"
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    private var liveWattsNote: String {
        let check = monitor.liveWattsCheck
        if check.disabled {
            return "이 Mac에서는 SMC 값이 배터리 드라이버 값과 맞지 않아 자동으로 꺼졌습니다. 드라이버 값(1~60초 간격)을 씁니다."
        }
        guard liveWatts else { return "끄면 배터리 드라이버 값(1~60초 간격)을 씁니다." }
        let verified = check.matches > 0 ? " · 드라이버 값과 \(check.matches)회 일치 확인" : " · 드라이버 값과 비교 중"
        return "SMC 센서에서 와트를 약 1.5초마다 읽습니다" + verified
    }

    private func setting<Control: View>(_ title: String, note: String? = nil,
                                        @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let note {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            control()
        }
    }
}

struct DetailList: View {
    let title: String
    let rows: [DetailRow]

    var body: some View {
        Card(title) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(Theme.border) }
                    HStack {
                        Text(row.label).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text(row.value).fontWeight(.semibold).textSelection(.enabled)
                    }
                    .font(.system(size: 13))
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: 640)
    }
}

/// Six tiles in one row when they fit untruncated, otherwise two rows of three.
struct BatteryTiles: View {
    let tiles: [OverviewPresentation.Tile]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ForEach(tiles, id: \.label) { tile($0) }
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(Array(stride(from: 0, to: tiles.count, by: 3)), id: \.self) { start in
                    GridRow {
                        ForEach(tiles[start..<min(start + 3, tiles.count)], id: \.label) { tile($0) }
                    }
                }
            }
        }
    }

    private func tile(_ tile: OverviewPresentation.Tile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tile.label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize()
            Text(tile.value)
                .font(.system(size: 15, weight: .semibold))
                .fixedSize()
        }
        .frame(minWidth: 72, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
    }
}
