import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum MarkTool: String, CaseIterable, Codable {
    case pin, region, arrow

    var label: String {
        switch self {
        case .pin: "点"
        case .region: "框"
        case .arrow: "箭头"
        }
    }

    var icon: String {
        switch self {
        case .pin: "scope"
        case .region: "rectangle.dashed"
        case .arrow: "arrow.up.right"
        }
    }

    var shortcut: String {
        switch self {
        case .pin: "1"
        case .region: "2"
        case .arrow: "3"
        }
    }

    var instruction: String {
        switch self {
        case .pin: "点击要说明的位置"
        case .region: "拖动选中要说明的区域"
        case .arrow: "从起点拖向要指出的位置"
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

    var hasFeedback: Bool {
        !problem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !desired.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var bounds: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(start.x - end.x), height: abs(start.y - end.y))
    }

    var summary: String {
        for value in [problem, desired] {
            if let line = value.split(whereSeparator: \.isNewline)
                .map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) {
                return line
            }
        }
        return "待填写说明"
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
        return result
    }

    func location(in size: CGSize) -> String {
        func coordinates(_ position: CGPoint) -> String {
            "(\(Int(position.x.rounded())), \(Int(position.y.rounded())))"
        }
        switch tool {
        case .pin:
            let p = start.point
            let x = Int((p.x / size.width * 100).rounded())
            let y = Int((p.y / size.height * 100).rounded())
            return "点 \(coordinates(p)) · 距左 \(x)%、距顶 \(y)%"
        case .region:
            return "区域左上 \(coordinates(bounds.origin)) · 宽 \(Int(bounds.width.rounded())) × 高 \(Int(bounds.height.rounded()))"
        case .arrow:
            return "箭头 \(coordinates(start.point)) → \(coordinates(end.point))"
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

    static func paste(from pasteboard: NSPasteboard) -> Self? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let result = urls.lazy.compactMap({ read($0) }).first {
            return result
        }
        for type: NSPasteboard.PasteboardType in [.png, .tiff, .init(UTType.jpeg.identifier), .init(UTType.heic.identifier)] {
            if let data = pasteboard.data(forType: type), let result = read(data, name: "剪贴板图片.png") {
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

    var markdown: String {
        guard let source else { return "" }
        let filename = source.name.replacingOccurrences(of: "\n", with: " ")
        var lines = [
            "# 截图评审 · \(filename)",
            "",
            "原图尺寸为 \(source.image.width) × \(source.image.height) px，坐标原点在原图左上角。请按截图中的编号逐项处理，并说明每项改动。",
            ""
        ]
        for mark in marks {
            lines += ["## \(mark.number). \(mark.location(in: source.size))", ""]
            for (label, value) in [("当前问题", mark.problem), ("期望调整", mark.desired)] {
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { lines += ["**\(label)**", "", cleaned, ""] }
            }
            if !mark.hasFeedback {
                lines += ["（说明待填写）", ""]
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
}

final class ReviewModel: ObservableObject {
    private static let hideWindowKey = "hideWindowDuringCapture"
    private static let annotationColorKey = "annotationColor"
    private static let defaultTool: MarkTool = .region

    @Published var review: Review { didSet { store.schedule(review) } }
    @Published var tool: MarkTool? = ReviewModel.defaultTool
    @Published var showAnnotationColors = false
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

    init(store: ReviewStore = ReviewStore(), preferences: UserDefaults = .standard) {
        self.store = store
        self.preferences = preferences
        review = store.load()
        let savedColor = preferences.object(forKey: Self.annotationColorKey) as? Int ?? Int(Ink.logoBlue)
        annotationAppearance = AnnotationAppearance((0...0xFFFFFF).contains(savedColor) ? UInt32(savedColor) : Ink.logoBlue)
        hideWindowDuringCapture = preferences.object(forKey: Self.hideWindowKey) as? Bool ?? true
    }

    var selectedMark: Mark? { review.marks.first { $0.id == review.selectedID } }
    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    func notify(_ message: String) {
        noticeTask?.cancel()
        notice = message
        let task = DispatchWorkItem { [weak self] in self?.notice = "" }
        noticeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: task)
    }

    func accept(_ source: ReviewImage, marks: [Mark] = []) {
        remember()
        tool = Self.defaultTool
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
            notify("无法打开这张图片")
            return
        }
        accept(asset)
    }

    func paste() {
        guard let image = ReviewImage.paste(from: .general) else {
            notify("剪贴板里没有可打开的图片")
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
        tool = nil
        select(Set(review.marks.map(\.id)))
    }

    func reveal(_ id: UUID) {
        select(id)
        revealRequest += 1
    }

    func add(_ tool: MarkTool, start: CGPoint, end: CGPoint) {
        remember()
        let mark = Mark(number: review.nextNumber, tool: tool, start: ImagePoint(start), end: ImagePoint(end))
        var next = review
        next.marks.append(mark)
        next.nextNumber += 1
        next.selectedIDs = [mark.id]
        review = next
        requestedFocus += 1
    }

    func updatePositions(_ marks: [Mark]) {
        let positions = Dictionary(uniqueKeysWithValues: marks.map { ($0.id, $0) })
        var next = review
        for index in next.marks.indices {
            guard let changed = positions[next.marks[index].id] else { continue }
            next.marks[index].start = changed.start
            next.marks[index].end = changed.end
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
        if previous.source?.id != review.source?.id { fit() }
        typing = nil
        review = previous
    }
}
