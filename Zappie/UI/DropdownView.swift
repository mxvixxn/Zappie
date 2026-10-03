import SwiftUI

struct DropdownView: View {
    let monitor: PowerMonitor
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppSettings.sectionKey) private var section: MainSection = .overview

    var body: some View {
        VStack(spacing: 12) {
            if let snapshot = monitor.snapshot, let state = monitor.state {
                content(PowerPresentation(snapshot: snapshot, state: state), PowerTree(snapshot: snapshot, state: state,
                                                                                    connectedSince: monitor.usbConnectedSince))
            } else {
                unsupported
            }
            footer
                .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 340)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .monospacedDigit()
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func content(_ p: PowerPresentation, _ tree: PowerTree) -> some View {
        header(p)
        PowerTreeView(tree: tree, metrics: .compact)
            .padding(10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        HStack {
            Text(p.detailLabel).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(p.detailValue).fontWeight(.semibold)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 2)
    }

    private func header(_ p: PowerPresentation) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("전원").font(.system(size: 15, weight: .semibold))
                Text(p.source).font(.system(size: 12)).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Badge(text: p.badge, tint: p.badgeTint)
            Text(p.percent).font(.system(size: 22, weight: .semibold))
        }
        .padding([.horizontal, .top], 2)
    }

    private var unsupported: some View {
        VStack(spacing: 8) {
            Image(systemName: "powerplug")
                .font(.system(size: 28))
                .foregroundStyle(Theme.secondaryText)
            Text(monitor.isSupported ? "전원 정보를 읽는 중…" : "지원하지 않는 기기")
                .font(.system(size: 13, weight: .semibold))
            if !monitor.isSupported {
                Text("배터리가 있는 Apple Silicon Mac에서만 동작합니다.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openWindow(id: "main")
                NSApp.activate()
            } label: {
                Label("앱에서 자세히 보기", systemImage: "macwindow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.buttonText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.adapter, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("설정…") {
                    section = .settings
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Divider()
                Button("Zappie 종료") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .frame(width: 44, height: 44)
            .accessibilityLabel("설정")
        }
    }
}
