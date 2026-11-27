import SwiftUI

struct FrontendReference: View {
    let language: AppLanguage
    @Binding var query: String
    @Binding var category: TermCategory?
    var searchFocused: FocusState<Bool>.Binding

    var body: some View {
        let words = query.split { $0.isWhitespace || $0 == "-" }.map(String.init)
        let matches = FrontendTerm.all.compactMap { term in
            term.searchRank(for: words).map { (rank: $0, term: term) }
        }.sorted { $0.rank < $1.rank }.map(\.term)
        let counts = Dictionary(grouping: matches, by: \.category).mapValues(\.count)
        let results = matches.filter { category == nil || $0.category == category }
        return VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField(language.text("搜索中文或英文术语", "Search in English or Chinese"), text: $query)
                    .textFieldStyle(.plain)
                    .focused(searchFocused)
                    .accessibilityIdentifier("design-atlas-search")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.text("清除搜索", "Clear search"))
                }
            }
            .foregroundStyle(Palette.secondary)
            .padding(9)
            .background(Palette.board, in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        categoryButton(nil, count: matches.count)
                        ForEach(TermCategory.allCases, id: \.self) { group in
                            if group == .style { Divider().padding(.vertical, 4) }
                            categoryButton(group, count: counts[group, default: 0])
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 7)
                }
                .frame(width: language == .chinese ? 145 : 174)
                .background(Palette.board.opacity(0.44))
                Divider()
                resultList(results, hasOtherMatches: !matches.isEmpty)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 14)
            }
        }
        .background(Palette.surface)
        .foregroundStyle(Palette.primary)
        .preferredColorScheme(.light)
    }

    private func categoryButton(_ group: TermCategory?, count: Int) -> some View {
        let selected = category == group
        return Button {
            category = group
        } label: {
            HStack {
                Text(group?.title(language) ?? language.text("全部", "All"))
                Spacer(minLength: 2)
                Text(String(count)).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
            }
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(selected ? Palette.selected : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func resultList(_ results: [FrontendTerm], hasOtherMatches: Bool) -> some View {
        if results.isEmpty {
            ContentUnavailableView {
                Label(language.text("没有匹配的术语", "No matching terms"), systemImage: "magnifyingglass")
            } actions: {
                if hasOtherMatches {
                    Button(language.text("在全部分类中查找", "Search all categories")) { category = nil }
                } else {
                    Button(language.text("查看全部术语", "Show all terms")) { query = ""; category = nil }
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 14)], spacing: 14) {
                    ForEach(results) { term in
                        TermCard(term: term, language: language)
                    }
                }
                .padding(.vertical, 16)
            }
            .id(results.map(\.id))
        }
    }

}

private struct TermCard: View {
    let term: FrontendTerm
    let language: AppLanguage
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(language.text(term.chinese, term.english)).font(.headline)
                Text(language.text(term.english, term.chinese))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            TermSample(kind: term.kind, language: language)
                .accessibilityHidden(term.category != .motion)
            Text(term.definition(language))
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Divider()
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.text("标注示例", "Example feedback"))
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                    Text(term.example(language))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    let board = NSPasteboard.general
                    board.clearContents()
                    copied = board.setString(term.example(language), forType: .string)
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help(language.text("复制标注示例", "Copy example feedback"))
                .accessibilityLabel(copied ? language.text("已复制", "Copied") : language.text("复制标注示例", "Copy example feedback"))
                .task(id: copied) {
                    guard copied else { return }
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled { copied = false }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line) }
    }
}

private struct TermSample: View {
    let kind: FrontendTerm.Kind
    let language: AppLanguage
    private let blue = Color(nsColor: Ink.color(0x4959AD))
    private let pale = Color(nsColor: Ink.color(0xE1E5FB))
    private let paper = Color(nsColor: Ink.color(0xF4F5FA))

    var body: some View {
        sample
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(paper, in: RoundedRectangle(cornerRadius: 7))
    }

