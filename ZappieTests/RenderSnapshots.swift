import AppKit
import SwiftUI
import Testing
@testable import Zappie

/// Writes PNGs of the dropdown in each state for visual review against the design.
/// Opt-in: `TEST_RUNNER_ZAPPIE_RENDER_DIR=/path scripts/test.sh`
@MainActor
struct RenderSnapshots {
    nonisolated static let outputDir = ProcessInfo.processInfo.environment["ZAPPIE_RENDER_DIR"]

    static let cases: [(String, PowerSnapshot)] = [
        ("charging", PowerSnapshot(isExternalConnected: true, adapterInW: 45.2, systemLoadW: 12.3, batteryW: 31.4,
                                   percent: 62, timeToFullMin: 24)),
        ("hold", PowerSnapshot(isExternalConnected: true, adapterInW: 12.3, systemLoadW: 12.3, batteryW: 0, percent: 80)),
        ("battery", PowerSnapshot(isExternalConnected: false, adapterInW: 0, systemLoadW: 11.8, batteryW: -11.8,
                                  percent: 80, timeToEmptyMin: 290)),
        ("assisted", PowerSnapshot(isExternalConnected: true, adapterInW: 30, systemLoadW: 38, batteryW: -8,
                                   percent: 55, timeToEmptyMin: 400)),
    ]

    @Test(.enabled(if: outputDir != nil)) func renderDropdowns() throws {
        let dir = URL(fileURLWithPath: try #require(Self.outputDir))
        for (name, snapshot) in Self.cases {
            let monitor = PowerMonitor(read: { snapshot })
            monitor.refresh()
            let renderer = ImageRenderer(content: DropdownView(monitor: monitor))
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            let tiff = try #require(image.tiffRepresentation)
            let rep = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: dir.appendingPathComponent("dropdown-\(name).png"))
        }
    }

    @Test(.enabled(if: outputDir != nil)) func renderMainWindow() throws {
        let dir = URL(fileURLWithPath: try #require(Self.outputDir))
        let adapter = AdapterInfo(watts: 68, voltageV: 20, currentA: 3.39, name: "70W USB-C Power Adapter")
        var snapshot = Self.cases[0].1
        snapshot.adapter = adapter
        snapshot.adapterLossW = 0.233
        snapshot.batteryVoltageV = 12.71
        snapshot.batteryCurrentA = 2.47
        snapshot.temperatureC = 33.4
        snapshot.cycleCount = 66
        snapshot.designCapacitymAh = 6249
        snapshot.fullChargeCapacitymAh = 6004
        snapshot.updateTime = .now
        let monitor = PowerMonitor(read: { snapshot })
        monitor.refresh()
        let renderer = ImageRenderer(content: MainWindow(monitor: monitor, scrolls: false).frame(width: 1200, height: 908))
        renderer.scale = 1
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: dir.appendingPathComponent("main-overview.png"))
    }
}
