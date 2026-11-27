import SwiftUI

/// A user-triggered timeline plays one example, then stops requesting frames.
struct TimingSample: View {
    let motion: AnimationSpecimen
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started: Date?
    @State private var played = false

    private var duration: Double {
        switch motion {
        case .delay: 0.85
        case .stagger: 0.52
        default: 0.72
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: started == nil || reduceMotion)) { tick in
                let t = started.map { min(1, max(0, tick.date.timeIntervalSince($0) / duration)) } ?? (played ? 1 : 0)
                frame(reduceMotion ? (played ? 1 : 0) : t)
                    .frame(width: 135, height: 48)
            }
            Button {
                played = true
                started = Date()
            } label: { Image(systemName: "play.fill").frame(width: 22, height: 22) }
                .help(language.text("播放动效示例", "Play motion example"))
                .accessibilityLabel(language.text("播放动效示例", "Play motion example"))
        }
        .task(id: started) {
            guard started != nil else { return }
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled { started = nil }
        }
    }

    @ViewBuilder private func frame(_ t: Double) -> some View {
        switch motion {
        case .delay, .spring:
            let x = motion == .delay ? max(0, (t * duration - 0.3) / (duration - 0.3)) : 1 - exp(-6 * t) * cos(13 * t)
            Capsule().fill(.indigo.opacity(0.12)).frame(width: 103, height: 9)
                .overlay(alignment: .leading) { Circle().fill(.indigo).frame(width: 11).offset(x: 80 * x) }
        case .stagger:
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    let phase = max(0, min(1, (t * duration - Double(i) * 0.06) / 0.4))
                    RoundedRectangle(cornerRadius: 4).fill(.indigo).frame(width: 28, height: 27)
                        .opacity(0.12 + 0.88 * phase).offset(y: 5 * (1 - phase))
                }
            }
        case .scale:
            Label(language.text("菜单", "Menu"), systemImage: "line.3.horizontal")
                .padding(7).background(.white).scaleEffect(0.9 + 0.1 * t, anchor: .topLeading)
        case .crossfade:
            ZStack {
                Image(systemName: "moon.stars.fill").foregroundStyle(.indigo).opacity(1 - t)
                Image(systemName: "sun.max.fill").foregroundStyle(.orange).opacity(t)
            }.font(.title)
        case .rotation:
            Image(systemName: "chevron.right").font(.title3.bold()).foregroundStyle(.indigo).rotationEffect(.degrees(90 * t))
        case .press:
            let pressure = sin(t * .pi)
            Text(language.text("提交", "Submit")).foregroundStyle(.white).padding(8)
                .background(.indigo, in: RoundedRectangle(cornerRadius: 5)).brightness(-0.16 * pressure).scaleEffect(1 - 0.12 * pressure)
        case .shimmer:
            RoundedRectangle(cornerRadius: 5).fill(.indigo.opacity(0.2)).frame(width: 112, height: 30)
                .overlay {
                    LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 33).offset(x: -73 + 146 * t)
                }.clipShape(RoundedRectangle(cornerRadius: 5))
        case .shared:
            Image(systemName: "mountain.2.fill").foregroundStyle(.teal)
                .frame(width: 28 + 56 * t, height: 22 + 16 * t).background(.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
                .offset(x: -34 * (1 - t))
        case .keyframes:
            Text("name@").padding(6).frame(width: 88, alignment: .leading).background(.white).border(.red)
                .offset(x: -8 * sin(t * 2 * .pi))
        }
    }
}
