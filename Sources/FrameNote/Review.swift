import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum MarkTool: String, CaseIterable, Codable {
    case pin, region, arrow, lasso, brush

    func label(in language: AppLanguage) -> String {
        switch self {
        case .pin: language.text("点", "Pin")
        case .region: language.text("框", "Box")
        case .arrow: language.text("箭头", "Arrow")
        case .lasso: language.text("圈选", "Lasso")
        case .brush: language.text("涂抹", "Brush")
        }
    }

    var icon: String {
        switch self {
        case .pin: "scope"
        case .region: "rectangle.dashed"
        case .arrow: "arrow.up.right"
        case .lasso: "lasso"
        case .brush: "paintbrush.pointed"
        }
    }

    var shortcut: String {
        switch self {
        case .pin: "1"
        case .region: "2"
        case .arrow: "3"
        case .lasso: "4"
        case .brush: "5"
        }
    }

    var drawsFreehand: Bool { self == .lasso || self == .brush }
    var hasEndpointGrips: Bool { self == .region || self == .arrow }

    func instruction(in language: AppLanguage) -> String {
        switch self {
        case .pin: language.text("点击要说明的位置", "Click to place a pin")
        case .region: language.text("拖动选中要说明的区域", "Drag to draw a box")
        case .arrow: language.text("从起点拖向要指出的位置", "Drag to draw an arrow")
        case .lasso: language.text("拖动画任意形状，回到起点附近可闭合", "Draw any shape. Return near the start to close it.")
        case .brush: language.text("在图上拖动涂抹", "Drag to paint on the image")
        }
    }
}

struct ImagePoint: Codable, Equatable {
    var x: Double
    var y: Double

    init(_ point: CGPoint) { x = point.x; y = point.y }
    var point: CGPoint { CGPoint(x: x, y: y) }

    func translated(by offset: CGSize) -> Self {
        Self(CGPoint(x: x + offset.width, y: y + offset.height))
    }
}

enum NoteField: Hashable { case problem, desired }

struct Mark: Codable, Identifiable, Equatable {
    var id = UUID()
    var number = 0
    var tool: MarkTool
    var start: ImagePoint
    var end: ImagePoint
    var problem = ""
    var desired = ""
    var stroke: [ImagePoint]?
    var brushWidth: CGFloat?
    var closesStroke: Bool?

    static func freehand(number: Int, tool: MarkTool, points: [ImagePoint], brushWidth: CGFloat?, closesStroke: Bool? = nil) -> Self? {
        guard let first = points.first, let last = points.last else { return nil }
        return Self(number: number, tool: tool, start: first, end: last, stroke: points, brushWidth: brushWidth, closesStroke: closesStroke)
    }

    var isClosedLasso: Bool { tool == .lasso && (stroke?.count ?? 0) > 2 && (closesStroke ?? true) }

    var hasFeedback: Bool {
        !problem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !desired.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var bounds: CGRect {
        let endpoints = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                               width: abs(start.x - end.x), height: abs(start.y - end.y))
        return stroke?.reduce(endpoints) { $0.union(CGRect(origin: $1.point, size: .zero)) } ?? endpoints
    }