    private func chip(_ text: String, filled: Bool = false) -> some View {
        Text(text)
            .foregroundStyle(filled ? .white : blue)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(filled ? blue : .white, in: RoundedRectangle(cornerRadius: 5))
            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(blue, lineWidth: 1) }
    }

    private func fieldRow(_ text: String, symbol: String? = nil) -> some View {
        HStack {
            Text(text)
            Spacer()
            if let symbol { Image(systemName: symbol) }
        }
        .padding(7).frame(width: 162)
        .background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.line) }
    }

    @ViewBuilder private var sample: some View {
        switch kind {
        case .illustrated(let illustration):
            ReferenceSample(illustration: illustration, language: language)
        case .design(let concept):
            DesignSample(concept: concept, language: language)
        case .button:
            HStack {
                chip(language.text("保存", "Save"), filled: true)
                chip(language.text("取消", "Cancel"))
            }
        case .input:
            VStack(alignment: .leading, spacing: 4) {
                Text(language.text("邮箱", "Email")).font(.caption.bold())
                fieldRow("name@example.com").foregroundStyle(Palette.muted)
            }
        case .dropdown:
            fieldRow(language.text("最近更新", "Recently updated"), symbol: "chevron.down")
        case .checkbox:
            HStack(spacing: 18) {
                Label(language.text("图片", "Images"), systemImage: "checkmark.square.fill")
                Label(language.text("视频", "Videos"), systemImage: "square")
            }.foregroundStyle(blue)
        case .radio:
            HStack(spacing: 18) {
                Label(language.text("月付", "Monthly"), systemImage: "circle.inset.filled")
                Label(language.text("年付", "Yearly"), systemImage: "circle")
            }.foregroundStyle(blue)
        case .toggle:
            HStack {
                Text(language.text("邮件通知", "Email notifications"))
                Capsule().fill(blue).frame(width: 30, height: 18)
                    .overlay(alignment: .trailing) { Circle().fill(.white).padding(2) }
            }
        case .tabs:
            HStack(spacing: 20) {
                Text(language.text("概览", "Overview")).padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(blue).frame(height: 2) }
                    .foregroundStyle(blue)
                Text(language.text("动态", "Activity"))
            }
        case .breadcrumb:
            HStack {
                Text(language.text("项目", "Projects")).foregroundStyle(blue)
                Image(systemName: "chevron.right").font(.caption2)
                Text(language.text("设置", "Settings"))
            }
        case .pagination:
            HStack(spacing: 12) {
                Image(systemName: "chevron.left").foregroundStyle(.tertiary)
                chip("1", filled: true)
                Text("2")
                Text("3")
                Image(systemName: "chevron.right")
            }
        case .card:
            VStack(alignment: .leading, spacing: 4) {
                Label(language.text("设计评审", "Design review"), systemImage: "folder").bold()
                Text(language.text("今天更新", "Updated today")).font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(9).frame(width: 160, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line) }
        case .badge:
            HStack {
                Text(language.text("设计规范", "Style guide"))
                Text(language.text("已发布", "Published")).font(.caption.bold())
                    .foregroundStyle(Color(nsColor: Ink.color(0x24674D)))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color(nsColor: Ink.color(0xD7EFDF)), in: Capsule())
            }
        case .dialog:
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.22))
                VStack(spacing: 4) {
                    Text(language.text("删除项目？", "Delete project?")).bold()
                    HStack {
                        Text(language.text("取消", "Cancel"))
                        Text(language.text("删除", "Delete")).foregroundStyle(.red)
                    }.font(.caption)
                }.padding(8).background(.white, in: RoundedRectangle(cornerRadius: 5))
            }.frame(width: 166, height: 62)
        case .toast:
            Label(language.text("已保存", "Saved"), systemImage: "checkmark.circle")
                .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8)
                .background(Palette.primary, in: RoundedRectangle(cornerRadius: 6))
        case .padding:
            HStack(spacing: 0) {
                measure("16")
                Text(language.text("内容", "Content")).padding(5).background(.white)
                measure("16")
            }.padding(.vertical, 6).background(pale)
                .overlay { Rectangle().strokeBorder(blue) }
        case .margin:
            VStack(spacing: 0) {
                Rectangle().fill(Palette.muted).frame(width: 76, height: 2)
                Text("↕ 16 px").font(.caption.monospaced()).foregroundStyle(blue)
                chip(language.text("卡片", "Card"))
            }
        case .gap:
            HStack(spacing: 0) {
                chip("A")
                measure("12")
                chip("B")
                measure("12")
                chip("C")
            }
        case .radius:
            HStack(spacing: 16) {
                ForEach([4, 12], id: \.self) { radius in
                    Text("\(radius) px").font(.caption.monospaced()).frame(width: 60, height: 34)
                        .background(pale, in: RoundedRectangle(cornerRadius: CGFloat(radius)))
                        .overlay { RoundedRectangle(cornerRadius: CGFloat(radius)).strokeBorder(blue) }
                }
            }
        case .lineHeight:
            HStack(spacing: 18) {
                ForEach([18, 24], id: \.self) { height in
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<2) { _ in
                                Text("Aa").font(.system(size: 16))
                                    .frame(height: CGFloat(height))
                                    .background(alignment: .bottom) { Rectangle().fill(pale).frame(height: 1) }
                            }
                        }
                        Text("\(height) px").font(.caption.monospaced()).foregroundStyle(blue)
                    }
                }
            }
        }
    }

    private func measure(_ value: String) -> some View {
        Text("↔\(value)").font(.system(size: 10, design: .monospaced))
            .foregroundStyle(blue).padding(.horizontal, 3)
    }
}
