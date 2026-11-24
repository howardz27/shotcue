import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum Palette {
    static let board = Color(nsColor: Ink.color(0xF0F1F3))
    static let surface = Color.white
    static let line = Color(nsColor: Ink.color(0xE1E3E8))
    static let primary = Color(nsColor: Ink.color(0x17191E))
    static let secondary = Color(nsColor: Ink.color(0x424750))
    static let muted = Color(nsColor: Ink.color(0x626873))
    static let primaryAction = Color(nsColor: Ink.color(0x17191E))
    static let primaryInk = Color(nsColor: Ink.color(0xFFFFFF))
    static let selected = Color(nsColor: Ink.color(0xEEF0F3))
}

struct Workspace: View {
    @ObservedObject var model: ReviewModel
    let actions: AppActions
    private var language: AppLanguage { model.language }
    @State private var dropTarget = false
    @State private var showCaptureOptions = false
    @State private var showSaveOptions = false
    @State private var showLanguageOptions = false

    private var accent: Color { Color(nsColor: model.annotationAppearance.textAccent) }

    var body: some View {
        if model.chosenLanguage == nil {
            LanguageWelcome(choose: actions.chooseLanguage)
        } else {
            editor
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                board
                if model.review.source != nil {
                    Rectangle().fill(Palette.line).frame(width: 1)
                    Group {
                        if let draft = model.colorReplacement {
                            ColorReplacementPanel(model: model, draft: draft)
                                .id(draft.id)
                        } else {
                            NotesPanel(model: model)
                        }
                    }
                    .frame(width: 332)
                }
            }
        }
        .foregroundStyle(Palette.primary)
        .background(Palette.surface)
        .tint(accent)
        .preferredColorScheme(.light)
        .sheet(item: $model.exportPreview) { request in
            ExportPreview(review: request.review, appearance: request.appearance, language: request.language)
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTarget, perform: receiveDrop)
    }

    private var toolbar: some View {
        GeometryReader { geometry in
            let english = language == .english
            let width = geometry.size.width
            toolbarContent(compact: width < (english ? 1630 : 1380),
                           narrow: width < (english ? 1200 : 1080),
                           showToolLabels: width >= (english ? 1450 : 1240))
                .frame(width: width, height: geometry.size.height)
        }
        .frame(height: 52)
        .background(Palette.surface)
        .overlay(alignment: .bottom) { rule.allowsHitTesting(false) }
    }

    private func toolbarContent(compact: Bool, narrow: Bool, showToolLabels: Bool) -> some View {
        let hasImage = model.review.source != nil
        return HStack(spacing: narrow ? 5 : compact ? 6 : 9) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("ShotCue")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.45)
            }
            .fixedSize()

            languageButton(showsLabel: !narrow)

            Rectangle().fill(Palette.line).frame(width: 1, height: 17)
                .padding(.trailing, 3)

            HStack(spacing: 0) {
                toolbarUtility(language.text("打开", "Open"), icon: "folder", hint: language.text("打开图片  ⌘O", "Open image  ⌘O"),
                               compact: narrow, action: actions.open)
                toolbarUtility(language.text("粘贴", "Paste"), icon: "doc.on.clipboard", hint: language.text("粘贴图片  ⌘V", "Paste image  ⌘V"), compact: compact, action: model.paste)
                captureControls(iconOnly: narrow)
            }
            .fixedSize()

            toolbarDragSpace

            HStack(spacing: 7) {
                HStack(spacing: 2) {
                    ToolButton(label: language.text("选择", "Select"), icon: "cursorarrow", hint: language.text("选择和移动标注  V", "Select and move annotations  V"),
                               selected: hasImage && model.tool == nil && model.colorReplacement == nil, showsLabel: !compact) {
                        model.chooseTool(nil)
                    }
                    ForEach(MarkTool.allCases, id: \.self) { tool in
                        ToolButton(label: tool.label(in: language), icon: tool.icon, hint: "\(tool.instruction(in: language))  \(tool.shortcut)",
                                   selected: hasImage && model.tool == tool, showsLabel: showToolLabels) { model.chooseTool(tool) }
                    }
                    ToolButton(label: language.text("换色", "Replace Color"), icon: "eyedropper",
                               hint: language.text("点击图中颜色并预览换色  6", "Sample a color and preview a replacement  6"),
                               selected: model.colorReplacement != nil, showsLabel: showToolLabels) {
                        model.beginColorReplacement()
                    }
                }
                .padding(3)
                .background(Palette.board, in: RoundedRectangle(cornerRadius: 8))
                .disabled(!hasImage)
                .opacity(hasImage ? 1 : 0.54)

                annotationColorButton

                HStack(spacing: 2) {
                    IconButton(language.text("撤销", "Undo"), icon: "arrow.uturn.backward", hint: language.text("撤销  ⌘Z", "Undo  ⌘Z"), action: model.undo)
                        .disabled(!model.canUndo)
                    IconButton(language.text("重做", "Redo"), icon: "arrow.uturn.forward", hint: language.text("重做  ⌘⇧Z", "Redo  ⌘⇧Z"), action: model.redo)
                        .disabled(!model.canRedo)
                }
            }
            .fixedSize()

            toolbarDragSpace

            HStack(spacing: 5) {
                ActionButton(language.text("预览", "Preview"), icon: "eye", hint: language.text("预览导出图片  ⌘Y", "Preview export  ⌘Y"),
                             kind: .quiet, action: actions.previewExport)
                    .disabled(!hasImage)
                ActionButton(language.text("复制图片", "Copy Image"), icon: "photo.on.rectangle", hint: language.text("复制标注图片  ⌘⌥C", "Copy annotated image  ⌘⌥C"),
                             kind: .primary, showsLabel: !narrow, action: actions.copyImage)
                    .disabled(!hasImage)
                toolbarUtility(language.text("复制反馈", "Copy Feedback"), icon: "doc.on.doc", hint: language.text("复制给 Agent 的 Markdown  ⌘⇧C", "Copy Markdown feedback for your agent  ⌘⇧C"),
                               compact: compact, action: actions.copyFeedback)
                    .disabled(model.review.marks.isEmpty)
                ActionButton(language.text("保存", "Save"), icon: "square.and.arrow.down", hint: language.text("保存为 PNG 或 Markdown", "Save as PNG or Markdown"), kind: .outline, showsMenu: true, showsLabel: !narrow) {
                    showSaveOptions.toggle()
                }
                .disabled(!hasImage)
                .popover(isPresented: $showSaveOptions, arrowEdge: .bottom) {
                    VStack(spacing: 3) {
                        ToolbarChoice(language.text("保存图片（PNG）", "Save Image (PNG)"), icon: "photo") {
                            showSaveOptions = false
                            actions.saveImage()
                        }
                        ToolbarChoice(language.text("保存反馈（Markdown）", "Save Feedback (Markdown)"), icon: "doc.text") {
                            showSaveOptions = false
                            actions.saveFeedback()
                        }
                        .disabled(model.review.marks.isEmpty)
                    }
                    .padding(6)
                    .frame(width: 211)
                }
            }
            .fixedSize()
        }
        .padding(.leading, 82)
        .padding(.trailing, 13)
    }

    private func languageButton(showsLabel: Bool) -> some View {
        ActionButton(language.text("语言", "Language"), icon: "globe",
                     hint: language.text("切换界面语言", "Change interface language"), kind: .outline,
                     showsMenu: true, showsLabel: showsLabel) {
            showLanguageOptions.toggle()
        }
        .fixedSize()
        .accessibilityValue(language.name)
        .accessibilityIdentifier("workspace-language")
        .popover(isPresented: $showLanguageOptions, arrowEdge: .bottom) {
            VStack(spacing: 3) {
                ForEach(AppLanguage.allCases, id: \.self) { option in
                    ToolbarChoice(option.name, icon: option == language ? "checkmark" : nil) {
                        showLanguageOptions = false
                        actions.chooseLanguage(option)
                    }
                    .accessibilityAddTraits(option == language ? .isSelected : [])
                    .accessibilityIdentifier("workspace-language-\(option.rawValue)")
                }
            }
            .padding(6)
            .frame(width: 146)
        }
    }

    @ViewBuilder
    private func toolbarUtility(_ title: String, icon: String, hint: String, compact: Bool, action: @escaping () -> Void) -> some View {
        if compact {
            IconButton(title, icon: icon, hint: hint, action: action)
        } else {
            ActionButton(title, icon: icon, hint: hint, kind: .quiet, action: action)
        }
    }

    private var toolbarDragSpace: some View {
        WindowDragArea()
            .frame(minWidth: 7, maxWidth: .infinity)
            .frame(height: 36)
    }

    private var annotationColorButton: some View {
        Button {
            model.showAnnotationColors.toggle()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(nsColor: model.annotationAppearance.fill))
                    .overlay { Circle().strokeBorder(.black.opacity(0.16)) }
                    .frame(width: 15, height: 15)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(width: 34, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButton(kind: .quiet))
        .accessibilityLabel(language.text("标注颜色", "Annotation Color"))
        .accessibilityIdentifier("annotation-color")
        .help(language.text("选择标注颜色", "Choose annotation color"))
        .popover(isPresented: $model.showAnnotationColors, arrowEdge: .bottom) {
            ColorOptions(selection: $model.annotationAppearance, language: language,
                         title: language.text("标注颜色", "Annotation Color"))
        }
    }

    private func captureControls(iconOnly: Bool) -> some View {
        HStack(spacing: 0) {
            toolbarUtility(language.text("截图", "Capture"), icon: "camera.viewfinder",
                           hint: language.text("截取屏幕区域  ⌘⇧S", "Capture a screen area  ⌘⇧S"),
                           compact: iconOnly, action: actions.capture)
            IconButton(language.text("截图设置", "Capture Settings"), icon: "chevron.down", hint: language.text("设置截图时是否隐藏窗口", "Choose whether to hide ShotCue during capture")) {
                showCaptureOptions.toggle()
            }
            .popover(isPresented: $showCaptureOptions, arrowEdge: .bottom) {
                Toggle(language.text("截图时隐藏 ShotCue 窗口", "Hide ShotCue during capture"), isOn: $model.hideWindowDuringCapture)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .fixedSize()
            }
        }
        .disabled(model.capturing)
    }

    private var rule: some View { Rectangle().fill(Palette.line).frame(height: 1) }

    private var board: some View {
        VStack(spacing: 0) {
            ZStack {
                if model.review.source != nil {
                    AnnotationCanvas(model: model)
                } else {
                    emptyBoard
                }

                if dropTarget {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(accent.opacity(0.11))
                        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5])) }
                        .padding(14)
                        .overlay {
                            Label(language.text("松开以打开图片", "Drop to open image"), systemImage: "arrow.down.to.line")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(Palette.selected, in: Capsule())
                        }
                        .allowsHitTesting(false)
                }
                if !model.notice.isEmpty {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(accent)
                            Text(model.notice).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 15).padding(.vertical, 10)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line) }
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        .padding(.top, 14)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .accessibilityLabel(model.notice)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.easeInOut(duration: 0.16), value: model.notice)
            if model.review.source != nil { canvasFooter }
        }
        .background(Palette.board)
    }

    private var emptyBoard: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)
                .padding(.bottom, 16)
            Text(language.text("打开图片开始标注", "Open an image to start annotating"))
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.7)
                .padding(.bottom, 8)
            Text(language.text("也可以拖入文件、粘贴图片或截取屏幕", "Drag in a file, paste an image, or capture your screen"))
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 24)
            HStack(spacing: 8) {
                ActionButton(language.text("打开图片", "Open Image"), icon: "folder", hint: language.text("打开图片  ⌘O", "Open image  ⌘O"), kind: .primary, action: actions.open)
                ActionButton(language.text("粘贴", "Paste"), icon: "doc.on.clipboard", hint: language.text("粘贴图片  ⌘V", "Paste image  ⌘V"), kind: .outline, action: model.paste)
                ActionButton(language.text("截图", "Capture"), icon: "camera.viewfinder", hint: language.text("截取屏幕区域  ⌘⇧S", "Capture a screen area  ⌘⇧S"), kind: .outline, action: actions.capture)
                    .disabled(model.capturing)
            }
            Button(action: actions.openDemo) {
                HStack(spacing: 5) {
                    Text(language.text("查看评审示例", "View sample review"))
                    Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 13)
        }
        .padding(28)
    }

    private var canvasFooter: some View {
        let replacingColor = model.colorReplacement != nil
        let toolIcon = replacingColor ? "eyedropper" : model.tool?.icon ?? "cursorarrow"
        let instruction = replacingColor ? language.text("点击图中位置取色", "Click the image to sample a color")
            : model.tool?.instruction(in: language) ?? language.text("点击选择 · 拖框多选", "Click to select · drag to select multiple")
        return HStack(spacing: 8) {
            if let source = model.review.source {
                Image(systemName: "photo")
                    .foregroundStyle(.black)
                    .accessibilityHidden(true)
                Text(source.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(source.name)
                Text(verbatim: "\(source.image.width) × \(source.image.height) px")
                    .fontDesign(.monospaced)
                    .foregroundStyle(Palette.muted)
                    .fixedSize()
            }

            Spacer(minLength: 4)

            ViewThatFits(in: .horizontal) {
                Label(instruction, systemImage: toolIcon)
                    .fixedSize()
                Image(systemName: toolIcon)
                    .help(instruction)
                    .accessibilityLabel(instruction)
            }
            .foregroundStyle(.black)
            Rectangle().fill(Palette.line).frame(width: 1, height: 13).padding(.horizontal, 3)
            IconButton(language.text("缩小", "Zoom Out"), icon: "minus", hint: language.text("缩小", "Zoom Out"), action: { model.adjustZoom(by: 1 / 1.25) })
            Text("\(Int((model.visibleZoom * 100).rounded()))%")
                .monospacedDigit()
                .frame(minWidth: 33)
                .accessibilityLabel(language.text("缩放", "Zoom") + " \(Int((model.visibleZoom * 100).rounded()))%")
            IconButton(language.text("放大", "Zoom In"), icon: "plus", hint: language.text("放大", "Zoom In"), action: { model.adjustZoom(by: 1.25) })
            ActionButton(language.text("适合", "Fit"), icon: "arrow.up.left.and.arrow.down.right", hint: language.text("适合窗口  0", "Fit to window  0"), kind: .quiet, action: model.fit)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Palette.secondary)
        .padding(.horizontal, 14)
        .frame(height: 41)
        .background(Palette.surface)
        .overlay(alignment: .top) { rule }
    }

    private func receiveDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                guard let url else {
                    DispatchQueue.main.async { model.notify(language.text("无法读取拖入的文件", "Could not read the dropped file")) }
                    return
                }
                let image = ReviewImage.read(url)
                DispatchQueue.main.async {
                    if let image { model.accept(image) }
                    else { model.notify(language.text("无法打开拖入的图片", "Could not open the dropped image")) }
                }
            }
        } else {
            let type = provider.registeredTypeIdentifiers.first {
                UTType($0)?.conforms(to: .image) == true
            } ?? UTType.image.identifier
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                let name = provider.suggestedName ?? language.text("拖入的图片", "Dropped image")
                let image = data.flatMap { ReviewImage.read($0, name: name) }
                DispatchQueue.main.async {
                    if let image { model.accept(image) }
                    else { model.notify(language.text("无法读取拖入的图片", "Could not read the dropped image")) }
                }
            }
        }
        return true
    }
}