    func summary(in language: AppLanguage) -> String {
        for value in [problem, desired] {
            if let line = value.split(whereSeparator: \.isNewline)
                .map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) {
                return line
            }
        }
        return language.text("待填写说明", "Add feedback")
    }

    static func constrainedOffset(_ proposed: CGSize, for marks: [Mark], within size: CGSize) -> CGSize {
        marks.reduce(proposed) { offset, mark in
            let bounds = mark.bounds
            return CGSize(width: max(-bounds.minX, min(offset.width, size.width - bounds.maxX)),
                          height: max(-bounds.minY, min(offset.height, size.height - bounds.maxY)))
        }
    }

    func translated(by offset: CGSize) -> Self {
        var result = self
        result.start = start.translated(by: offset)
        result.end = end.translated(by: offset)
        result.stroke = stroke?.map { $0.translated(by: offset) }
        return result
    }

    func location(in size: CGSize, language: AppLanguage) -> String {
        func coordinates(_ position: CGPoint) -> String {
            "(\(Int(position.x.rounded())), \(Int(position.y.rounded())))"
        }
        switch tool {
        case .pin:
            let p = start.point
            let x = Int((p.x / size.width * 100).rounded())
            let y = Int((p.y / size.height * 100).rounded())
            return language.text("点 \(coordinates(p)) · 距左 \(x)%、距顶 \(y)%",
                                 "Pin \(coordinates(p)) · \(x)% from left, \(y)% from top")
        case .region:
            let width = Int(bounds.width.rounded())
            let height = Int(bounds.height.rounded())
            return language.text("区域左上 \(coordinates(bounds.origin)) · 宽 \(width) × 高 \(height)",
                                 "Box top-left \(coordinates(bounds.origin)) · \(width) × \(height) px")
        case .arrow:
            return "\(tool.label(in: language)) \(coordinates(start.point)) → \(coordinates(end.point))"
        case .lasso, .brush:
            let area = tool == .brush ? bounds.insetBy(dx: -(brushWidth ?? 1) / 2, dy: -(brushWidth ?? 1) / 2) : bounds
            let rect = area.intersection(CGRect(origin: .zero, size: size)).integral
            let dimensions = "\(max(1, Int(rect.width))) × \(max(1, Int(rect.height))) px"
            return language.text("\(tool.label(in: language))范围左上 \(coordinates(rect.origin)) · \(dimensions)",
                                 "\(tool.label(in: language)) bounds at \(coordinates(rect.origin)) · \(dimensions)")
        }
    }
}

struct ReviewImage: Identifiable {
    let id: UUID
    let name: String
    let image: CGImage
    let originalData: Data?

    init(id: UUID = UUID(), name: String, image: CGImage, originalData: Data? = nil) {
        self.id = id
        self.name = name
        self.image = image
        self.originalData = originalData
    }

    var size: CGSize { CGSize(width: image.width, height: image.height) }

    static func read(_ data: Data, name: String, id: UUID = UUID()) -> Self? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary)
        else { return nil }
        return Self(id: id, name: name, image: image, originalData: data)
    }

    static func read(_ url: URL) -> Self? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return read(data, name: url.lastPathComponent)
    }

    static func paste(from pasteboard: NSPasteboard, language: AppLanguage = .chinese) -> Self? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let result = urls.lazy.compactMap({ read($0) }).first {
            return result
        }
        for type: NSPasteboard.PasteboardType in [.png, .tiff, .init(UTType.jpeg.identifier), .init(UTType.heic.identifier)] {
            if let data = pasteboard.data(forType: type),
               let result = read(data, name: language.text("剪贴板图片.png", "Clipboard image.png")) {
                return result
            }
        }
        return nil
    }
}

struct Review {
    var source: ReviewImage?
    var marks: [Mark] = []
    var selectedIDs: Set<UUID> = []
    var nextNumber = 1

    var selectedID: UUID? { selectedIDs.count == 1 ? selectedIDs.first : nil }
    var hasFeedback: Bool { marks.contains(where: \.hasFeedback) }

    func markdown(in language: AppLanguage = .chinese) -> String {
        guard let source else { return "" }
        let filename = source.name.replacingOccurrences(of: "\n", with: " ")
        var lines = [
            "# \(language.text("截图评审", "Screenshot review")) · \(filename)",
            "",
            language.text("原图尺寸为 \(source.image.width) × \(source.image.height) px，坐标原点在原图左上角。请按截图中的编号逐项处理，并说明每项改动。",
                          "Original image: \(source.image.width) × \(source.image.height) px. Coordinates start at the top-left. Address each numbered annotation and describe the changes."),
            ""
        ]
        for mark in marks {
            lines += ["## \(mark.number). \(mark.location(in: source.size, language: language))", ""]
            for (label, value) in [(language.text("当前问题", "Current issue"), mark.problem),
                                   (language.text("期望调整", "Requested change"), mark.desired)] {
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { lines += ["**\(label)**", "", cleaned, ""] }
            }
            if !mark.hasFeedback {
                lines += [language.text("（说明待填写）", "(No written feedback yet)"), ""]
            }
        }
        return lines.joined(separator: "\n")
    }
}

