#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

struct IconSpec {
    let filename: String
    let pixels: Int
}

let specs: [IconSpec] = [
    IconSpec(filename: "icon_16x16.png", pixels: 16),
    IconSpec(filename: "icon_16x16@2x.png", pixels: 32),
    IconSpec(filename: "icon_32x32.png", pixels: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64),
    IconSpec(filename: "icon_128x128.png", pixels: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256),
    IconSpec(filename: "icon_256x256.png", pixels: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512x512.png", pixels: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024),
]

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

func renderIconPNG(pixelSize: Int) -> Data? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
    guard let rep else { return nil }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    defer { NSGraphicsContext.restoreGraphicsState() }

    let cg = nsCtx.cgContext
    let s = CGFloat(pixelSize)
    let scale = s / 1024.0

    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.clear(CGRect(x: 0, y: 0, width: s, height: s))

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // Outer macOS icon rounded rectangle (squircle-like inset)
    let inset = 94.0 * scale
    let bodyRect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bodyRadius = 188.0 * scale
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)

    // Soft outer drop shadow
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -18.0 * scale),
        blur: 32.0 * scale,
        color: rgba(0.02, 0.04, 0.09, 0.55)
    )
    cg.addPath(bodyPath)
    cg.setFillColor(rgba(0.08, 0.11, 0.17, 1.0))
    cg.fillPath()
    cg.restoreGState()

    // Dark-slate base gradient
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()

    let baseColors = [
        rgba(0.15, 0.21, 0.31, 1.0), // Top slate #26364F
        rgba(0.07, 0.10, 0.17, 1.0)  // Bottom deep slate #121A2B
    ] as CFArray
    if let baseGrad = CGGradient(colorsSpace: colorSpace, colors: baseColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(
            baseGrad,
            start: CGPoint(x: s / 2.0, y: bodyRect.maxY),
            end: CGPoint(x: s / 2.0, y: bodyRect.minY),
            options: []
        )
    }

    // Subtle ambient cyan/indigo glow across upper-center
    let ambientColors = [
        rgba(0.22, 0.74, 0.97, 0.24),
        rgba(0.39, 0.40, 0.95, 0.10),
        rgba(0.07, 0.10, 0.17, 0.0)
    ] as CFArray
    if let ambientGrad = CGGradient(colorsSpace: colorSpace, colors: ambientColors, locations: [0.0, 0.48, 1.0]) {
        cg.drawRadialGradient(
            ambientGrad,
            startCenter: CGPoint(x: s * 0.5, y: s * 0.54),
            startRadius: 20 * scale,
            endCenter: CGPoint(x: s * 0.5, y: s * 0.50),
            endRadius: 430 * scale,
            options: []
        )
    }

    // Precision grid accent lines in dark slate
    cg.setStrokeColor(rgba(0.58, 0.74, 0.95, 0.06))
    cg.setLineWidth(max(1.0, 2.0 * scale))
    let step = 128.0 * scale
    var x = bodyRect.minX + step
    while x < bodyRect.maxX {
        cg.move(to: CGPoint(x: x, y: bodyRect.minY))
        cg.addLine(to: CGPoint(x: x, y: bodyRect.maxY))
        x += step
    }
    var y = bodyRect.minY + step
    while y < bodyRect.maxY {
        cg.move(to: CGPoint(x: bodyRect.minX, y: y))
        cg.addLine(to: CGPoint(x: bodyRect.maxX, y: y))
        y += step
    }
    cg.strokePath()
    cg.restoreGState()

    // Outer metallic slate rim highlight
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.setStrokeColor(rgba(0.65, 0.78, 0.96, 0.24))
    cg.setLineWidth(max(1.0, 4.0 * scale))
    cg.strokePath()
    cg.restoreGState()

    // Keycap base skirt (3D physical key depth)
    let capWidth = 548.0 * scale
    let capHeight = 548.0 * scale
    let capX = (s - capWidth) / 2.0
    let capY = (s - capHeight) / 2.0 - 12.0 * scale
    let skirtRect = CGRect(x: capX, y: capY - 24.0 * scale, width: capWidth, height: capHeight + 12.0 * scale)
    let skirtRadius = 118.0 * scale
    let skirtPath = CGPath(roundedRect: skirtRect, cornerWidth: skirtRadius, cornerHeight: skirtRadius, transform: nil)

    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -20.0 * scale),
        blur: 36.0 * scale,
        color: rgba(0.01, 0.02, 0.06, 0.72)
    )
    cg.addPath(skirtPath)
    cg.setFillColor(rgba(0.06, 0.09, 0.15, 1.0))
    cg.fillPath()
    cg.restoreGState()

    // Sculpted Keycap top face
    let faceRect = CGRect(x: capX + 16.0 * scale, y: capY + 18.0 * scale, width: capWidth - 32.0 * scale, height: capHeight - 32.0 * scale)
    let faceRadius = 96.0 * scale
    let facePath = CGPath(roundedRect: faceRect, cornerWidth: faceRadius, cornerHeight: faceRadius, transform: nil)

    cg.saveGState()
    cg.addPath(facePath)
    cg.clip()

    let faceColors = [
        rgba(0.22, 0.29, 0.42, 1.0), // Top bevel light #384A6B
        rgba(0.13, 0.18, 0.28, 1.0)  // Lower key face #212E47
    ] as CFArray
    if let faceGrad = CGGradient(colorsSpace: colorSpace, colors: faceColors, locations: [0.0, 1.0]) {
        cg.drawLinearGradient(
            faceGrad,
            start: CGPoint(x: faceRect.midX, y: faceRect.maxY),
            end: CGPoint(x: faceRect.midX, y: faceRect.minY),
            options: []
        )
    }

    // Subtle cyan inner halo under the ⌘ glyph
    let haloColors = [
        rgba(0.35, 0.80, 1.0, 0.30),
        rgba(0.35, 0.80, 1.0, 0.0)
    ] as CFArray
    if let haloGrad = CGGradient(colorsSpace: colorSpace, colors: haloColors, locations: [0.0, 1.0]) {
        cg.drawRadialGradient(
            haloGrad,
            startCenter: CGPoint(x: faceRect.midX, y: faceRect.midY),
            startRadius: 10.0 * scale,
            endCenter: CGPoint(x: faceRect.midX, y: faceRect.midY),
            endRadius: 215.0 * scale,
            options: []
        )
    }
    cg.restoreGState()

    // Keycap top rim highlight
    cg.saveGState()
    cg.addPath(facePath)
    cg.setStrokeColor(rgba(0.56, 0.82, 1.0, 0.42))
    cg.setLineWidth(max(1.0, 4.5 * scale))
    cg.strokePath()
    cg.restoreGState()

    // Glowing ⌘ glyph centered on keycap face
    let glyphText = "⌘" as NSString
    let fontSize = 278.0 * scale
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedRed: 0.22, green: 0.78, blue: 1.0, alpha: 0.85)
    shadow.shadowBlurRadius = 26.0 * scale
    shadow.shadowOffset = .zero

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.94, green: 0.98, blue: 1.0, alpha: 1.0),
        .paragraphStyle: paragraph,
        .shadow: shadow
    ]

    let textSize = glyphText.size(withAttributes: attrs)
    let textRect = CGRect(
        x: faceRect.midX - textSize.width / 2.0,
        y: faceRect.midY - textSize.height / 2.0 + 4.0 * scale,
        width: textSize.width,
        height: textSize.height
    )
    glyphText.draw(in: textRect, withAttributes: attrs)

    return rep.representation(using: .png, properties: [:])
}

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fm = FileManager.default

try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let tempRoot = fm.temporaryDirectory.appendingPathComponent("keymapstudio-icon-\(UUID().uuidString)")
let iconsetURL = tempRoot.appendingPathComponent("AppIcon.iconset")
try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: tempRoot) }

for spec in specs {
    guard let pngData = renderIconPNG(pixelSize: spec.pixels) else {
        fputs("error: failed to render \(spec.filename)\n", stderr)
        exit(1)
    }
    try pngData.write(to: iconsetURL.appendingPathComponent(spec.filename), options: .atomic)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("error: iconutil exited with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}

print("Generated app icon: \(outputURL.path)")
