import SwiftUI

struct ReferenceSample: View {
    let illustration: ReferenceIllustration
    let language: AppLanguage

    @ViewBuilder var body: some View {
        switch illustration {
        case .look(let look): AppearanceSample(look: look, language: language)
        case .layout(let layout): LayoutSample(layout: layout, language: language)
        case .ui(let control): InterfaceSample(control: control, language: language)
        case .type(let specimen): TypographySample(specimen: specimen, language: language)
        case .motion(let motion): TimingSample(motion: motion, language: language)
        case .palette(let hex):
            HStack(spacing: 0) {
                ForEach(hex, id: \.self) { value in
                    Color(nsColor: Ink.color(value)).frame(width: 36, height: 38)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 5))
        case .gradient(let hex):
            LinearGradient(colors: hex.map { Color(nsColor: Ink.color($0)) }, startPoint: .leading, endPoint: .trailing)
                .frame(width: 190, height: 38).clipShape(RoundedRectangle(cornerRadius: 5))
        case let .pair(firstZH, firstEN, nextZH, nextEN):
            HStack(spacing: 9) {
                Text(language.text(firstZH, firstEN)).padding(7).background(.white, in: RoundedRectangle(cornerRadius: 5))
                Image(systemName: "arrow.right").foregroundStyle(Palette.muted)
                Text(language.text(nextZH, nextEN)).padding(7)
                    .foregroundStyle(.indigo).background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

private struct TypographySample: View {
    let specimen: TypeSpecimen
    let language: AppLanguage

    @ViewBuilder var body: some View {
        switch specimen {
        case .scale:
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ForEach([28, 18, 12], id: \.self) { size in Text("Aa").font(.system(size: CGFloat(size))) }
            }
        case .tracking:
            VStack(alignment: .leading) { Text("STUDIO"); Text("STUDIO").tracking(4) }
        case .kerning:
            HStack(spacing: 16) { Text("AV").kerning(5); Text("→").font(.caption); Text("AV").kerning(-2) }
                .font(.system(size: 24, design: .serif))
        case .paragraph, .measure:
            VStack(alignment: .leading, spacing: 2) {
                let widths: [CGFloat] = specimen == .paragraph ? [160, 122, 150, 98] : [117, 117, 105, 117]
                ForEach(widths.indices, id: \.self) { i in
                    Capsule().fill(Palette.muted.opacity(0.65)).frame(width: widths[i], height: 3)
                        .padding(.top, specimen == .paragraph && i == 2 ? 10 : 2)
                }
            }
        case .baseline:
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("128").font(.system(size: 30, weight: .semibold))
                Text(language.text("元", "USD")).font(.caption)
            }.overlay(alignment: .bottom) { Rectangle().fill(.indigo.opacity(0.5)).frame(height: 1).offset(y: -6) }
        case .tabular, .numeric:
            VStack(alignment: .trailing, spacing: 3) {
                Text(specimen == .tabular ? "09:11:11" : "1,024.00")
                Text(specimen == .tabular ? "09:22:22" : "59.90")
            }.font(.system(size: 16)).monospacedDigit()
        case .ellipsis:
            Text(language.text("春季活动设计规范与交付清单.pdf", "Spring campaign specifications.pdf"))
                .lineLimit(1).truncationMode(.middle).frame(width: 145)
        case .clamp, .wrap:
            Text(specimen == .wrap ? "example.com/gallery/spring/collection/cover.png" :
                    language.text("周末的城市漫步，从一条安静的小巷出发，沿街寻找旧建筑的痕迹与新的风景。", "The weekend walk begins on a quiet street and follows the traces of old architecture through the changing city."))
                .lineLimit(specimen == .wrap ? 4 : 2).frame(width: 145, alignment: .leading)
        case .fallback:
            Text("春日 Studio 2026").font(.system(size: 20))
        case .italic:
            HStack { Text("Field Notes").italic(); Text("· Lee") }.font(.system(size: 19, design: .serif))
        case .variable:
            HStack(spacing: 8) {
                ForEach(Array([Font.Weight.ultraLight, .light, .medium, .bold, .black].enumerated()), id: \.offset) { item in
                    Text("a").font(.system(size: 24, weight: item.element))
                }
            }
        case .spacing:
            HStack(alignment: .bottom, spacing: 12) {
                ForEach([4, 8, 16, 24, 32], id: \.self) { value in
                    VStack { Rectangle().fill(.indigo).frame(width: CGFloat(value), height: 8); Text("\(value)").font(.caption) }
                }
            }
        }
    }
}

private struct AppearanceSample: View {
    let look: AppearanceSpecimen
    let language: AppLanguage

    @ViewBuilder var body: some View {
        switch look {
        case .swiss:
            HStack(alignment: .top) {
                Text("27").font(.system(size: 33, weight: .black)).foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) { Rectangle().frame(width: 94, height: 2); Text("Studio\nBasel").bold() }
            }.padding(6).background(.white)
        case .bauhaus, .memphis:
            ZStack {
                Rectangle().fill(look == .bauhaus ? Color(red: 0.98, green: 0.90, blue: 0.71) : .mint)
                Circle().fill(look == .bauhaus ? .red : .pink).frame(width: 48).offset(x: -45, y: 12)
                Rectangle().fill(look == .bauhaus ? .indigo : .yellow).frame(width: 53, height: 24)
                    .rotationEffect(.degrees(look == .bauhaus ? 0 : -22)).offset(x: 9)
                if look == .memphis { Text("∿∿∿").font(.title).offset(x: 42, y: -12) }
                else { Circle().trim(from: 0, to: 0.5).fill(.black).frame(width: 46).offset(x: 56) }
            }.frame(width: 174, height: 51).clipped()
        case .brutal:
            Text(language.text("立即报名", "JOIN NOW")).bold().padding(9)
                .background(.yellow).border(.black, width: 2).shadow(color: .black, radius: 0, x: 4, y: 4)
        case .soft, .physical:
            ZStack {
                Circle().fill(look == .soft ? AnyShapeStyle(Color(nsColor: Ink.color(0xE8EAF0))) :
                                AnyShapeStyle(.linearGradient(colors: [.white, .gray, .white], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .shadow(color: .white, radius: 3, x: -3, y: -3).shadow(color: .black.opacity(0.27), radius: 3, x: 3, y: 3)
                Capsule().fill(Palette.muted).frame(width: 3, height: 12).offset(y: -12).rotationEffect(.degrees(38))
                if look == .physical { Circle().strokeBorder(.gray, style: StrokeStyle(lineWidth: 2, dash: [1, 5])) }
            }.frame(width: 49, height: 49)
        case .pixel:
            Canvas { context, _ in
                for (y, row) in ["0100010","0011100","0111110","1101011","1111111","0100010","1010101"].enumerated() {
                    for (x, bit) in row.enumerated() where bit == "1" {
                        context.fill(Path(CGRect(x: x * 6, y: y * 6, width: 6, height: 6)), with: .color(.indigo))
                    }
                }
            }.frame(width: 42, height: 42)
        case .terminal:
            VStack(alignment: .leading, spacing: 3) { Text("$ build"); Text("✓ ready   0.42s") }
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.mint).padding(8).frame(width: 165, alignment: .leading).background(.black)
        case .paper:
            Text(language.text("田野手记", "Field journal")).font(.custom(language.text("Songti SC", "Georgia"), size: 20))
                .padding(12).frame(width: 155).background {
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(nsColor: Ink.color(0xF2E5C9))))
                        for i in 0..<180 {
                            ctx.fill(Path(CGRect(x: CGFloat((i * 53) % 155), y: CGFloat((i * 19) % 55), width: 1.1, height: 0.65)), with: .color(.brown.opacity(0.32)))
                        }
                    }
                }
        case .deco:
            ZStack {
                Color(nsColor: Ink.color(0x123E3B))
                ForEach([0, 1, 2], id: \.self) { step in
                    Rectangle().strokeBorder(.yellow.opacity(0.75)).frame(width: CGFloat(134 - step * 10), height: CGFloat(33 + step * 6))
                }
                Text("GALA").font(.system(size: 16, design: .serif)).tracking(4).foregroundStyle(.yellow)
            }.frame(width: 174, height: 54)
        case .outline, .icons:
            HStack(spacing: 16) {
                ForEach(look == .outline ? ["square", "triangle", "circle"] : ["folder", "heart", "gearshape"], id: \.self) { icon in
                    Image(systemName: icon)
                }
            }.font(.system(size: 21, weight: .regular)).foregroundStyle(.indigo)
        case .dark, .themes:
            HStack(spacing: 6) {
                if look == .themes { surface(dark: false) }
                surface(dark: true)
            }
        case .opacity:
            ZStack {
                Capsule().fill(.orange).frame(width: 160, height: 8)
                HStack(spacing: 10) {
                    ForEach([0.22, 0.55, 0.92], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 4).fill(.indigo.opacity(opacity)).frame(width: 36, height: 32)
                    }
                }
            }
        case .contrast:
            HStack(spacing: 14) {
                Text("Aa").foregroundStyle(.gray.opacity(0.45)); Text("Aa").foregroundStyle(.black)
            }.font(.system(size: 24)).padding(.horizontal, 16).background(.white)
        case .elevation:
            HStack(spacing: 20) {
                ForEach([1, 3, 7], id: \.self) { depth in
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 33, height: 24)
                        .shadow(color: .black.opacity(0.22), radius: CGFloat(depth), y: CGFloat(depth / 2 + 1))
                }
            }
        }
    }

    private func surface(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aa").bold()
            Capsule().fill(.gray.opacity(0.55)).frame(width: 42, height: 3)
        }.padding(8).foregroundStyle(dark ? .white : .black)
            .background(dark ? Color(nsColor: Ink.color(0x272C37)) : .white, in: RoundedRectangle(cornerRadius: 5))
    }
}
