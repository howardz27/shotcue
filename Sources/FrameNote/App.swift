import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class AppActions: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let model: ReviewModel
    private var editorWindow: NSWindow?
    private var captureProcess: Process?
    private var captureDirectory: URL?
    private var saveDialog: NSSavePanel?
    private var pendingURL: URL?
    private var copyRequest = 0

    init(model: ReviewModel = ReviewModel()) {
        self.model = model
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        installMenus()

        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1180, height: 770),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "ShotCue"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.backgroundColor = Ink.color(0xFFFFFF)
        window.contentMinSize = NSSize(width: 920, height: 540)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        let hostingView = NSHostingView(rootView: Workspace(model: model, actions: self))
        hostingView.safeAreaRegions = []
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("FrameNoteWorkspace")

        editorWindow = window
        if let pendingURL { model.open(pendingURL); self.pendingURL = nil }
        if CommandLine.arguments.contains("--demo"), model.review.source == nil { openDemo() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else { sender.reply(toOpenOrPrint: .failure); return }
        let url = URL(fileURLWithPath: filename)
        if editorWindow == nil { pendingURL = url }
        else { model.open(url); editorWindow?.makeKeyAndOrderFront(nil) }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        editorWindow?.makeKeyAndOrderFront(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if captureProcess?.isRunning == true { captureProcess?.terminate() }
        if let captureDirectory { try? FileManager.default.removeItem(at: captureDirectory) }
        model.flush()
    }

    @objc func open() {
        guard let window = editorWindow, window.attachedSheet == nil else { return }
        let panel = NSOpenPanel()
        panel.message = "选择要评审的截图或图片"
        panel.prompt = "打开图片"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] result in
            if result == .OK, let url = panel.url { self?.model.open(url) }
        }
    }

    @objc func openDemo() {
        guard let (image, marks) = Demo.make() else { return }
        model.accept(image, marks: marks)
    }

    @objc func capture() {
        guard !model.capturing, let window = editorWindow, window.attachedSheet == nil else { return }
        let hideWindow = model.hideWindowDuringCapture && window.isVisible
        let directory = FileManager.default.temporaryDirectory.appending(path: "FrameNote-\(UUID().uuidString)")
        let destination = directory.appending(path: "screen.png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        } catch {
            model.notify("无法创建临时截图文件")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", "-t", "png", destination.path]
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        process.terminationHandler = { [weak self] _ in
            let error = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let image = (try? Data(contentsOf: destination)).flatMap { data in
                let date = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
                    .timeZone(separator: .omitted).timeSeparator(.omitted).dateSeparator(.dash))
                return ReviewImage.read(data, name: "截图-\(date).png")
            }
            try? FileManager.default.removeItem(at: directory)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                finishCapture(hiddenWindow: hideWindow, didCapture: image != nil)
                if let image { model.accept(image) }
                else if !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.notify("截图未生成，请检查「屏幕录制」权限或粘贴系统截图")
                }
            }
        }
        captureProcess = process
        captureDirectory = directory
        model.capturing = true
        if hideWindow { NSApp.hide(nil) }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(hideWindow ? 170 : 0)) { [weak self] in
            do { try process.run() }
            catch {
                try? FileManager.default.removeItem(at: directory)
                guard let self else { return }
                finishCapture(hiddenWindow: hideWindow)
                model.notify("无法启动系统截图")
            }
        }
    }

    private func finishCapture(hiddenWindow: Bool, didCapture: Bool = false) {
        captureProcess = nil
        captureDirectory = nil
        model.capturing = false
        if hiddenWindow { NSApp.unhide(nil) }
        if hiddenWindow || didCapture {
            editorWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func toggleCaptureWindowVisibility() {
        model.hideWindowDuringCapture.toggle()
    }

    @objc func pasteImage() { model.paste() }

    @objc func paste() {
        if isEditingText {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        } else {
            model.paste()
        }
    }

    private var isEditingText: Bool {
        let responder = editorWindow?.firstResponder
        return responder is NSTextView || responder is NSTextField || responder is NSTextInputClient
    }

    @objc func copyImage() {
        let review = model.review
        copyRequest += 1
        let request = copyRequest
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        renderPNG(review, appearance: model.annotationAppearance) { [weak self] data in
            guard let self, copyRequest == request else { return }
            guard pasteboard.changeCount == changeCount else {
                model.notify("剪贴板已有更新，请再次复制图片")
                return
            }
            let item = NSPasteboardItem()
            item.setData(data, forType: .png)
            pasteboard.clearContents()
            if pasteboard.writeObjects([item]) {
                model.notify(review.hasFeedback ? "已复制带标注和说明的 PNG" : "已复制 PNG 图片")
            } else {
                model.notify("无法写入剪贴板")
            }
        }
    }

    @objc func copyFeedback() {
        guard !model.review.marks.isEmpty else { return }
        copyRequest += 1
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(model.review.markdown, forType: .string) {
            model.notify("已复制反馈，可直接粘贴给 Agent")
        } else {
            model.notify("无法写入剪贴板")
        }
    }

    @objc func chooseAnnotationColor() {
        model.showAnnotationColors = true
    }

    @objc func previewExport() {
        let review = model.review
        guard review.source != nil, model.exportPreview == nil, saveDialog == nil else { return }
        model.exportPreview = ExportPreviewRequest(review: review, appearance: model.annotationAppearance)
    }

    @objc func saveImage() {
        let review = model.review
        guard let source = review.source else { return }
        let appearance = model.annotationAppearance
        savePanel(type: .png, title: "保存标注图片", name: suggestedName(source, suffix: "-标注.png")) { [weak self] url in
            self?.renderPNG(review, appearance: appearance) { data in self?.write(data, to: url) }
        }
    }

    @objc func saveFeedback() {
        let review = model.review
        guard let source = review.source, !review.marks.isEmpty else { return }
        savePanel(type: UTType(filenameExtension: "md") ?? .plainText, title: "保存 Markdown 反馈",
                  name: suggestedName(source, suffix: "-反馈.md")) {
            [weak self] url in
            self?.write(Data(review.markdown.utf8), to: url)
        }
    }

    private func suggestedName(_ source: ReviewImage, suffix: String) -> String {
        (source.name as NSString).deletingPathExtension + suffix
    }

    private func renderPNG(_ review: Review, appearance: AnnotationAppearance, complete: @escaping (Data) -> Void) {
        guard review.source != nil else { return }
        model.notify("正在生成 PNG…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try ImageExport.png(review, appearance: appearance) }
            DispatchQueue.main.async { [weak self] in
                switch result {
                case .success(let data): complete(data)
                case .failure(let error): self?.model.notify(error.localizedDescription)
                }
            }
        }
    }

    private func savePanel(type: UTType, title: String, name: String, complete: @escaping (URL) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = editorWindow, saveDialog == nil else { return }
            guard window.attachedSheet == nil else {
                model.notify("请先关闭当前对话框")
                return
            }
            let panel = NSSavePanel()
            panel.title = title
            panel.prompt = "保存"
            panel.allowedContentTypes = [type]
            panel.nameFieldStringValue = name
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.showsTagField = false
            saveDialog = panel
            panel.beginSheetModal(for: window) { [weak self, weak panel] result in
                guard let self else { return }
                let url = panel?.url
                saveDialog = nil
                guard result == .OK else { return }
                if let url { complete(url) }
                else { model.notify("未能获取保存位置，请重试") }
            }
        }
    }

    private func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
            model.notify("已保存 \(url.lastPathComponent)")
        } catch {
            model.notify("保存失败：\(error.localizedDescription)")
        }
    }

    @objc func undo() { model.undo() }
    @objc func redo() { model.redo() }
    @objc func fit() { model.fit() }
    @objc func zoomIn() { model.adjustZoom(by: 1.25) }
    @objc func zoomOut() { model.adjustZoom(by: 1 / 1.25) }
    @objc func deleteMark() { model.removeSelected() }
    @objc func selectAllMarks() { model.selectAllMarks() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undo): return model.canUndo
        case #selector(redo): return model.canRedo
        case #selector(copyImage), #selector(fit), #selector(zoomIn), #selector(zoomOut):
            return model.review.source != nil
        case #selector(saveImage), #selector(previewExport):
            return model.review.source != nil && model.exportPreview == nil && saveDialog == nil
        case #selector(saveFeedback):
            return !model.review.marks.isEmpty && model.exportPreview == nil && saveDialog == nil
        case #selector(copyFeedback): return !model.review.marks.isEmpty
        case #selector(deleteMark): return !model.review.selectedIDs.isEmpty
        case #selector(selectAllMarks): return !model.review.marks.isEmpty && !isEditingText
        case #selector(capture): return !model.capturing
        case #selector(toggleCaptureWindowVisibility):
            item.state = model.hideWindowDuringCapture ? .on : .off
            return !model.capturing
        default: return true
        }
    }

    private func installMenus() {
        let root = NSMenu()
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem()
            item.title = title
            let menu = NSMenu(title: title)
            item.submenu = menu
            root.addItem(item)
            return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
                 modifiers: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            menu.addItem(item)
        }

        let app = menu("ShotCue")
        add(app, "关于 ShotCue", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator())
        add(app, "隐藏 ShotCue", #selector(NSApplication.hide(_:)), "h")
        add(app, "退出 ShotCue", #selector(NSApplication.terminate(_:)), "q")

        let file = menu("文件")
        add(file, "打开图片…", #selector(open), "o", target: self)
        add(file, "截取屏幕区域…", #selector(capture), "s", modifiers: [.command, .shift], target: self)
        add(file, "截图时隐藏 ShotCue 窗口", #selector(toggleCaptureWindowVisibility), target: self)
        file.addItem(.separator())
        add(file, "预览导出图片…", #selector(previewExport), "y", target: self)
        add(file, "保存标注图片…", #selector(saveImage), "s", target: self)
        add(file, "保存 Markdown 反馈…", #selector(saveFeedback), target: self)
        file.addItem(.separator())
        add(file, "关闭窗口", #selector(NSWindow.performClose(_:)), "w")

        let edit = menu("编辑")
        add(edit, "撤销", #selector(undo), "z", target: self)
        add(edit, "重做", #selector(redo), "z", modifiers: [.command, .shift], target: self)
        edit.addItem(.separator())
        add(edit, "剪切", #selector(NSText.cut(_:)), "x")
        add(edit, "复制", #selector(NSText.copy(_:)), "c")
        add(edit, "粘贴", #selector(paste), "v", target: self)
        add(edit, "全选", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())
        add(edit, "粘贴图片", #selector(pasteImage), "v", modifiers: [.command, .option], target: self)
        add(edit, "复制标注图片", #selector(copyImage), "c", modifiers: [.command, .option], target: self)
        add(edit, "复制给 Agent 的反馈", #selector(copyFeedback), "c", modifiers: [.command, .shift], target: self)
        add(edit, "删除所选标注", #selector(deleteMark), target: self)
        add(edit, "全选标注", #selector(selectAllMarks), "a", modifiers: [.control], target: self)

        let view = menu("显示")
        add(view, "标注颜色…", #selector(chooseAnnotationColor), target: self)
        view.addItem(.separator())
        add(view, "适合窗口", #selector(fit), "0", target: self)
        add(view, "放大", #selector(zoomIn), "=", target: self)
        add(view, "缩小", #selector(zoomOut), "-", target: self)
        view.addItem(.separator())
        add(view, "进入或退出全屏", #selector(NSWindow.toggleFullScreen(_:)), "f", modifiers: [.command, .control])

        let help = menu("帮助")
        add(help, "打开评审示例", #selector(openDemo), target: self)
        NSApp.helpMenu = help
        NSApp.mainMenu = root
    }
}