private struct LanguageWelcome: View {
    let choose: (AppLanguage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)
                .padding(.bottom, 8)
            Text("ShotCue")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 25)
            Text("选择界面语言")
                .font(.system(size: 26, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 5)
            Text("Choose your language")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 24)
            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases, id: \.self) { option in
                    Button { choose(option) } label: {
                        HStack {
                            Text(option.name).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.muted)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .frame(width: 264, height: 43)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HoverButton(kind: .outline))
                    .accessibilityIdentifier("welcome-language-\(option.rawValue)")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Palette.primary)
        .background(Palette.board)
        .overlay(alignment: .top) {
            WindowDragArea().frame(height: 44).padding(.leading, 82)
        }
        .preferredColorScheme(.light)
    }
}

private struct ColorOptions: View {
    @Binding var selection: AnnotationAppearance
    let language: AppLanguage
    var title: String? = nil
    var showsHexInput = true
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    @State private var hexInput = ""

    private var presets: [(name: String, hex: UInt32)] { [
        (language.text("默认蓝", "Default blue"), Ink.logoBlue), (language.text("青色", "Teal"), 0x2BC6BC), (language.text("绿色", "Green"), 0x58C778),
        (language.text("橙色", "Orange"), 0xF9A14A), (language.text("红色", "Red"), 0xF16668), (language.text("黑色", "Black"), 0x202329)
    ] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.system(size: 13, weight: .semibold)) }
            HStack(spacing: 7) {
                ForEach(presets, id: \.hex) { preset in
                    let appearance = AnnotationAppearance(preset.hex)
                    Button { setColor(appearance) } label: {
                        Circle()
                            .fill(Color(nsColor: appearance.fill))
                            .overlay { Circle().strokeBorder(.black.opacity(0.15)) }
                            .overlay {
                                if selection == appearance {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(nsColor: appearance.foreground))
                                }
                            }
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(selection == appearance ? .isSelected : [])
                    .help(preset.name)
                }
            }
            Divider()
            Text(language.text("自定义颜色", "Custom Color")).font(.system(size: 12, weight: .medium))
            colorField.frame(height: 100)
            hueTrack.frame(height: 14)
            if showsHexInput {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(nsColor: selection.fill))
                        .overlay { Circle().strokeBorder(.black.opacity(0.15)) }
                        .frame(width: 20, height: 20)
                    TextField(language.text("色值", "Hex color"), text: $hexInput)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if let appearance = AnnotationAppearance(hexString: hexInput) {
                                setColor(appearance)
                            } else {
                                hexInput = selection.hexString
                            }
                        }
                }
            }
        }
        .padding(14)
        .frame(width: 232)
        .onAppear { loadColor(selection) }
        .onChange(of: selection) { _, next in
            if hexInput != next.hexString { loadColor(next) }
        }
    }

    private var colorField: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                               startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .background(.black.opacity(0.32), in: Circle())
                    .frame(width: 13, height: 13)
                    .position(x: 7 + saturation * (size.width - 14), y: 7 + (1 - brightness) * (size.height - 14))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                saturation = unitInterval((value.location.x - 7) / (size.width - 14))
                brightness = 1 - unitInterval((value.location.y - 7) / (size.height - 14))
                applyComponents()
            })
        }
        .accessibilityLabel(language.text("饱和度和亮度", "Saturation and brightness"))
    }

    private var hueTrack: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) },
                               startPoint: .leading, endPoint: .trailing)
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .position(x: 7 + hue * (width - 14), y: 7)
            }
            .clipShape(Capsule())
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                hue = unitInterval((value.location.x - 7) / (width - 14))
                applyComponents()
            })
        }
        .accessibilityLabel(language.text("色相", "Hue"))
        .accessibilityAdjustableAction { direction in
            hue = unitInterval(hue + (direction == .increment ? 0.025 : -0.025))
            applyComponents()
        }
    }

    private func unitInterval(_ value: Double) -> Double { max(0, min(1, value)) }

    private func setColor(_ appearance: AnnotationAppearance) {
        selection = appearance
        loadColor(appearance)
    }

    private func loadColor(_ appearance: AnnotationAppearance) {
        var newHue: CGFloat = 0
        var newSaturation: CGFloat = 0
        var newBrightness: CGFloat = 0
        appearance.fill.getHue(&newHue, saturation: &newSaturation, brightness: &newBrightness, alpha: nil)
        hue = newHue
        saturation = newSaturation
        brightness = newBrightness
        hexInput = appearance.hexString
    }

    private func applyComponents() {
        let color = Color(hue: hue, saturation: saturation, brightness: brightness)
        guard let appearance = AnnotationAppearance(color: NSColor(color)) else { return }
        if appearance != selection { selection = appearance }
        hexInput = appearance.hexString
    }
}