final class ReviewStore {
    private struct Record: Codable {
        var id: UUID
        var name: String
        var marks: [Mark]
        var selectedID: UUID?
        var selectedIDs: Set<UUID>?
        var nextNumber: Int
    }

    private let directory: URL
    private let queue = DispatchQueue(label: "local.framenote.draft", qos: .utility)
    private var pending: DispatchWorkItem?

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "FrameNote", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    private var recordURL: URL { directory.appending(path: "draft.json") }

    func load() -> Review {
        guard let data = try? Data(contentsOf: recordURL),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              let pixels = try? Data(contentsOf: imageURL(record.id), options: .mappedIfSafe),
              let source = ReviewImage.read(pixels, name: record.name, id: record.id)
        else { return Review() }
        let selection = record.selectedIDs ?? Set(record.selectedID.map { [$0] } ?? [])
        return Review(source: source, marks: record.marks, selectedIDs: selection.intersection(record.marks.map(\.id)),
                      nextNumber: record.nextNumber)
    }

    func schedule(_ review: Review) {
        pending?.cancel()
        let operation = DispatchWorkItem { [self] in
            do { try write(review) } catch { NSLog("FrameNote draft: %@", error.localizedDescription) }
        }
        pending = operation
        queue.asyncAfter(deadline: .now() + .milliseconds(400), execute: operation)
    }

    func flush(_ review: Review) {
        pending?.cancel()
        queue.sync {
            do { try write(review) } catch { NSLog("FrameNote draft: %@", error.localizedDescription) }
        }
    }

    private func imageURL(_ id: UUID) -> URL { directory.appending(path: "\(id.uuidString).image") }

