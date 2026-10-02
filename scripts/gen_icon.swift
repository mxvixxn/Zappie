#!/usr/bin/env swift
// Generate the Zappie app icon layers for Icon Composer, plus a flat preview.
//
// Concept: a lightning bolt split along its own zigzag into two pieces —
// adapter lavender on top, battery emerald below — the adapter → battery flow the app shows.
// Layers stay flat (no baked gloss) so macOS can apply Liquid Glass to the `.icon`.
//
// Run from the repo root:  swift scripts/gen_icon.swift
import AppKit

let size = 1024
let iconDir = "Zappie/Zappie.icon"
let previewPath = "docs/app-icon.png"

// Design tokens (docs/SPEC.md §4)
let adapterLavender = NSColor(srgbRed: 0x96 / 255, green: 0x7C / 255, blue: 0xEC / 255, alpha: 1)
let batteryEmerald = NSColor(srgbRed: 0x0F / 255, green: 0xAA / 255, blue: 0x7B / 255, alpha: 1)
let backgroundTop = NSColor(srgbRed: 44 / 255, green: 44 / 255, blue: 50 / 255, alpha: 1)
let backgroundBottom = NSColor(srgbRed: 16 / 255, green: 16 / 255, blue: 19 / 255, alpha: 1)

// Bolt from the design's 24-unit glyph: M13 2 4 14h7l-1 8 9-12h-7z.
// The line through its inner zigzag edge (11,14)–(12,10) splits it into an upper and a lower piece.
let bolt: [CGPoint] = [.init(x: 13, y: 2), .init(x: 4, y: 14), .init(x: 11, y: 14),
                       .init(x: 10, y: 22), .init(x: 19, y: 10), .init(x: 12, y: 10)]
let cut = (CGPoint(x: 11, y: 14), CGPoint(x: 12, y: 10))
let upperReference = CGPoint(x: 4, y: 14)
let lowerReference = CGPoint(x: 19, y: 10)

let glyphHeight = 0.60 * Double(size)   // bolt spans y 2…22 (20 units)
let scale = glyphHeight / 20
let cornerRounding = 0.9 * scale         // stroke width that rounds the bolt's corners
let gapWidth = 0.45 * scale              // transparent gap between the two pieces

/// Glyph units → canvas pixels, centered, with CoreGraphics' flipped y.
func canvas(_ p: CGPoint) -> CGPoint {
    let cx = 11.5, cy = 12.0
    return CGPoint(x: Double(size) / 2 + (p.x - cx) * scale,
                   y: Double(size) / 2 - (p.y - cy) * scale)
}

func render(_ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(path)")
}

func drawBackground(_ ctx: CGContext) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [backgroundTop.cgColor, backgroundBottom.cgColor] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
}

func drawBolt(_ ctx: CGContext, _ color: NSColor) {
    let path = CGMutablePath()
    path.addLines(between: bolt.map(canvas))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(color.cgColor)
    ctx.fillPath()
    ctx.addPath(path)
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(cornerRounding)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

/// Clips to the side of the cut line that contains `reference`, shrunk by half the gap.
func clipToSide(_ ctx: CGContext, of reference: CGPoint) {
    let a = canvas(cut.0), b = canvas(cut.1), r = canvas(reference)
    let dx = b.x - a.x, dy = b.y - a.y
    let len = (dx * dx + dy * dy).squareRoot()
    let ux = dx / len, uy = dy / len
    var nx = -uy, ny = ux
    if (r.x - a.x) * nx + (r.y - a.y) * ny < 0 { nx = -nx; ny = -ny }
    let far = Double(size) * 2, half = gapWidth / 2
    let p0 = CGPoint(x: a.x - ux * far + nx * half, y: a.y - uy * far + ny * half)
    let p1 = CGPoint(x: a.x + ux * far + nx * half, y: a.y + uy * far + ny * half)
    let path = CGMutablePath()
    path.addLines(between: [p0, p1,
                            CGPoint(x: p1.x + nx * far, y: p1.y + ny * far),
                            CGPoint(x: p0.x + nx * far, y: p0.y + ny * far)])
    path.closeSubpath()
    ctx.addPath(path)
    ctx.clip()
}

func piece(_ reference: CGPoint, _ color: NSColor) -> NSBitmapImageRep {
    render { ctx in
        clipToSide(ctx, of: reference)
        drawBolt(ctx, color)
    }
}

// Icon Composer layers
save(render(drawBackground), "\(iconDir)/Assets/background.png")
let upper = piece(upperReference, adapterLavender)
let lower = piece(lowerReference, batteryEmerald)
save(upper, "\(iconDir)/Assets/bolt-adapter.png")
save(lower, "\(iconDir)/Assets/bolt-battery.png")

let iconJSON = """
{
  "fill" : {
    "automatic-gradient" : "extended-srgb:0.11765,0.11765,0.12549,1.00000"
  },
  "groups" : [
    {
      "layers" : [
        { "image-name" : "bolt-adapter.png", "name" : "bolt-adapter" },
        { "image-name" : "bolt-battery.png", "name" : "bolt-battery" }
      ],
      "shadow" : { "kind" : "layer-color", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.3 }
    },
    {
      "layers" : [
        { "image-name" : "background.png", "name" : "background" }
      ]
    }
  ],
  "supported-platforms" : {
    "squares" : "shared"
  }
}
"""
try! iconJSON.write(toFile: "\(iconDir)/icon.json", atomically: true, encoding: .utf8)
print("wrote \(iconDir)/icon.json")

// Flat preview for the README: layers composited inside the macOS rounded-square mask.
let preview = render { ctx in
    let inset = 0.098 * Double(size)          // macOS icon grid: artwork inside ~824 pt of 1024
    let rect = CGRect(x: inset, y: inset, width: Double(size) - inset * 2, height: Double(size) - inset * 2)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil))
    ctx.clip()
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.minY)
    ctx.scaleBy(x: rect.width / Double(size), y: rect.height / Double(size))
    drawBackground(ctx)
    for layer in [upper, lower] {
        ctx.draw(layer.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    ctx.restoreGState()
}
save(preview, previewPath)
