import AppKit

/// Renders the LeetCode menu-bar glyph, colored by status:
///
///   .plain   – RED mark        (today's challenge not solved yet)
///   .done    – GREEN mark + ✓  (today's challenge solved)
///   .error   – GRAY mark + !   (last refresh failed)
///
/// Colors are baked into the image (not a template) so the status is visible
/// at a glance in both light and dark menu bars.
enum IconState: Equatable {
    case plain, done, error
}

enum MenuIcon {

    static let pointSize = 18

    /// Cached base mark rendered from the bundled SVG.
    private static let baseMark: NSImage? = {
        guard let url = Bundle.module.url(forResource: "leetcode", withExtension: "svg"),
              let svg = NSImage(contentsOf: url) else {
            return fallbackMark()
        }
        // Render into a fixed 18x18 template canvas, centered with a small inset.
        let size = NSSize(width: pointSize, height: pointSize)
        let img = NSImage(size: size)
        img.lockFocus()
        let inset: CGFloat = 1.6
        let rect = NSRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        svg.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        img.unlockFocus()
        return img
    }()

    static let leetcodeGreen = NSColor(red: 0x6E / 255.0, green: 0xCC / 255.0, blue: 0x3A / 255.0, alpha: 1)

    static func markColor(for state: IconState) -> NSColor {
        switch state {
        case .plain: .systemRed
        case .done: leetcodeGreen
        case .error: .systemGray
        }
    }

    static func image(for state: IconState) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let img = NSImage(size: size)
        img.lockFocus()
        let fullRect = NSRect(origin: .zero, size: size)

        // 1) Draw the mark (SVG or fallback), tinted to the state color.
        let mark = baseMark ?? fallbackMark()
        mark.draw(in: fullRect, from: .zero, operation: .sourceOver, fraction: 1)
        markColor(for: state).set()
        fullRect.fill(using: .sourceAtop)

        // 2) Optional status badge.
        if state != .plain {
            drawBadge(state == .done ? .check : .exclaim, color: markColor(for: state))
        }

        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    // MARK: - Badges

    private enum Badge { case check, exclaim }

