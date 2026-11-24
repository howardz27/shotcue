import AppKit
import ImageIO
import UniformTypeIdentifiers

enum Ink {
    static let logoBlue: UInt32 = 0x6398FF

    static func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }

    static func fill(_ context: CGContext, _ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
        context.setFillColor(color.cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }

    static func line(_ context: CGContext, _ from: CGPoint, _ to: CGPoint, _ color: NSColor, width: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }

    static func text(_ value: String, size: CGFloat, weight: NSFont.Weight = .regular,
                     color: NSColor, lineSpacing: CGFloat = 0, mono: Bool = false) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                        : NSFont.systemFont(ofSize: size, weight: weight)
        return NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color,
                                                               .paragraphStyle: paragraph])
    }

    static func drawPixels(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    static func onBitmap(_ bitmap: CGContext, height: CGFloat, draw: () -> Void) {
        bitmap.translateBy(x: 0, y: height)
        bitmap.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: true)
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func bitmap(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0, width <= 40_000, height <= 40_000,
              width <= 160_000_000 / height,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                         space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}

struct AnnotationAppearance: Equatable, Sendable {
    let hex: UInt32

    init(_ hex: UInt32 = Ink.logoBlue) { self.hex = hex }

    init?(hexString: String) {
        let text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = text.hasPrefix("#") ? text.dropFirst() : text[...]
        guard digits.count == 6, digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let value = UInt32(digits, radix: 16) else { return nil }
        self.init(value)
    }

    init?(color: NSColor) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        func byte(_ component: CGFloat) -> UInt32 {
            UInt32((max(0, min(component, 1)) * 255).rounded())
        }
        hex = byte(rgb.redComponent) << 16 | byte(rgb.greenComponent) << 8 | byte(rgb.blueComponent)
    }

    var hexString: String { String(format: "#%06X", hex) }
    var fill: NSColor { Ink.color(hex) }
    var foreground: NSColor { luminance > 0.179 ? .black : .white }

    // Keep small interface text legible on the light toolbar.
    var textAccent: NSColor {
        let factor = luminance > 0.17 ? 0.17 / luminance : 1
        func display(_ component: CGFloat) -> CGFloat {
            let scaled = component * factor
            return scaled <= 0.0031308 ? scaled * 12.92 : 1.055 * pow(scaled, 1 / 2.4) - 0.055
        }
        let rgb = linearRGB
        return NSColor(srgbRed: display(rgb.red), green: display(rgb.green), blue: display(rgb.blue), alpha: 1)
    }

    private var linearRGB: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let rgb = fill
        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return (linear(rgb.redComponent), linear(rgb.greenComponent), linear(rgb.blueComponent))
    }

    private var luminance: CGFloat {
        let rgb = linearRGB
        return 0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
    }
}

struct MarkLayout {
    let mark: Mark
    let imageRect: CGRect
    let scale: CGFloat
    let unit: CGFloat

    func screen(_ point: ImagePoint) -> CGPoint {
        CGPoint(x: imageRect.minX + point.x * scale, y: imageRect.minY + point.y * scale)
    }

    var start: CGPoint { screen(mark.start) }
    var end: CGPoint { screen(mark.end) }
    var region: CGRect {
        let bounds = mark.bounds
        return CGRect(origin: screen(ImagePoint(bounds.origin)),
                      size: CGSize(width: bounds.width * scale, height: bounds.height * scale))
    }

    private var strokePoints: [CGPoint] { (mark.stroke ?? [mark.start, mark.end]).map(screen) }
    private var brushWidth: CGFloat { max(1, (mark.brushWidth ?? 12) * scale) }

