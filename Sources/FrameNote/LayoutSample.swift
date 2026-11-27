import SwiftUI

/// Miniature page layouts share a drawing scale so their spacing can be compared.
struct LayoutSample: View {
    let layout: LayoutSpecimen
    let language: AppLanguage
    private let ink = Color(nsColor: Ink.color(0x45568D))
    private let mid = Color(nsColor: Ink.color(0xA5B1D7))
    private let light = Color(nsColor: Ink.color(0xDFE5F4))

    var body: some View {
        Canvas { ctx, _ in
            func block(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Color, radius: CGFloat = 3) {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius), with: .color(color))
            }
            func label(_ text: String, _ x: Int, _ y: Int, _ color: Color = .black, size: CGFloat = 9) {
                ctx.draw(Text(text).font(.system(size: size, weight: .medium)).foregroundStyle(color),
                         at: CGPoint(x: x, y: y), anchor: .leading)
            }
            func lines(_ x: Int, _ y: Int, _ width: Int, count: Int = 3) {
                for i in 0..<count { block(x, y + i * 7, i == count - 1 ? width * 2 / 3 : width, 3, mid) }
            }
            func panel(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
                block(x, y, w, h, mid, radius: 4)
                block(x + 1, y + 1, w - 2, h - 2, .white)
            }
            func scene(_ x: Int, _ y: Int, _ w: Int, _ h: Int, clippedTo crop: CGRect? = nil) {
                var drawing = ctx
                if let crop { drawing.clip(to: Path(crop)) }
                drawing.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(nsColor: Ink.color(0xD2EAF1))))
                let sun = CGRect(x: x + w / 5, y: y + h / 10, width: h / 4, height: h / 4)
                drawing.fill(Path(ellipseIn: sun), with: .color(.orange))
                var hills = Path()
                hills.move(to: CGPoint(x: x, y: y + h))
                hills.addLine(to: CGPoint(x: x + w / 3, y: y + h / 3))
                hills.addLine(to: CGPoint(x: x + w / 2, y: y + h * 2 / 3))
                hills.addLine(to: CGPoint(x: x + w * 3 / 4, y: y + h / 4))
                hills.addLine(to: CGPoint(x: x + w, y: y + h))
                hills.closeSubpath()
                drawing.fill(hills, with: .color(.teal))
            }

            switch layout {
            case .bento:
                block(14, 5, 93, 58, ink); block(112, 5, 78, 26, mid); block(112, 36, 78, 27, light)
                label("01", 24, 48, .white, size: 16)
            case .align:
                block(35, 3, 1, 60, .pink)
                block(36, 10, 86, 8, ink); lines(36, 25, 137); block(36, 48, 54, 12, ink)
            case .similar:
                for (i, x) in [17, 54, 91].enumerated() {
                    block(x, 21, 30, 24, light, radius: 12); label(String(i + 1), x + 12, 33, ink)
                }
                block(145, 21, 36, 24, ink); label("A", 159, 33, .white)
            case .region:
                for x in [8, 108] { block(x, 8, 89, 52, light); lines(x + 10, 20, 65) }
            case .target:
                block(78, 9, 49, 49, light, radius: 8)
                label("×", 95, 32, ink, size: 23)
                label("↔", 136, 32, ink, size: 16)
            case .sidebar, .anchors, .master:
                panel(12, 3, 178, 62)
                block(14, 5, 52, 58, light); block(18, 14, 44, 9, mid)
                lines(21, 30, 35); lines(74, 17, 101, count: layout == .anchors ? 2 : 4)
                if layout == .anchors { block(74, 38, 56, 6, ink); lines(74, 50, 86, count: 1) }
                if layout == .master { block(74, 43, 22, 12, ink) }
            case .topbar, .bottomnav, .footer, .sticky:
                panel(12, 3, 178, 62)
                let top = layout == .topbar || layout == .sticky
                let y = top ? 5 : 47
                block(14, y, 174, 16, ink)
                if layout == .footer { label(language.text("联系       帮助       隐私", "Contact      Help      Privacy"), 29, y + 8, .white) }
                else {
                    for (i, x) in [30, 87, 144].enumerated() {
                        block(x, y + 6, i == 0 ? 29 : 24, 3, i == 0 ? .white : mid)
                    }
                }
                lines(22, top ? 30 : 13, 139, count: 3)
                if layout == .sticky { label("↑", 174, 47, ink, size: 14) }
            case .drawer:
                panel(12, 3, 178, 62); lines(20, 16, 78, count: 5)
                block(13, 4, 94, 60, .black.opacity(0.16)); block(106, 4, 82, 60, light)
                label(language.text("订单详情", "Order details"), 114, 18, ink); lines(114, 31, 61)
            case .skeleton:
                for y in [8, 37] {
                    block(19, y, 23, 23, light, radius: 12); block(50, y + 4, 118, 5, mid); block(50, y + 15, 78, 4, light)
                }
            case .flex:
                panel(8, 19, 190, 30); block(13, 24, 101, 19, light); label("↔", 55, 33, ink)
                for x in [120, 158] { block(x, 24, 32, 19, mid) }
            case .grid:
                for col in 0..<3 { for row in 0..<2 { block(18 + col * 58, 8 + row * 28, 52, 23, row == 0 ? mid : light) } }
            case .gutter:
                block(19, 9, 72, 48, light); block(112, 9, 72, 48, light)
                label("↔", 94, 34, ink); lines(25, 20, 58); lines(119, 20, 56)
            case .maxwidth, .fluid:
                panel(7, 6, 190, 56); block(43, 8, 117, 52, light)
                if layout == .fluid { label("←              →", 59, 32, ink, size: 14) }
                else { lines(51, 17, 100, count: 5) }
            case .ratio:
                block(50, 4, 104, 59, light); label("16 : 9", 83, 32, ink, size: 14)
            case .stack:
                for i in 0..<3 {
                    block(40 + i * 29, 5 + i * 9, 70, 42, [light, mid, ink][i])
                    label(String(i + 1), 48 + i * 29, 17 + i * 9, i == 2 ? .white : .black)
                }
            case .divider, .density:
                let count = layout == .density ? 5 : 3
                for i in 0..<count {
                    let y = 7 + i * (56 / count)
                    block(24, y, 55 + i * 5, 4, mid); block(24, y + 7, 154, 1, light)
                }
            case .hero:
                panel(8, 4, 188, 60); block(17, 13, 76, 8, ink); lines(17, 27, 75, count: 2)
                block(17, 45, 33, 10, ink); scene(110, 12, 76, 42)
            case .breakpoint, .mobilefirst:
                panel(6, 9, 140, 50)
                for i in 0..<3 { block(12 + i * 44, 18, 39, 31, i == 0 ? mid : light) }
                panel(161, 3, 35, 61)
                for i in 0..<3 { block(165, 9 + i * 16, 27, 12, i == 0 ? mid : light) }
            case .wrap:
                panel(30, 4, 142, 61)
                for (i, x) in [36, 85, 119, 36, 87].enumerated() { block(x, i < 3 ? 12 : 38, [42, 27, 44, 44, 51][i], 16, light, radius: 8) }
            case .safe:
                panel(72, 1, 61, 66); block(88, 2, 28, 5, ink); block(79, 43, 47, 11, mid)
                block(77, 56, 51, 8, light); block(92, 60, 22, 2, ink)
            case .overflow:
                panel(22, 6, 160, 56)
                for i in 0..<4 { block(28 + i * 38, 14, 34, 28, light) }
                block(28, 51, 147, 3, light); block(28, 51, 70, 3, ink)
            case .shift:
                for x in [18, 117] { panel(x, 4, 70, 58); block(x + 7, 12, 56, 28, light); block(x + 7, 47, 35, 6, ink) }
                scene(124, 12, 56, 28); label("→", 91, 33, ink)
            case .cover, .contain, .focal:
                scene(12, 16, 79, 38); label("→", 98, 34, ink)
                panel(121, 5, 59, 59)
                if layout == .contain { scene(123, 21, 55, 27) }
                else {
                    scene(layout == .focal ? 111 : 91, 6, 118, 57,
                          clippedTo: CGRect(x: 122, y: 6, width: 57, height: 57))
                }
            case .rtl:
                panel(12, 12, 179, 43); label("→", 168, 31, ink, size: 17)
                label("الرئيسية", 112, 31, ink, size: 14); block(26, 29, 45, 4, mid)
            }
        }.frame(width: 204, height: 68)
    }
}