    private func write(_ review: Review) throws {
        let fm = FileManager.default
        guard let source = review.source else {
            if fm.fileExists(atPath: recordURL.path) { try fm.removeItem(at: recordURL) }
            removeUnusedImages(keeping: nil)
            return
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let pixels = imageURL(source.id)
        if !fm.fileExists(atPath: pixels.path) {
            try (source.originalData ?? ImageExport.pngData(source.image)).write(to: pixels, options: .atomic)
        }
        let record = Record(id: source.id, name: source.name, marks: review.marks, selectedID: review.selectedID,
                            selectedIDs: review.selectedIDs, nextNumber: review.nextNumber)
        try JSONEncoder().encode(record).write(to: recordURL, options: .atomic)
        removeUnusedImages(keeping: pixels.lastPathComponent)
    }

    private func removeUnusedImages(keeping filename: String?) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "image" && file.lastPathComponent != filename {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

struct ExportPreviewRequest: Identifiable {
    let id = UUID()
    let review: Review
    let appearance: AnnotationAppearance
    let language: AppLanguage
}

struct ColorReplacementDraft {
    let id = UUID()
    var point: ImagePoint?
    var sample: ColorSample?
    var targetHex = ""

    var target: AnnotationAppearance? { AnnotationAppearance(hexString: targetHex) }
}

final class ReviewModel: ObservableObject {
    private static let hideWindowKey = "hideWindowDuringCapture"
    private static let annotationColorKey = "annotationColor"
    private static let languageKey = "appLanguage"
    private static let defaultTool: MarkTool = .region

    @Published var review: Review { didSet { store.schedule(review) } }
    @Published private(set) var chosenLanguage: AppLanguage? {
        didSet { preferences.set(chosenLanguage?.rawValue, forKey: Self.languageKey) }
    }
    @Published private(set) var tool: MarkTool? = ReviewModel.defaultTool
    @Published private(set) var colorReplacement: ColorReplacementDraft?
    @Published var showAnnotationColors = false
    @Published var showDesignAtlas = false
    @Published var zoom: Double?
    @Published var visibleZoom: Double = 1
    @Published var viewportReset = 0
    @Published var revealRequest = 0
    @Published var requestedFocus = 0
    @Published var notice = ""
    @Published var capturing = false
    @Published var exportPreview: ExportPreviewRequest?
    @Published var annotationAppearance: AnnotationAppearance {
        didSet { preferences.set(Int(annotationAppearance.hex), forKey: Self.annotationColorKey) }
    }
    @Published var hideWindowDuringCapture: Bool {
        didSet { preferences.set(hideWindowDuringCapture, forKey: Self.hideWindowKey) }
    }

    private let store: ReviewStore
    private let preferences: UserDefaults
    private var past: [Review] = []
    private var future: [Review] = []
    private var typing: (UUID, NoteField, Date)?
    private var noticeTask: DispatchWorkItem?
    private var sampleTask: Task<Void, Never>?

    init(store: ReviewStore = ReviewStore(), preferences: UserDefaults = .standard) {
        self.store = store
        self.preferences = preferences
        review = store.load()
        chosenLanguage = preferences.string(forKey: Self.languageKey).flatMap(AppLanguage.init(rawValue:))
        let savedColor = preferences.object(forKey: Self.annotationColorKey) as? Int ?? Int(Ink.logoBlue)
        annotationAppearance = AnnotationAppearance((0...0xFFFFFF).contains(savedColor) ? UInt32(savedColor) : Ink.logoBlue)
        hideWindowDuringCapture = preferences.object(forKey: Self.hideWindowKey) as? Bool ?? true
    }

    var language: AppLanguage { chosenLanguage ?? .chinese }
    var selectedMark: Mark? { review.marks.first { $0.id == review.selectedID } }
    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    func chooseLanguage(_ language: AppLanguage) {
        chosenLanguage = language
        noticeTask?.cancel()
        notice = ""
    }

    func notify(_ message: String) {
        noticeTask?.cancel()
        notice = message
        let task = DispatchWorkItem { [weak self] in self?.notice = "" }
        noticeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: task)
    }

    func accept(_ source: ReviewImage, marks: [Mark] = []) {
        remember()
        chooseTool(Self.defaultTool)
        zoom = nil
        viewportReset += 1
        let numbered = marks.enumerated().map { index, mark in
            var numbered = mark
            numbered.number = index + 1
            return numbered
        }
        review = Review(source: source, marks: numbered, selectedIDs: Set(numbered.prefix(1).map(\.id)),
                        nextNumber: numbered.count + 1)
    }

    func open(_ url: URL) {
        guard let asset = ReviewImage.read(url) else {
            notify(language.text("无法打开这张图片", "Could not open this image"))
            return
        }
        accept(asset)
    }

    func paste() {
        guard let image = ReviewImage.paste(from: .general, language: language) else {
            notify(language.text("剪贴板里没有可打开的图片", "The clipboard does not contain an image"))
            return
        }
        accept(image)
    }

    func select(_ id: UUID?) {
        select(Set(id.map { [$0] } ?? []))
    }

    func select(_ ids: Set<UUID>) {
        guard review.selectedIDs != ids else { return }
        typing = nil
        review.selectedIDs = ids
    }

    func selectAllMarks() {
        guard !review.marks.isEmpty else { return }
        chooseTool(nil)
        select(Set(review.marks.map(\.id)))
    }

    func chooseTool(_ next: MarkTool?) {
        if colorReplacement != nil {
            sampleTask?.cancel()
            sampleTask = nil
            colorReplacement = nil
        }
        tool = next
    }

    func beginColorReplacement() {
        guard review.source != nil, colorReplacement == nil else { return }
        tool = nil
        colorReplacement = ColorReplacementDraft()
    }

    func sampleColor(at position: CGPoint) {
        guard colorReplacement != nil, let image = review.source?.image else { return }
        let point = ImagePoint(CGPoint(x: position.x.rounded(.down), y: position.y.rounded(.down)))
        let draft = ColorReplacementDraft(point: point)
        colorReplacement = draft
        sampleTask?.cancel()
        sampleTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) { ColorSample.make(in: image, at: point) }
            let sample = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled, let self, self.colorReplacement?.id == draft.id else { return }
            self.sampleTask = nil
            if let sample {
                var ready = draft
                ready.sample = sample
                ready.targetHex = sample.original.hexString
                self.colorReplacement = ready
            } else {
                self.colorReplacement = ColorReplacementDraft()
                self.notify(self.language.text("无法在这里取色，请点击图中有颜色的位置", "Click a visible pixel to sample its color"))
            }
        }
    }