    private func strokePath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        if mark.isClosedLasso { path.closeSubpath() }
        return path
    }

    func containsArea(_ point: CGPoint) -> Bool {
        switch mark.tool {
        case .region: region.contains(point)
        case .lasso: mark.isClosedLasso && region.contains(point) && strokePath(strokePoints).contains(point, using: .evenOdd)
        default: false
        }
    }

    func badge(for number: Int) -> CGRect {
        let height = 26 * unit
        let width = (number < 10 ? 26 : number < 100 ? 33 : 43) * unit
        let offset = 11 * unit
        let anchor = mark.tool == .region || mark.tool == .lasso ? region.origin : start
        let right = anchor.x + offset
        let left = anchor.x - offset - width
        let x = right + width <= imageRect.maxX - 3 * unit ? right : left
        let top = anchor.y - offset - height
        let y = top >= imageRect.minY + 3 * unit ? top : anchor.y + offset
        return CGRect(x: max(imageRect.minX + 3 * unit, min(x, imageRect.maxX - width - 3 * unit)),
                      y: max(imageRect.minY + 3 * unit, min(y, imageRect.maxY - height - 3 * unit)),
                      width: width, height: height)
    }

    func hitTest(_ point: CGPoint, number: Int) -> Bool {
        if badge(for: number).insetBy(dx: -4, dy: -4).contains(point) { return true }
        let slop = 8 * unit
        switch mark.tool {
        case .pin:
            return hypot(point.x - start.x, point.y - start.y) <= slop + 4
        case .region:
            return region.insetBy(dx: -slop, dy: -slop).contains(point) &&
                (region.width <= 2 * slop || region.height <= 2 * slop ||
                 !region.insetBy(dx: slop, dy: slop).contains(point))
        case .arrow:
            return distance(from: point, toSegmentFrom: start, to: end) <= slop
        case .lasso, .brush:
            let radius = slop + (mark.tool == .brush ? brushWidth / 2 : 0)
            guard region.insetBy(dx: -radius, dy: -radius).contains(point) else { return false }
            let points = strokePoints
            if mark.isClosedLasso, distance(from: point, toSegmentFrom: end, to: start) <= radius { return true }
            if points.count == 1 { return hypot(point.x - start.x, point.y - start.y) <= radius }
            return zip(points, points.dropFirst()).contains { distance(from: point, toSegmentFrom: $0, to: $1) <= radius }
        }
    }

    private func distance(from point: CGPoint, toSegmentFrom first: CGPoint, to last: CGPoint) -> CGFloat {
        let dx = last.x - first.x
        let dy = last.y - first.y
        let squared = dx * dx + dy * dy
        guard squared > 0 else { return hypot(point.x - first.x, point.y - first.y) }
        let t = max(0, min(1, ((point.x - first.x) * dx + (point.y - first.y) * dy) / squared))
        return hypot(point.x - (first.x + t * dx), point.y - (first.y + t * dy))
    }

    func intersects(_ selection: CGRect) -> Bool {
        if selection.intersects(badge(for: mark.number)) { return true }
        switch mark.tool {
        case .pin:
            return selection.insetBy(dx: -6 * unit, dy: -6 * unit).contains(start)
        case .region:
            return selection.intersects(region)
        case .arrow:
            return segment(from: start, to: end, intersects: selection.insetBy(dx: -3 * unit, dy: -3 * unit))
        case .lasso, .brush:
            let padding = mark.tool == .brush ? brushWidth / 2 : 3 * unit
            let target = selection.insetBy(dx: -padding, dy: -padding)
            guard selection.intersects(region.insetBy(dx: -padding, dy: -padding)) else { return false }
            let points = strokePoints
            if mark.isClosedLasso,
               segment(from: end, to: start, intersects: target) || containsArea(CGPoint(x: target.midX, y: target.midY)) {
                return true
            }
            if points.count == 1 { return target.contains(start) }
            return zip(points, points.dropFirst()).contains { segment(from: $0, to: $1, intersects: target) }
        }
    }

    private func segment(from start: CGPoint, to end: CGPoint, intersects target: CGRect) -> Bool {
        let left = max(target.minX, min(start.x, end.x))
        let right = min(target.maxX, max(start.x, end.x))
        guard left <= right else { return false }
        let dx = end.x - start.x
        if dx == 0 { return max(start.y, end.y) >= target.minY && min(start.y, end.y) <= target.maxY }
        let slope = (end.y - start.y) / dx
        let firstY = start.y + (left - start.x) * slope
        let lastY = start.y + (right - start.x) * slope
        return max(firstY, lastY) >= target.minY && min(firstY, lastY) <= target.maxY
    }

    func draw(number: Int, selected: Bool, appearance: AnnotationAppearance, context: CGContext) {
        let thickness = (selected ? 3.5 : 2.6) * unit
        let marker = appearance.fill
        let outer = appearance.foreground.withAlphaComponent(0.92)
        let badgeRect = badge(for: number)

        func outlinedLine(_ from: CGPoint, _ to: CGPoint) {
            Ink.line(context, from, to, outer, width: thickness + 2.4 * unit)
            Ink.line(context, from, to, marker, width: thickness)
        }

        switch mark.tool {
        case .pin:
            let stem = CGPoint(x: max(badgeRect.minX, min(start.x, badgeRect.maxX)),
                               y: max(badgeRect.minY, min(start.y, badgeRect.maxY)))
            outlinedLine(start, stem)
            context.setFillColor(outer.cgColor)
            context.fillEllipse(in: CGRect(x: start.x - 5.8 * unit, y: start.y - 5.8 * unit,
                                           width: 11.6 * unit, height: 11.6 * unit))
            context.setFillColor(marker.cgColor)
            context.fillEllipse(in: CGRect(x: start.x - 3.4 * unit, y: start.y - 3.4 * unit,
                                           width: 6.8 * unit, height: 6.8 * unit))
        case .region:
            let path = CGPath(roundedRect: region, cornerWidth: 3 * unit, cornerHeight: 3 * unit, transform: nil)
            context.addPath(path)
            context.setFillColor(marker.withAlphaComponent(0.10).cgColor)
            context.fillPath()
            for (color, width) in [(outer, thickness + 2.4 * unit), (marker, thickness)] {
                context.addPath(path)
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(width)
                context.strokePath()
            }
        case .arrow:
            let direction = atan2(end.y - start.y, end.x - start.x)
            let head = min(15 * unit, hypot(end.x - start.x, end.y - start.y) * 0.55)
            let left = CGPoint(x: end.x - cos(direction - 0.54) * head, y: end.y - sin(direction - 0.54) * head)
            let right = CGPoint(x: end.x - cos(direction + 0.54) * head, y: end.y - sin(direction + 0.54) * head)
            for (color, width) in [(outer, thickness + 2.4 * unit), (marker, thickness)] {
                Ink.line(context, start, end, color, width: width)
                Ink.line(context, left, end, color, width: width)
                Ink.line(context, end, right, color, width: width)
            }
        case .lasso, .brush:
            let points = strokePoints
            let path = strokePath(points)
            context.saveGState()
            context.setLineCap(.round)
            context.setLineJoin(.round)
            if mark.tool == .lasso {
                if mark.isClosedLasso {
                    context.addPath(path)
                    context.setFillColor(marker.withAlphaComponent(0.10).cgColor)
                    context.fillPath(using: .evenOdd)
                }
                for (color, width) in [(outer, thickness + 2.4 * unit), (marker, thickness)] {
                    context.addPath(path)
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(width)
                    context.strokePath()
                }
            } else {
                let color = marker.withAlphaComponent(0.36).cgColor
                let width = brushWidth
                if points.count == 1 {
                    context.setFillColor(color)
                    context.fillEllipse(in: CGRect(x: start.x - width / 2, y: start.y - width / 2,
                                                   width: width, height: width))
                } else {
                    context.addPath(path)
                    context.setStrokeColor(color)
                    context.setLineWidth(width)
                    context.strokePath()
                }
            }
            context.restoreGState()
        }

        Self.drawBadge(number, in: badgeRect, unit: unit, selected: selected, appearance: appearance, context: context)
    }

    static func drawBadge(_ number: Int, in rect: CGRect, unit: CGFloat, selected: Bool = false,
                          appearance: AnnotationAppearance, context: CGContext) {
        if selected {
            Ink.fill(context, rect.insetBy(dx: -2.5 * unit, dy: -2.5 * unit), .white, radius: 9 * unit)
        }
        Ink.fill(context, rect.insetBy(dx: -unit, dy: -unit), appearance.foreground, radius: 7 * unit)
        Ink.fill(context, rect, appearance.fill, radius: 6 * unit)
        let value = Ink.text(String(number), size: 14 * unit, weight: .heavy, color: appearance.foreground, mono: true)
        let size = value.size()
        value.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }
}

