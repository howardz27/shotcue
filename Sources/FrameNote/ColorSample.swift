import AppKit
import simd

struct ColorSample {
    private struct EdgeOverlay {
        let image: CGImage
        let bounds: CGRect
    }

    let original: AnnotationAppearance
    private let mask: CGImage
    private let edges: EdgeOverlay?

    static func make(in image: CGImage, at point: ImagePoint) -> Self? {
        let width = image.width
        let height = image.height
        guard !Task.isCancelled, point.x >= 0, point.y >= 0, point.x < Double(width), point.y < Double(height),
              let bitmap = Ink.bitmap(width: width, height: height), let data = bitmap.data else { return nil }
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let rowStride = bitmap.bytesPerRow

        func rgb(at offset: Int) -> (red: Int, green: Int, blue: Int)? {
            let alpha = Int(pixels[offset + 3])
            guard alpha > 0 else { return nil }
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            if alpha == 255 { return (red, green, blue) }
            return ((red * 255 + alpha / 2) / alpha, (green * 255 + alpha / 2) / alpha, (blue * 255 + alpha / 2) / alpha)
        }

        let x = Int(point.x)
        let y = Int(point.y)
        guard let sampled = rgb(at: y * rowStride + x * 4) else { return nil }
        let original = AnnotationAppearance(UInt32(sampled.red << 16 | sampled.green << 8 | sampled.blue))
        var covered = [UInt8](repeating: 0, count: width * height)
        let toleranceSquared = 24 * 24
        func matches(_ x: Int, _ y: Int) -> Bool {
            guard covered[y * width + x] == 0, let color = rgb(at: y * rowStride + x * 4) else { return false }
            let red = color.red - sampled.red
            let green = color.green - sampled.green
            let blue = color.blue - sampled.blue
            return red * red + green * green + blue * blue <= toleranceSquared
        }

        // Visit horizontal runs so large solid regions do not need a queue entry for every pixel.
        var pending = [(x: x, y: y)]
        var bounds = CGRect(x: x, y: y, width: 1, height: 1)
        while let seed = pending.popLast() {
            guard !Task.isCancelled else { return nil }
            guard matches(seed.x, seed.y) else { continue }
            var left = seed.x
            var right = seed.x
            while left > 0, matches(left - 1, seed.y) { left -= 1 }
            while right < width - 1, matches(right + 1, seed.y) { right += 1 }
            bounds = bounds.union(CGRect(x: left, y: seed.y, width: right - left + 1, height: 1))
            for column in left...right { covered[seed.y * width + column] = 255 }
            for row in (seed.y - 1)...(seed.y + 1) where row != seed.y && row >= 0 && row < height {
                var insideRun = false
                for column in left...right {
                    let match = matches(column, row)
                    if match && !insideRun { pending.append((column, row)) }
                    insideRun = match
                }
            }
        }

        let sample = SIMD3(Double(sampled.red), Double(sampled.green), Double(sampled.blue))
        let edges = makeEdgeOverlay(bitmap, around: bounds, sampled: sample, covered: &covered)
        guard !Task.isCancelled else { return nil }
        guard let provider = CGDataProvider(data: Data(covered) as CFData),
              let mask = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                                 bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                                 decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return Self(original: original, mask: mask, edges: edges)
    }

    private static func makeEdgeOverlay(_ bitmap: CGContext, around bounds: CGRect, sampled: SIMD3<Double>,
                                        covered: inout [UInt8]) -> EdgeOverlay? {
        guard let pixels = bitmap.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let width = bitmap.width
        let height = bitmap.height
        let stride = bitmap.bytesPerRow
        let search = bounds.insetBy(dx: -1, dy: -1).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        var edgePixels: [(x: Int, y: Int, foreground: SIMD4<UInt8>)] = []
        var edgeBounds = CGRect.null

        func opaqueColor(at x: Int, _ y: Int) -> SIMD3<Double>? {
            let offset = y * stride + x * 4
            guard pixels[offset + 3] == 255 else { return nil }
            return SIMD3(Double(pixels[offset]), Double(pixels[offset + 1]), Double(pixels[offset + 2]))
        }

        for y in Int(search.minY)..<Int(search.maxY) {
            guard !Task.isCancelled else { return nil }
            for x in Int(search.minX)..<Int(search.maxX) {
                guard let color = opaqueColor(at: x, y), color != sampled else { continue }
                var best: (lengthSquared: Double, foreground: SIMD4<UInt8>)?
                for (dx, dy) in directions {
                    let insideX = x - dx, insideY = y - dy
                    let outsideX = x + dx, outsideY = y + dy
                    guard (0..<width).contains(insideX), (0..<height).contains(insideY),
                          (0..<width).contains(outsideX), (0..<height).contains(outsideY),
                          covered[insideY * width + insideX] == 255, covered[outsideY * width + outsideX] == 0,
                          let outside = opaqueColor(at: outsideX, outsideY) else { continue }
                    let direction = outside - sampled
                    let lengthSquared = simd_length_squared(direction)
                    guard lengthSquared >= 48 * 48, lengthSquared > (best?.lengthSquared ?? 0) else { continue }
                    let difference = color - sampled
                    let opacity = simd_dot(difference, direction) / lengthSquared
                    guard (0.06...0.94).contains(opacity),
                          simd_length_squared(difference - opacity * direction) <= 6 * 6 else { continue }

                    // Recover the part of this pixel that belongs to the foreground before recoloring its background.
                    let alpha = (opacity * 255).rounded()
                    let foreground = simd_clamp(color - (1 - alpha / 255) * sampled, .zero, SIMD3(repeating: alpha))
                    best = (lengthSquared, SIMD4(UInt8(foreground.x.rounded()), UInt8(foreground.y.rounded()),
                                                 UInt8(foreground.z.rounded()), UInt8(alpha)))
                }
                if let best {
                    edgePixels.append((x, y, best.foreground))
                    edgeBounds = edgeBounds.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }

        guard !edgePixels.isEmpty, let overlay = Ink.bitmap(width: Int(edgeBounds.width), height: Int(edgeBounds.height)),
              let data = overlay.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        for (x, y, color) in edgePixels {
            let offset = (y - Int(edgeBounds.minY)) * overlay.bytesPerRow + (x - Int(edgeBounds.minX)) * 4
            data[offset] = color.x
            data[offset + 1] = color.y
            data[offset + 2] = color.z
            data[offset + 3] = color.w
        }
        guard let image = overlay.makeImage() else { return nil }
        for (x, y, _) in edgePixels { covered[y * width + x] = 255 }
        return EdgeOverlay(image: image, bounds: edgeBounds)
    }

    func drawPreview(of image: CGImage, target: AnnotationAppearance, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        Ink.drawPixels(image, in: rect, context: context)
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        let area = CGRect(origin: .zero, size: rect.size)
        context.clip(to: area, mask: mask)
        context.setFillColor(target.fill.cgColor)
        context.fill(area)
        context.restoreGState()
        if let edges {
            let scaleX = rect.width / CGFloat(image.width)
            let scaleY = rect.height / CGFloat(image.height)
            let bounds = edges.bounds
            let edgeRect = CGRect(x: rect.minX + bounds.minX * scaleX, y: rect.minY + bounds.minY * scaleY,
                                  width: bounds.width * scaleX, height: bounds.height * scaleY)
            Ink.drawPixels(edges.image, in: edgeRect, context: context)
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
