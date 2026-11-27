import SwiftUI

struct DesignSample: View {
    let concept: DesignConcept
    let language: AppLanguage
    private let indigo = Color(nsColor: Ink.color(0x4959AD))
    private let navy = Color(nsColor: Ink.color(0x19385D))
    private let orange = Color(nsColor: Ink.color(0xFFC07C))

    @ViewBuilder var body: some View {
        switch concept {
        case .minimalism:
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text("图标集", "Icon set")).bold()
                    Text("SVG · 24 KB").font(.caption).foregroundStyle(Palette.muted)
                }
                Image(systemName: "arrow.down.to.line")
            }
            .padding(13).background(.white)
        case .editorial:
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text("设计随笔", "DESIGN NOTES")).font(.system(size: 9)).tracking(2)
                Text(language.text("留白的尺度", "Room to breathe"))
                    .font(.custom(language.text("Songti SC", "Georgia"), size: 22))
                Rectangle().frame(height: 1)
            }
            .padding(8).frame(width: 190).background(Color(nsColor: Ink.color(0xFAF5EA)))
        case .glass:
            ZStack {
                LinearGradient(colors: [.indigo, .cyan, .purple], startPoint: .leading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.65)).frame(width: 48).offset(x: -40, y: -12)
                Label(language.text("工具栏", "Toolbar"), systemImage: "slider.horizontal.3")
                    .padding(.horizontal, 24).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.75)) }
            }
            .frame(width: 192, height: 62).clipShape(RoundedRectangle(cornerRadius: 8))
        case .flat:
            HStack(spacing: 16) {
                flatAction("folder.fill", language.text("文件", "Files"), indigo)
                flatAction("heart.fill", language.text("收藏", "Favorites"), .pink)
                flatAction("clock.fill", language.text("最近", "Recent"), .teal)
            }
        case .accentColor:
            HStack(spacing: 12) {
                Text(language.text("取消", "Cancel")).foregroundStyle(Palette.muted)
                Text(language.text("预览", "Preview"))
                Text(language.text("发布", "Publish")).padding(7)
                    .foregroundStyle(.white).background(indigo, in: RoundedRectangle(cornerRadius: 5))
            }
        case .monochromatic:
            HStack(spacing: 0) {
                ForEach([0xE3ECFF, 0xB9D2FA, 0x7FA9EB, 0x416BAB, 0x223F6B] as [UInt32], id: \.self) { hex in
                    Color(nsColor: Ink.color(hex)).frame(width: 36, height: 32)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 4))
        case .complementary:
            HStack {
                Text(language.text("开放日", "Open studio")).foregroundStyle(.white)
                Spacer()
                Text("06 / 12").foregroundStyle(navy).padding(5).background(orange)
            }.padding(10).frame(width: 184).background(navy)
        case .semantic:
            HStack(spacing: 16) {
                Label(language.text("已同步", "Synced"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(nsColor: Ink.color(0x25644C)))
                Label(language.text("同步失败", "Sync failed"), systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(Color(nsColor: Ink.color(0xA43239)))
            }
        case .serif:
            Text(language.text("春日手记 Aa", "Field Notes Aa"))
                .font(.custom(language.text("Songti SC", "Georgia"), size: 26))
        case .sansSerif:
            Text(language.text("春日手记 Aa", "Field Notes Aa")).font(.system(size: 26))
        case .monospace:
            VStack(alignment: .leading, spacing: 5) {
                Text("#1144FF")
                Text("#AA44FF")
            }.font(.system(size: 15, design: .monospaced)).foregroundStyle(navy)
        case .weight:
            HStack(spacing: 18) {
                weightSample(.regular, "400")
                weightSample(.semibold, "600")
                weightSample(.bold, "700")
            }
        case .motion(let motion):
            MotionSample(motion: motion, language: language)
        case .hierarchy:
            VStack(alignment: .leading, spacing: 4) {
                Text("¥ 248.00").font(.system(size: 23, weight: .bold))
                Text(language.text("订单号 1042", "Order 1042")).font(.caption).foregroundStyle(Palette.muted)
            }
        case .proximity:
            VStack(alignment: .leading, spacing: 15) {
                smallField(language.text("姓名", "Name"))
                smallField(language.text("邮箱", "Email"))
            }
        case .disclosure:
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(language.text("文件格式", "Format"))
                    Spacer()
                    Text("PNG").bold()
                }
                Divider()
                Label(language.text("高级设置", "Advanced settings"), systemImage: "chevron.right")
                    .font(.caption)
            }
            .padding(8).frame(width: 164).background(.white, in: RoundedRectangle(cornerRadius: 5))
        case .recognition:
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                Image(systemName: "arrow.right").foregroundStyle(Palette.muted)
                Label(language.text("导出", "Export"), systemImage: "square.and.arrow.up")
                    .padding(7).background(.white, in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private func flatAction(_ icon: String, _ text: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 19)).foregroundStyle(color)
            Text(text).font(.caption)
        }
    }

    private func weightSample(_ weight: Font.Weight, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text("Aa").font(.system(size: 22, weight: weight))
            Text(label).font(.caption.monospaced()).foregroundStyle(Palette.muted)
        }
    }

    private func smallField(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10))
            RoundedRectangle(cornerRadius: 2).strokeBorder(.gray.opacity(0.6)).frame(width: 130, height: 10)
        }
    }
}

private struct MotionSample: View {
    let motion: MotionConcept
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback = 0
    @State private var finished = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch motion {
                case .duration:
                    VStack(spacing: 6) {
                        track("160 ms", animation: .linear(duration: 0.16))
                        track("400 ms", animation: .linear(duration: 0.4))
                    }
                case .easing:
                    VStack(spacing: 6) {
                        track(language.text("匀速", "Linear"), animation: .linear(duration: 0.7))
                        track(language.text("缓出", "Ease-out"), animation: .easeOut(duration: 0.7))
                    }
                case .fade:
                    Label(language.text("已保存", "Saved"), systemImage: "checkmark.circle")
                        .padding(7).background(.white, in: Capsule())
                        .opacity(playback == 0 || finished ? 1 : 0)
                        .animation(animation(.linear(duration: 0.2)), value: finished)
                case .slide:
                    ZStack(alignment: .trailing) {
                        Color.white
                        Label(language.text("筛选", "Filters"), systemImage: "line.3.horizontal.decrease")
                            .padding(.horizontal, 8).frame(height: 44)
                            .background(.indigo.opacity(0.15))
                            .offset(x: playback == 0 || finished ? 0 : 110)
                            .animation(animation(.easeOut(duration: 0.32)), value: finished)
                    }
                    .frame(width: 150, height: 44).clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(width: 160)
            Button {
                playback += 1
            } label: {
                Image(systemName: "play.fill").frame(width: 22, height: 22)
            }
            .help(language.text("播放动效示例", "Play motion example"))
            .accessibilityLabel(language.text("播放动效示例", "Play motion example"))
        }
        .task(id: playback) {
            guard playback > 0 else { return }
            finished = false
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            finished = true
        }
    }

    private func animation(_ animation: Animation) -> Animation? {
        finished && !reduceMotion ? animation : nil
    }

    private func track(_ label: String, animation timing: Animation) -> some View {
        HStack {
            Text(label).font(.caption.monospaced()).frame(width: 52, alignment: .trailing)
            Capsule().fill(.indigo.opacity(0.14)).frame(width: 88, height: 10)
                .overlay(alignment: .leading) {
                    Circle().fill(.indigo).frame(width: 10)
                        .offset(x: finished ? 78 : 0)
                        .animation(animation(timing), value: finished)
                }
        }
    }
}