enum ImageExport {
    enum Failure: LocalizedError {
        case noSource, size, encoding
        var errorDescription: String? { message(in: .english) }

        func message(in language: AppLanguage) -> String {
            switch self {
            case .noSource: language.text("请先打开截图", "Open a screenshot first")
            case .size: language.text("这张截图和说明合成后的图片过大，可以单独保存说明",
                                      "The image is too large with feedback attached. Save the feedback separately.")
            case .encoding: language.text("无法生成 PNG", "Could not create the PNG")
            }
        }
    }

    private struct Row {
        let number: Int
        let location: NSAttributedString
        let text: [(NSAttributedString, CGFloat)]
        let height: CGFloat
    }

    private static let drawingOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    static func render(_ review: Review, appearance: AnnotationAppearance = .init(),
                       language: AppLanguage = .chinese) throws -> CGImage {
        guard let source = review.source else { throw Failure.noSource }
        guard !review.marks.isEmpty else { return source.image }

        let screenshotWidth = CGFloat(source.image.width)
        let screenshotHeight = CGFloat(source.image.height)
        let includeFeedback = review.hasFeedback
        let width = includeFeedback ? max(860, screenshotWidth) : screenshotWidth
        let unit = max(1, min(width / 1100, 3.4))
        let markerUnit = min(unit, max(0.56, min(screenshotWidth, screenshotHeight) / 145))
        let panelWidth = min(width, 1120 * unit)
        let margin = 32 * unit
        let textWidth = panelWidth - margin * 2 - 58 * unit
        let textX = (width - panelWidth) / 2 + margin + 58 * unit
        let ink = Ink.color(0x17191E)
        let muted = Ink.color(0x535A66)

        func height(of text: NSAttributedString) -> CGFloat {
            ceil(text.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                                   options: drawingOptions).height) + unit * 2
        }