    private static func drawBadge(_ badge: Badge, color: NSColor) {
        guard let ctx = NSGraphicsContext.current else { return }
        let badgeCenter = NSPoint(x: 14.6, y: 4.2)
        let badgeRadius: CGFloat = 4.3

        // 1) Clear a ring around the badge so it separates from the mark.
        ctx.saveGraphicsState()
        ctx.cgContext.setBlendMode(.clear)
        NSBezierPath(ovalIn: NSRect(
            x: badgeCenter.x - badgeRadius - 0.9,
            y: badgeCenter.y - badgeRadius - 0.9,
            width: (badgeRadius + 0.9) * 2,
            height: (badgeRadius + 0.9) * 2
        )).fill()

        // 2) Solid badge disc (state color).
        ctx.restoreGraphicsState()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: badgeCenter.x - badgeRadius,
            y: badgeCenter.y - badgeRadius,
            width: badgeRadius * 2,
            height: badgeRadius * 2
        )).fill()

        // 3) Cut the glyph out of the disc.
        ctx.saveGraphicsState()
        ctx.cgContext.setBlendMode(.clear)
        let glyph = NSBezierPath()
        switch badge {
        case .check:
            glyph.move(to: NSPoint(x: badgeCenter.x - 2.1, y: badgeCenter.y - 0.3))
            glyph.line(to: NSPoint(x: badgeCenter.x - 0.7, y: badgeCenter.y - 1.7))
            glyph.line(to: NSPoint(x: badgeCenter.x + 2.2, y: badgeCenter.y + 1.5))
            glyph.lineWidth = 1.5
            glyph.lineCapStyle = .round
            glyph.lineJoinStyle = .round
            glyph.stroke()
        case .exclaim:
            let bar = NSBezierPath(roundedRect:
                NSRect(x: badgeCenter.x - 0.75, y: badgeCenter.y - 0.6, width: 1.5, height: 2.6),
                xRadius: 0.7, yRadius: 0.7)
            bar.fill()
            let dot = NSBezierPath(ovalIn: NSRect(x: badgeCenter.x - 0.8, y: badgeCenter.y - 2.4, width: 1.6, height: 1.6))
            dot.fill()
        }
        ctx.restoreGraphicsState()
    }

    // MARK: - Preview (CLI: leetcode-toggle --icon-preview <dir>)

    static func writePreviews(to dir: String) {
        let states: [IconState] = [.plain, .done, .error]

        // Individual icons, rendered large on a checkerboard so alpha is visible.
        for state in states {
            let canvas = NSImage(size: NSSize(width: 144, height: 144))
            canvas.lockFocus()
            checkerboard(in: NSRect(x: 0, y: 0, width: 144, height: 144))
            image(for: state).draw(in: NSRect(x: 12, y: 12, width: 120, height: 120))
            canvas.unlockFocus()
            writePNG(canvas, scale: 2, to: "\(dir)/icon-\(state).png")
        }

        // A fake menu-bar strip (dark background, icons in their real colors).
        let pointWidth: CGFloat = 30 + CGFloat(states.count) * 34
        let strip = NSImage(size: NSSize(width: pointWidth, height: 22))
        strip.lockFocus()
        NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: pointWidth, height: 22))
        var x: CGFloat = 14
        for state in states {
            image(for: state).draw(in: NSRect(x: x, y: 2, width: 18, height: 18))
            x += 34
        }
        strip.unlockFocus()
        writePNG(strip, scale: 4, to: "\(dir)/menubar-strip.png")
    }

    private static func checkerboard(in rect: NSRect) {
        let tile: CGFloat = 12
        for row in 0..<Int(rect.height / tile) + 1 {
            for col in 0..<Int(rect.width / tile) + 1 {
                let isLight = (row + col) % 2 == 0
                (isLight ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.75, alpha: 1)).setFill()
                NSRect(
                    x: rect.minX + CGFloat(col) * tile, y: rect.minY + CGFloat(row) * tile,
                    width: min(tile, rect.maxX - (rect.minX + CGFloat(col) * tile)),
                    height: min(tile, rect.maxY - (rect.minY + CGFloat(row) * tile))
                ).fill()
            }
        }
    }

    /// Renders the Finder/Dock app icon (green rounded square, white mark)
    /// as a complete .iconset directory: leetcode-toggle --app-icon <dir>
    static func writeAppIcon(to dir: String) {
        let entries: [(pixels: Int, name: String)] = [
            (16, "16x16"), (32, "16x16@2x"),
            (32, "32x32"), (64, "32x32@2x"),
            (128, "128x128"), (256, "128x128@2x"),
            (256, "256x256"), (512, "256x256@2x"),
            (512, "512x512"), (1024, "512x512@2x"),
        ]
        for entry in entries {
            writePNG(appIcon(pixels: entry.pixels), scale: 1, to: "\(dir)/icon_\(entry.name).png")
        }
    }

    private static func appIcon(pixels: Int) -> NSImage {
        let side = CGFloat(pixels)
        let img = NSImage(size: NSSize(width: side, height: side))
        img.lockFocus()

        // Rounded-square background with a subtle green gradient.
        let corner = side * 0.2237
        let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
                              xRadius: corner, yRadius: corner)
        let gradient = NSGradient(colors: [
            NSColor(red: 0x7C / 255.0, green: 0xD6 / 255.0, blue: 0x4B / 255.0, alpha: 1),
            leetcodeGreen,
            NSColor(red: 0x56 / 255.0, green: 0xB0 / 255.0, blue: 0x2E / 255.0, alpha: 1),
        ])
        gradient?.draw(in: bg, angle: -90)

        // White LeetCode mark, centered at ~60% of the canvas.
        // Tint on a separate transparent canvas so the background stays intact.
        let markSide = side * 0.62
        let markSize = NSSize(width: markSide, height: markSide)
        let mark: NSImage
        if let url = Bundle.module.url(forResource: "leetcode", withExtension: "svg"),
           let svg = NSImage(contentsOf: url) {
            svg.size = markSize
            mark = svg
        } else {
            mark = fallbackMark()
        }
        let whiteMark = NSImage(size: markSize)
        whiteMark.lockFocus()
        mark.draw(in: NSRect(origin: .zero, size: markSize), from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: markSize).fill(using: .sourceAtop)
        whiteMark.unlockFocus()
        whiteMark.draw(
            in: NSRect(x: (side - markSide) / 2, y: (side - markSide) / 2, width: markSide, height: markSide),
            from: .zero, operation: .sourceOver, fraction: 1
        )

        img.unlockFocus()
        return img
    }

    private static func writePNG(_ image: NSImage, scale: CGFloat, to path: String) {
        let w = Int(image.size.width * scale)
        let h = Int(image.size.height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    // MARK: - Fallback (if the SVG resource is missing)

    private static func fallbackMark() -> NSImage {
        // A simple circle + angle-bracket "code" glyph.
        let size = NSSize(width: pointSize, height: pointSize)
        let img = NSImage(size: size)
        img.lockFocus()
        NSBezierPath(ovalIn: NSRect(x: 1.2, y: 1.2, width: 15.6, height: 15.6)).stroke()
        func bracket(_ openLeft: Bool) {
            let p = NSBezierPath()
            let x0: CGFloat = openLeft ? 7.6 : 10.4
            let x1: CGFloat = openLeft ? 4.6 : 13.4
            p.move(to: NSPoint(x: x0, y: 10.6))
            p.line(to: NSPoint(x: x1, y: 7.5))
            p.line(to: NSPoint(x: x0, y: 4.4))
            p.lineWidth = 1.4
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            p.stroke()
        }
        bracket(true)
        bracket(false)
        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
