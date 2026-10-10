#!/usr/bin/env swift
// Generate the Zappie app icon layers for Icon Composer, plus a flat preview.
//
// Design (v2, from docs/icon-source/chatgpt-reference.png): a lightning bolt made of two rounded
// pieces that meet along the bolt's zigzag — lavender→violet on top (power from the charger),
// mint→teal below (power into the battery) — on a near-black navy with violet corner glow.
// Pieces are separate transparent layers so macOS applies Liquid Glass to each; no frame, shadow
// or highlight is baked in.
//
// Run from the repo root:  swift scripts/gen_icon.swift
import AppKit

let size = 1024
let iconDir = "Zappie/Zappie.icon"
let previewPath = "docs/app-icon.png"

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Colors sampled from the reference
let upperTop = rgb(0xEEE2FF), upperBottom = rgb(0x7656F6)
let lowerTop = rgb(0xC4FFF1), lowerBottom = rgb(0x14CEC6)
let backgroundBase = rgb(0x0B0C1E)
let glow = rgb(0x6E3CFF)

// MARK: - Geometry (reference image units, 1254 px canvas; mapped onto 1024 below)

struct Circle { var x: Double; var y: Double; var r: Double }

// Where the two pieces meet: the bolt's middle zigzag.
let joinTop = CGPoint(x: 787, y: 520)
let joinBottom = CGPoint(x: 600, y: 748)
// Rounded outer ends
let upperRight = Circle(x: 862, y: 228, r: 112)
let upperLeft = Circle(x: 292, y: 584, r: 112)
let lowerRight = Circle(x: 982, y: 648, r: 104)
let lowerTip = Circle(x: 448, y: 1058, r: 74)

let glyphBounds = CGRect(x: 180, y: 105, width: 910, height: 1025)
let glyphHeight = 0.76 * Double(size) // bold like the reference, still clear of the mask edge
let scale = glyphHeight / glyphBounds.height

/// Reference units → canvas pixels, centered, with CoreGraphics' flipped y.
func canvas(_ p: CGPoint) -> CGPoint {
    CGPoint(x: Double(size) / 2 + (p.x - glyphBounds.midX) * scale,
            y: Double(size) / 2 - (p.y - glyphBounds.midY) * scale)
}

/// Convex hull of rounded ends and sharp corners: the piece's outline.
func piece(circles: [Circle], points: [CGPoint]) -> CGPath {
    var cloud = points
    for c in circles {
        for i in 0..<180 {
            let a = Double(i) / 180 * 2 * .pi
            cloud.append(CGPoint(x: c.x + c.r * cos(a), y: c.y + c.r * sin(a)))
        }
    }
    let mapped: [CGPoint] = cloud.map(canvas).sorted { (a: CGPoint, b: CGPoint) -> Bool in
        if a.x != b.x { return a.x < b.x }
        return a.y < b.y
    }
    func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
    var lower: [CGPoint] = [], upper: [CGPoint] = []
    for p in mapped {
        while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
        lower.append(p)
    }
    for p in mapped.reversed() {
        while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
        upper.append(p)
    }
    let path = CGMutablePath()
    path.addLines(between: Array(lower.dropLast() + upper.dropLast()))
    path.closeSubpath()
    return path
}

let upperPath = piece(circles: [upperRight, upperLeft], points: [joinTop, joinBottom])
let lowerPath = piece(circles: [lowerRight, lowerTip], points: [joinTop, joinBottom])

// MARK: - Rendering

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

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func drawBackground(_ ctx: CGContext) {
    ctx.setFillColor(backgroundBase)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    // Violet glow from the top-left and bottom-right corners.
    let clear = glow.copy(alpha: 0)!
    let g = CGGradient(colorsSpace: space, colors: [glow.copy(alpha: 1)!, glow.copy(alpha: 0.4)!, clear] as CFArray,
                       locations: [0, 0.35, 1])!
    let r = Double(size) * 0.7
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: 0, y: size), startRadius: 0,
                           endCenter: CGPoint(x: 0, y: size), endRadius: r, options: [])
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: size, y: 0), startRadius: 0,
                           endCenter: CGPoint(x: size, y: 0), endRadius: r, options: [])
}

/// Piece fill opacity: below 1 so the Liquid Glass material shows through and carries the color.
let pieceOpacity = 0.86

func drawPiece(_ ctx: CGContext, _ path: CGPath, top: CGColor, bottom: CGColor) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.setAlpha(pieceOpacity)
    let box = path.boundingBox
    let g = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    // Light from the top-left, like the reference.
    ctx.drawLinearGradient(g, start: CGPoint(x: box.minX + box.width * 0.35, y: box.maxY),
                           end: CGPoint(x: box.minX + box.width * 0.55, y: box.minY), options: [])
    ctx.restoreGState()
}

let background = render(drawBackground)
let upper = render { drawPiece($0, upperPath, top: upperTop, bottom: upperBottom) }
let lower = render { drawPiece($0, lowerPath, top: lowerTop, bottom: lowerBottom) }

// Remove layers from earlier designs.
for old in ["bolt-adapter.png", "bolt-battery.png"] {
    try? FileManager.default.removeItem(atPath: "\(iconDir)/Assets/\(old)")
}
save(background, "\(iconDir)/Assets/background.png")
save(upper, "\(iconDir)/Assets/bolt-upper.png")
save(lower, "\(iconDir)/Assets/bolt-lower.png")

// Glass settings tuned in Icon Composer (blur 35%, refraction 100% / depth 60%, translucency 45%, shadow 70%);
// keep in sync.
let iconJSON = """
{
  "features" : [
    "refractivity"
  ],
  "fill" : {
    "automatic-gradient" : "extended-srgb:0.04314,0.04706,0.11765,1.00000"
  },
  "groups" : [
    {
      "blur-material" : 0.35,
      "layers" : [
        {
          "glass" : true,
          "image-name" : "bolt-upper.png",
          "name" : "bolt-upper"
        },
        {
          "glass" : true,
          "image-name" : "bolt-lower.png",
          "name" : "bolt-lower"
        }
      ],
      "refractivity" : {
        "depth" : 0.6,
        "enabled" : true,
        "strength" : 1
      },
      "shadow" : {
        "kind" : "layer-color",
        "opacity" : 0.7
      },
      "specular" : true,
      "translucency" : {
        "enabled" : true,
        "value" : 0.45
      }
    },
    {
      "layers" : [
        {
          "image-name" : "background.png",
          "name" : "background"
        }
      ],
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "translucency" : {
        "enabled" : true,
        "value" : 0.3
      }
    }
  ],
  "supported-platforms" : {
    "squares" : "shared"
  }
}
"""
try! iconJSON.write(toFile: "\(iconDir)/icon.json", atomically: true, encoding: .utf8)
print("wrote \(iconDir)/icon.json")

// Flat preview for the README: layers inside the macOS rounded-square mask (no glass).
let preview = render { ctx in
    let inset = 0.098 * Double(size)
    let rect = CGRect(x: inset, y: inset, width: Double(size) - inset * 2, height: Double(size) - inset * 2)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225,
                       transform: nil))
    ctx.clip()
    ctx.translateBy(x: rect.minX, y: rect.minY)
    ctx.scaleBy(x: rect.width / Double(size), y: rect.height / Double(size))
    for layer in [background, lower, upper] {
        ctx.draw(layer.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
}
save(preview, previewPath)