        let rows = (includeFeedback ? review.marks : []).map { mark -> Row in
            let location = Ink.text(mark.location(in: source.size, language: language), size: 15 * unit, weight: .semibold, color: muted)
            var blocks: [(NSAttributedString, CGFloat)] = []
            for (label, raw) in [(language.text("当前问题", "Current issue"), mark.problem),
                                 (language.text("期望调整", "Requested change"), mark.desired)] {
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { continue }
                let content = NSMutableAttributedString(attributedString: Ink.text(label + "  ",
                    size: 18 * unit, weight: .bold, color: ink, lineSpacing: 5 * unit))
                content.append(Ink.text(value, size: 18 * unit, color: ink, lineSpacing: 5 * unit))
                blocks.append((content, height(of: content)))
            }
            if blocks.isEmpty {
                let empty = Ink.text(language.text("说明待填写", "No written feedback yet"), size: 18 * unit, color: muted)
                blocks.append((empty, height(of: empty)))
            }
            let rowHeight = height(of: location) + blocks.reduce(0) { $0 + $1.1 + 7 * unit } + 36 * unit
            return Row(number: mark.number, location: location, text: blocks, height: rowHeight)
        }

        let headerHeight = 113 * unit
        let feedbackHeight = includeFeedback ? headerHeight + rows.reduce(0) { $0 + $1.height } + 18 * unit : 0
        let totalHeight = ceil(screenshotHeight + feedbackHeight)
        guard totalHeight.isFinite, totalHeight <= 40_000,
              let canvas = Ink.bitmap(width: Int(width), height: Int(totalHeight)) else { throw Failure.size }
        let imageRect = CGRect(x: (width - screenshotWidth) / 2, y: 0, width: screenshotWidth, height: screenshotHeight)

