import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case overview = "개요"
    case history = "기록"
    case adapter = "어댑터"
    case battery = "배터리"
    case settings = "설정"

    var id: Self { self }
}

struct MainWindow: View {
    let monitor: PowerMonitor
    var scrolls = true
    @AppStorage(AppSettings.sectionKey) private var section: MainSection = .overview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.divider).frame(width: 1)
            Group {
                switch section {
                case .overview: OverviewView(monitor: monitor, scrolls: scrolls)
                case .history: HistoryTab(monitor: monitor)
                case .adapter: AdapterTab(monitor: monitor)
                case .battery: BatteryTab(monitor: monitor)
                case .settings: SettingsTab(monitor: monitor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .monospacedDigit()
        .preferredColorScheme(.dark)
        .frame(minWidth: 960, minHeight: 760)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(MainSection.allCases) { item in
                let selected = item == section
                Button {
                    section = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.text : Theme.sidebarText)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .background(selected ? Theme.adapter.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .frame(width: 200)
        .background(Theme.sidebar)
    }
}