private struct ColorReplacementPanel: View {
    @ObservedObject var model: ReviewModel
    let draft: ColorReplacementDraft
    @State private var showTargetPalette = false

    private var language: AppLanguage { model.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.text("替换颜色", "Replace Color"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                IconButton(language.text("取消换色", "Cancel Color Replacement"), icon: "xmark",
                           hint: language.text("取消换色  Esc", "Cancel color replacement  Esc")) { model.chooseTool(nil) }
            }
            .padding(.horizontal, 20)
            .frame(height: 57)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }

            VStack(alignment: .leading, spacing: 16) {
                if let sample = draft.sample {
                    colorControls(sample)
                } else if draft.point != nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(language.text("正在取色…", "Sampling color…"))
                    }
                } else {
                    Text(language.text("点击图中要换色的位置。", "Click the area you want to recolor."))
                }
            }
            .font(.system(size: 13))
            .padding(20)
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(Palette.surface)
    }

    private func colorControls(_ sample: ColorSample) -> some View {
        let targetLabel = language.text("目标颜色", "Target color")
        let hex = Binding(get: { model.colorReplacement?.targetHex ?? "" }, set: model.setReplacementHex)
        let color = Binding(get: { model.colorReplacement?.target ?? sample.original }, set: { picked in
            model.setReplacementHex(picked.hexString)
        })
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(language.text("原始颜色", "Sampled color"))
                Spacer()
                Circle()
                    .fill(Color(nsColor: sample.original.fill))
                    .overlay { Circle().strokeBorder(.black.opacity(0.16)) }
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(verbatim: sample.original.hexString).monospaced()
            }
            HStack(spacing: 8) {
                Text(targetLabel)
                Spacer()
                Button { showTargetPalette.toggle() } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(nsColor: color.wrappedValue.fill))
                            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.16)) }
                            .frame(width: 21, height: 15)
                        Image(systemName: showTargetPalette ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 5)
                    .frame(height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButton(kind: .outline))
                .accessibilityLabel(language.text("选择目标颜色", "Pick target color"))
                .accessibilityValue(color.wrappedValue.hexString)
                .accessibilityAddTraits(showTargetPalette ? .isSelected : [])
                TextField(targetLabel, text: hex, prompt: Text("#RRGGBB"))
                    .textFieldStyle(.roundedBorder)
                    .monospaced()
                    .frame(width: 90)
                    .accessibilityLabel(language.text("目标色号", "Target hex color"))
            }
            if showTargetPalette {
                ColorOptions(selection: color, language: language, showsHexInput: false)
                    .background(Palette.board, in: RoundedRectangle(cornerRadius: 8))
            }
            Text(draft.target == nil
                 ? language.text("请输入 6 位十六进制色号。", "Enter a six-digit hex color.")
                 : language.text("画布实时预览，点击图中其他位置可重新取色。", "Preview updates as you choose a color. Click the image to sample again."))
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            ActionButton(language.text("选用", "Use Color"), icon: "checkmark",
                         hint: language.text("生成换色反馈", "Add color replacement feedback"), kind: .primary,
                         action: model.useColorReplacement)
                .disabled(draft.target == nil || draft.target == sample.original)
        }
    }
}