        Ink.onBitmap(canvas, height: totalHeight) {
            if includeFeedback {
                Ink.fill(canvas, CGRect(x: 0, y: 0, width: width, height: totalHeight), Ink.color(0xFAFBFC))
                Ink.fill(canvas, CGRect(x: 0, y: 0, width: width, height: screenshotHeight), Ink.color(0xECEEF1))
                Ink.fill(canvas, imageRect, .white)
            }
            Ink.drawPixels(source.image, in: imageRect, context: canvas)
            canvas.saveGState()
            canvas.clip(to: imageRect)
            for mark in review.marks {
                MarkLayout(mark: mark, imageRect: imageRect, scale: 1, unit: markerUnit)
                    .draw(number: mark.number, selected: false, appearance: appearance, context: canvas)
            }
            canvas.restoreGState()
            guard includeFeedback else { return }
            Ink.fill(canvas, CGRect(x: 0, y: screenshotHeight, width: width, height: 3 * unit), appearance.fill)

            let left = (width - panelWidth) / 2 + margin
            Ink.text(language.text("上图标注说明", "Screenshot feedback"), size: 27 * unit, weight: .bold, color: ink)
                .draw(at: CGPoint(x: left, y: screenshotHeight + 19 * unit))
            Ink.text(language.text("每条说明对应上图中相同编号的标记。", "Each note matches its numbered annotation above."),
                     size: 15 * unit, weight: .semibold, color: muted)
                .draw(at: CGPoint(x: left, y: screenshotHeight + 57 * unit))
            let size = "\(source.image.width) × \(source.image.height) px"
            let details = language.text("原图 \(size)  ·  坐标原点为原图左上角", "Original: \(size)  ·  Origin: top-left")
            Ink.text("\(language.annotationCount(rows.count))  ·  \(details)", size: 13 * unit, weight: .medium, color: muted)
                .draw(at: CGPoint(x: left, y: screenshotHeight + 80 * unit))

            var y = screenshotHeight + headerHeight
            for row in rows {
                Ink.line(canvas, CGPoint(x: left, y: y), CGPoint(x: left + panelWidth - margin * 2, y: y),
                         Ink.color(0xDEE1E6), width: unit)
                let badge = CGRect(x: left + unit, y: y + 17 * unit,
                                   width: (row.number < 10 ? 29 : row.number < 100 ? 36 : 45) * unit, height: 28 * unit)
                MarkLayout.drawBadge(row.number, in: badge, unit: unit, appearance: appearance, context: canvas)
                var textY = y + 15 * unit
                let locationHeight = height(of: row.location)
                row.location.draw(with: CGRect(x: textX, y: textY, width: textWidth, height: locationHeight),
                                  options: drawingOptions)
                textY += locationHeight + 5 * unit
                for (block, blockHeight) in row.text {
                    block.draw(with: CGRect(x: textX, y: textY, width: textWidth, height: blockHeight),
                               options: drawingOptions)
                    textY += blockHeight + 7 * unit
                }
                y += row.height
            }
        }

        guard let output = canvas.makeImage() else { throw Failure.encoding }
        return output
    }

    static func pngData(_ image: CGImage) throws -> Data {
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.encoding
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.encoding }
        return buffer as Data
    }

    static func png(_ review: Review, appearance: AnnotationAppearance = .init(),
                    language: AppLanguage = .chinese) throws -> Data {
        try pngData(render(review, appearance: appearance, language: language))
    }
}