    func setReplacementHex(_ hex: String) {
        guard colorReplacement?.sample != nil else { return }
        colorReplacement?.targetHex = hex
    }

    func useColorReplacement() {
        guard let draft = colorReplacement, let point = draft.point, let sample = draft.sample,
              let target = draft.target, target != sample.original else { return }
        let hex = target.hexString
        let desired = language.text("将该处的颜色替换成“\(hex)”", "Replace the color here with “\(hex)”")
        chooseTool(nil)
        append(Mark(tool: .pin, start: point, end: point, desired: desired), focusEditor: false)
    }

    func reveal(_ id: UUID) {
        select(id)
        revealRequest += 1
    }

    func add(_ tool: MarkTool, start: CGPoint, end: CGPoint) {
        append(Mark(tool: tool, start: ImagePoint(start), end: ImagePoint(end)))
    }

    func add(_ mark: Mark) {
        append(mark)
    }

    private func append(_ mark: Mark, focusEditor: Bool = true) {
        remember()
        var next = review
        var numbered = mark
        numbered.number = next.nextNumber
        next.marks.append(numbered)
        next.nextNumber += 1
        next.selectedIDs = [mark.id]
        review = next
        if focusEditor { requestedFocus += 1 }
    }

    func updatePositions(_ marks: [Mark]) {
        let positions = Dictionary(uniqueKeysWithValues: marks.map { ($0.id, $0) })
        var next = review
        for index in next.marks.indices {
            guard let changed = positions[next.marks[index].id] else { continue }
            next.marks[index].start = changed.start
            next.marks[index].end = changed.end
            next.marks[index].stroke = changed.stroke
        }
        guard next.marks != review.marks else { return }
        remember()
        review = next
    }

    func edit(_ id: UUID, field: NoteField, text: String) {
        guard let index = review.marks.firstIndex(where: { $0.id == id }) else { return }
        let path: WritableKeyPath<Mark, String> = field == .problem ? \.problem : \.desired
        guard review.marks[index][keyPath: path] != text else { return }
        let now = Date()
        if typing?.0 != id || typing?.1 != field || now.timeIntervalSince(typing?.2 ?? .distantPast) > 0.9 {
            remember()
        }
        typing = (id, field, now)
        review.marks[index][keyPath: path] = text
    }

    func removeSelected() {
        let selected = review.selectedIDs
        guard let index = review.marks.firstIndex(where: { selected.contains($0.id) }) else { return }
        remember()
        var next = review
        next.marks.removeAll { selected.contains($0.id) }
        next.selectedIDs = []
        if selected.count == 1, !next.marks.isEmpty {
            next.selectedIDs = [next.marks[min(index, next.marks.count - 1)].id]
        }
        review = next
    }

    func undo() {
        guard let previous = past.popLast() else { return }
        future.append(review)
        restore(previous)
    }

    func redo() {
        guard let next = future.popLast() else { return }
        past.append(review)
        restore(next)
    }

    func fit() {
        zoom = nil
        viewportReset += 1
    }

    func adjustZoom(by factor: Double) {
        zoom = min(8, max(0.05, visibleZoom * factor))
    }

    func flush() { store.flush(review) }

    private func remember() {
        past.append(review)
        if past.count > 35 { past.removeFirst() }
        future.removeAll()
        typing = nil
    }

    private func restore(_ previous: Review) {
        if previous.source?.id != review.source?.id {
            if colorReplacement != nil { chooseTool(nil) }
            fit()
        }
        typing = nil
        review = previous
    }
}