private struct NotesPanel: View {
    @ObservedObject var model: ReviewModel
    private var language: AppLanguage { model.language }
    @FocusState private var focused: EditTarget?

    private struct EditTarget: Hashable {
        let id: UUID
        let field: NoteField
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Text(language.text("反馈清单", "Feedback")).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(model.review.selectedIDs.count > 1
                     ? language.text("已选 \(model.review.selectedIDs.count) 条", "\(model.review.selectedIDs.count) selected")
                     : language.annotationCount(model.review.marks.count))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 20)
            .frame(height: 57)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }

            if model.review.marks.isEmpty {
                VStack(spacing: 10) {
                    Text(language.text("还没有标注", "No annotations yet")).font(.system(size: 14, weight: .semibold))
                    Text(language.text("在图上添加标注，再写下希望怎么改", "Mark a spot on the image and describe what to change"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            } else {
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.review.marks) { mark in
                                noteCard(mark)
                                    .id(mark.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .onChange(of: model.review.selectedID, initial: true) { _, next in
                        guard let next else { return }
                        withAnimation(.easeOut(duration: 0.16)) { scroll.scrollTo(next) }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Palette.surface)
        .onChange(of: model.requestedFocus) { _, _ in
            guard let id = model.review.selectedID else { return }
            DispatchQueue.main.async {
                if model.review.selectedID == id { focused = EditTarget(id: id, field: .problem) }
            }
        }
    }

    private func noteCard(_ mark: Mark) -> some View {
        let selected = model.review.selectedID == mark.id
        let highlighted = model.review.selectedIDs.contains(mark.id)
        let number = mark.number
        let appearance = model.annotationAppearance

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    if !selected { focused = nil }
                    model.reveal(mark.id)
                } label: {
                    HStack(spacing: 9) {
                        Text(String(number))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(nsColor: appearance.foreground))
                            .frame(minWidth: 22, minHeight: 22)
                            .padding(.horizontal, number >= 100 ? 4 : 0)
                            .background(Color(nsColor: appearance.fill), in: RoundedRectangle(cornerRadius: 5))
                        Text(selected ? language.text("\(mark.tool.label(in: language))标注", "\(mark.tool.label(in: language)) annotation")
                                      : mark.summary(in: language))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected || mark.hasFeedback ? Palette.primary : Palette.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if !selected {
                            Image(systemName: mark.tool.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("标注 \(number)，\(mark.tool.label(in: language))，\(mark.summary(in: language))",
                                                  "Annotation \(number), \(mark.tool.label(in: language)), \(mark.summary(in: language))"))

                if selected {
                    IconButton(language.text("删除标注", "Delete Annotation"), icon: "trash", hint: language.text("删除这条标注", "Delete this annotation"), action: model.removeSelected)
                }
            }
            .padding(.horizontal, 10)

            if selected, let source = model.review.source {
                HStack(spacing: 5) {
                    Image(systemName: "location").font(.system(size: 9, weight: .semibold))
                    Text(mark.location(in: source.size, language: language))
                        .font(.system(size: 10.5, design: .monospaced))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 12).padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 11) {
                    editor(mark, field: .problem, title: language.text("当前问题", "Current issue"), placeholder: language.text("这里出了什么问题？", "What is wrong here?"))
                    editor(mark, field: .desired, title: language.text("期望调整", "Requested change"), placeholder: language.text("希望它变成什么样？", "What should change?"))
                }
                .padding(.horizontal, 10).padding(.bottom, 11)
            }
        }
        .background(highlighted ? Palette.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottom) {
            if !selected {
                Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 10)
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 3)
    }

    private func editor(_ mark: Mark, field: NoteField, title: String, placeholder: String) -> some View {
        let target = EditTarget(id: mark.id, field: field)
        let binding = Binding<String>(
            get: { model.review.marks.first { $0.id == mark.id }.map { field == .problem ? $0.problem : $0.desired } ?? "" },
            set: { model.edit(mark.id, field: field, text: $0) }
        )
        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.secondary)
                .accessibilityHidden(true)
            TextField(title, text: binding, prompt: Text(""), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineSpacing(3)
                .lineLimit(2...6)
                .focused($focused, equals: target)
                .accessibilityLabel(title)
                .overlay(alignment: .topLeading) {
                    if binding.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(focused == target ? Color(nsColor: model.annotationAppearance.textAccent) : Palette.line,
                                      lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct ToolButton: View {
    let label: String
    let icon: String
    let hint: String
    let selected: Bool
    let showsLabel: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                if showsLabel {
                    Text(label).font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 27)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButton(kind: selected ? .selected : .quiet))
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(hint)
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let hint: String
    let kind: HoverButton.Kind
    let showsMenu: Bool
    let showsLabel: Bool
    let action: () -> Void

    init(_ title: String, icon: String, hint: String, kind: HoverButton.Kind, showsMenu: Bool = false, showsLabel: Bool = true,
         action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.hint = hint
        self.kind = kind
        self.showsMenu = showsMenu
        self.showsLabel = showsLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                if showsLabel { Text(title).font(.system(size: 12, weight: .semibold)) }
                if showsMenu {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, kind == .quiet ? 7 : 10)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButton(kind: kind))
        .accessibilityLabel(title)
        .help(hint)
    }
}

private struct IconButton: View {
    let title: String
    let icon: String
    let hint: String
    let action: () -> Void

    init(_ title: String, icon: String, hint: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.hint = hint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 25, height: 27)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverButton(kind: .quiet))
        .accessibilityLabel(title)
        .help(hint)
    }
}

private struct HoverButton: ButtonStyle {
    enum Kind { case quiet, outline, primary, selected }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, kind: kind)
    }

    private struct Surface: View {
        let configuration: Configuration
        let kind: Kind
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(kind == .primary ? Palette.primaryInk : kind == .quiet ? Palette.secondary : Palette.primary)
                .background(background, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    if kind == .outline {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Palette.line)
                            .allowsHitTesting(false)
                    }
                }
                .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
                .onHover { hovering = $0 }
        }

        private var background: Color {
            switch kind {
            case .quiet: hovering && enabled ? Palette.primary.opacity(0.08) : .clear
            case .outline: hovering && enabled ? Palette.selected : Palette.surface
            case .primary: hovering && enabled ? Color(nsColor: Ink.color(0x333841)) : Palette.primaryAction
            case .selected: Palette.surface
            }
        }
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> Draggable { Draggable() }
    func updateNSView(_ nsView: Draggable, context: Context) {}

    final class Draggable: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.zoom(nil) }
            else { window?.performDrag(with: event) }
        }
    }
}

