import AppKit

enum Demo {
    static func make(in language: AppLanguage = .chinese) -> (ReviewImage, [Mark])? {
        let width = 1120
        let height = 720
        guard let context = Ink.bitmap(width: width, height: height) else { return nil }
        Ink.onBitmap(context, height: CGFloat(height)) {
            let dark = Ink.color(0x25342C)
            let muted = Ink.color(0x626B62)
            let pine = Ink.color(0x315F49)
            let border = Ink.color(0xDFDCD0)
            func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor, radius: CGFloat = 0) {
                Ink.fill(context, CGRect(x: x, y: y, width: w, height: h), color, radius: radius)
            }
            func label(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor,
                       _ weight: NSFont.Weight = .regular, mono: Bool = false) {
                Ink.text(value, size: size, weight: weight, color: color, mono: mono).draw(at: CGPoint(x: x, y: y))
            }

            block(0, 0, 1120, 720, Ink.color(0xF9F8F1))
            block(0, 0, 1120, 68, .white)
            block(0, 67, 1120, 1, border)
            block(47, 21, 27, 27, pine, radius: 8)
            label("s", 55, 23, 16, .white, .heavy)
            label("studio", 85, 24, 20, dark, .bold)
            label(language.text("工作台", "Workspace"), 478, 27, 14, pine, .semibold)
            label(language.text("素材库", "Library"), 566, 27, 14, muted, .medium)
            label(language.text("团队", "Team"), 654, 27, 14, muted, .medium)
            block(476, 63, 49, 3, pine, radius: 1.5)
            block(1036, 18, 34, 34, Ink.color(0xE3E8D7), radius: 17)
            label("L", 1047, 26, 15, pine, .bold)
            label(language.text("你的工作台", "Your workspace"), 52, 103, 14, pine, .semibold)
            label(language.text("下午好，Lina", "Good afternoon, Lina"), 51, 132, 39, dark, .bold)
            label(language.text("继续你的设计项目，或从一个新的想法开始。", "Pick up a project or start with a new idea."), 53, 191, 15, muted)
            block(952, 145, 111, 38, Ink.color(0xBDCEB9), radius: 8)
            label(language.text("＋ 新建项目", "+ New project"), 963, 155, 14, .white, .semibold)
            block(52, 246, 1016, 220, Ink.color(0xE7ECDE), radius: 18)
            label(language.text("最近打开", "Recently opened"), 82, 276, 14, pine, .semibold)
            label(language.text("移动端视觉探索", "Mobile design exploration"), 81, 312, 33, dark, .bold)
            label(language.text("组件、插图和新导航的设计验证", "Test components, illustrations, and navigation"), 83, 366, 15, muted)
            block(83, 405, 126, 35, pine, radius: 8)
            label(language.text("打开项目   ↗", "Open project  ↗"), 98, 413, 14, .white, .semibold)

            context.saveGState()
            context.clip(to: CGRect(x: 654, y: 246, width: 392, height: 220))
            context.translateBy(x: 852, y: 372)
            context.rotate(by: -0.21)
            block(-116, -93, 232, 197, Ink.color(0x99AC8F), radius: 18)
            context.rotate(by: 0.35)
            block(-83, -76, 208, 188, .white, radius: 18)
            block(-66, -59, 174, 86, Ink.color(0xC1D0B4), radius: 9)
            block(-55, -44, 76, 55, Ink.color(0x64836D), radius: 7)
            block(31, -44, 61, 55, Ink.color(0xFFB9A8), radius: 28)
            block(-66, 45, 138, 9, Ink.color(0xE9EADD), radius: 4)
            block(-66, 63, 91, 9, Ink.color(0xE9EADD), radius: 4)
            context.restoreGState()

            label(language.text("所有项目", "All projects"), 52, 499, 21, dark, .bold)
            for (index, project) in [
                ("B", language.text("品牌视觉", "Brand identity"), language.text("3 个文件  ·  周一更新", "3 files  ·  Updated Monday"), UInt32(0xF8E8DF)),
                ("W", language.text("站点改版", "Website refresh"), language.text("8 个文件  ·  周三更新", "8 files  ·  Updated Wednesday"), UInt32(0xE0EDF9)),
                ("P", language.text("产品插图", "Product illustrations"), language.text("5 个文件  ·  昨天更新", "5 files  ·  Updated yesterday"), UInt32(0xE2E7D9))
            ].enumerated() {
                let x = CGFloat(52 + index * 342)
                block(x, 550, 332, 118, border, radius: 14)
                block(x + 1, 551, 330, 116, .white, radius: 13)
                block(x + 19, 571, 40, 40, Ink.color(project.3), radius: 11)
                label(project.0, x + 32, 581, 17, dark, .bold)
                label(project.1, x + 74, 575, 16, dark, .semibold)
                label(project.2, x + 74, 608, 13, muted)
            }
        }
        guard let pixels = context.makeImage() else { return nil }
        let marks = [
            Mark(tool: .region, start: ImagePoint(CGPoint(x: 945, y: 137)), end: ImagePoint(CGPoint(x: 1072, y: 194)),
                 problem: language.text("「新建项目」的白字与浅绿背景对比太弱。", "The New project button has low contrast."),
                 desired: language.text("使用与「打开项目」相同的深绿底色，保留白色按钮文字。", "Use the same dark green as Open project and keep the white label.")),
            Mark(tool: .arrow, start: ImagePoint(CGPoint(x: 272, y: 409)), end: ImagePoint(CGPoint(x: 215, y: 423)),
                 problem: language.text("示例项目的入口缺少清晰的操作反馈。", "The project button needs clearer interaction feedback."),
                 desired: language.text("增加悬停和键盘聚焦状态，保证入口在键盘操作时可见。", "Add visible hover and keyboard focus states."))
        ]
        return (ReviewImage(name: language.text("工作台评审示例.png", "Workspace review sample.png"), image: pixels), marks)
    }
}