private struct ToolbarChoice: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String?, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 16, height: 16)
                    .overlay {
                        if let icon { Image(systemName: icon) }
                    }
                    .accessibilityHidden(true)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButton(kind: .quiet))
    }
}

private struct ExportPreview: View {
    let review: Review
    let appearance: AnnotationAppearance
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var phase = Phase.loading
    @State private var fitWidth = false

    private enum Phase {
        case loading
        case ready(CGImage)
        case failure(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(language.text("导出预览", "Export Preview"))
                        .font(.system(size: 16, weight: .semibold))
                    if case let .ready(image) = phase {
                        Text(verbatim: "PNG  ·  \(image.width) × \(image.height) px  ·  \(language.annotationCount(review.marks.count))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                if case .ready = phase {
                    ActionButton(fitWidth ? language.text("查看整张", "Fit to Window") : language.text("适合宽度", "Fit Width"),
                                 icon: fitWidth ? "arrow.down.right.and.arrow.up.left" : "arrow.left.and.right",
                                 hint: language.text("切换预览缩放", "Change preview zoom"), kind: .outline) { fitWidth.toggle() }
                }
                ActionButton(language.text("关闭", "Close"), icon: "xmark", hint: language.text("关闭导出预览", "Close export preview"), kind: .quiet) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18)
            .frame(height: 64)
            .background(Palette.surface)
            Divider()

            switch phase {
            case .loading:
                ProgressView(language.text("正在生成预览…", "Rendering preview…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready(let pixels):
                if fitWidth {
                    ScrollView {
                        previewImage(pixels)
                            .frame(maxWidth: CGFloat(pixels.width))
                            .frame(maxWidth: .infinity)
                            .padding(24)
                    }
                } else {
                    GeometryReader { viewport in
                        let width = min(CGFloat(pixels.width), viewport.size.width,
                                        viewport.size.height * CGFloat(pixels.width) / CGFloat(pixels.height))
                        previewImage(pixels)
                            .frame(width: width)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(24)
                }
            case .failure(let message):
                ContentUnavailableView(language.text("预览失败", "Could Not Preview"), systemImage: "exclamationmark.circle", description: Text(message))
            }
        }
        .frame(width: 750, height: 545)
        .background(Palette.board)
        .foregroundStyle(Palette.primary)
        .task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try ImageExport.render(review, appearance: appearance, language: language) }
            }.value
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let pixels): phase = .ready(pixels)
            case .failure(let error):
                phase = .failure((error as? ImageExport.Failure)?.message(in: language) ?? error.localizedDescription)
            }
        }
    }

    private func previewImage(_ pixels: CGImage) -> some View {
        Image(pixels, scale: 1, label: Text(review.hasFeedback ? language.text("标注图片和反馈清单", "Annotated image and feedback") : language.text("标注图片", "Annotated image")))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .background(.white)
            .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }
}
