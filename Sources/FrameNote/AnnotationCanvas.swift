import AppKit
import SwiftUI

struct AnnotationCanvas: NSViewRepresentable {
    @ObservedObject var model: ReviewModel

    func makeNSView(context: Context) -> MarkCanvas {
        let canvas = MarkCanvas()
        canvas.setAccessibilityLabel("截图标注画布")
        return canvas
    }

    func updateNSView(_ canvas: MarkCanvas, context: Context) {
        canvas.update(from: model)
    }
}

final class MarkCanvas: NSView {
    private enum Endpoint { case start, end }

    private enum Gesture {
        case pan(origin: CGPoint, previous: CGPoint)
        case mark(start: CGPoint, current: CGPoint, tool: MarkTool)
        case move(start: CGPoint, original: [Mark], offset: CGSize)
        case marquee(start: CGPoint, current: CGPoint, retaining: Set<UUID>)
        case adjust(original: Mark, current: Mark, endpoint: Endpoint)
    }

    weak var model: ReviewModel?
    private var sourceID: UUID?
    private var zoomRequest: Double?
    private var viewportReset = -1
    private var revealRequest = 0
    private var pan = CGPoint.zero
    private var gesture: Gesture?
    private var spaceHeld = false
    private var eventMonitor: Any?
    private var mouseTracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityIdentifier("annotation-canvas")
    }

    required init?(coder: NSCoder) { fatalError("Use the programmatic canvas") }

    deinit {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyboard(event) ?? event
        }
    }

    override func updateTrackingAreas() {
        if let mouseTracking { removeTrackingArea(mouseTracking) }
        let next = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .mouseMoved,
                                                        .mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        addTrackingArea(next)
        mouseTracking = next
        super.updateTrackingAreas()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        constrainPan()
        relayZoom()
        needsDisplay = true
    }

    func update(from model: ReviewModel) {
        self.model = model
        let incoming = model.review.source?.id
        if sourceID != incoming || viewportReset != model.viewportReset {
            sourceID = incoming
            viewportReset = model.viewportReset
            pan = .zero
            gesture = nil
        }
        zoomRequest = model.zoom
        if revealRequest != model.revealRequest {
            revealRequest = model.revealRequest
            if let mark = model.selectedMark {
                reveal(mark)
            }
        }
        constrainPan()
        relayZoom()
        needsDisplay = true
    }

    private var scale: CGFloat {
        guard let size = model?.review.source?.size else { return 1 }
        if let zoomRequest { return zoomRequest }
        let available = CGSize(width: max(1, bounds.width - 58), height: max(1, bounds.height - 56))
        return min(1.5, available.width / size.width, available.height / size.height)
    }

    private var imageRect: CGRect {
        guard let size = model?.review.source?.size else { return .zero }
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: (bounds.width - width) / 2 + pan.x, y: (bounds.height - height) / 2 + pan.y,
                      width: width, height: height)
    }

    private var markerUnit: CGFloat { min(1, max(0.45, min(imageRect.width, imageRect.height) / 125)) }

    private func constrainPan() {
        let area = imageRect
        let xLimit = max(0, (area.width - bounds.width) / 2 + 34)
        let yLimit = max(0, (area.height - bounds.height) / 2 + 34)
        pan.x = max(-xLimit, min(xLimit, pan.x))
        pan.y = max(-yLimit, min(yLimit, pan.y))
    }

    private func relayZoom() {
        let actual = scale
        DispatchQueue.main.async { [weak self] in
            guard let self, let model, abs(actual - scale) < 0.0001, abs(model.visibleZoom - actual) > 0.001 else { return }
            model.visibleZoom = actual
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let model, let source = model.review.source, let context = NSGraphicsContext.current?.cgContext else { return }
        let imageRect = self.imageRect
        let appearance = model.annotationAppearance
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 12), blur: 32, color: NSColor.black.withAlphaComponent(0.13).cgColor)
        context.setFillColor(Ink.color(0xC1C6CE).cgColor)
        context.fill(imageRect.insetBy(dx: -1, dy: -1))
        context.restoreGState()
        context.saveGState()
        context.clip(to: imageRect)
        Ink.fill(context, imageRect, .white)
        context.interpolationQuality = scale >= 2 ? .none : .high
        Ink.drawPixels(source.image, in: imageRect, context: context)

        func draw(_ mark: Mark, selected: Bool) {
            MarkLayout(mark: mark, imageRect: imageRect, scale: scale, unit: markerUnit)
                .draw(number: mark.number, selected: selected, appearance: appearance, context: context)
        }

        var marks = model.review.marks
        var selection = model.review.selectedIDs
        var marqueeRect: CGRect?
        switch gesture {
        case let .move(_, original, offset):
            let moved = Dictionary(uniqueKeysWithValues: original.map { ($0.id, $0.translated(by: offset)) })
            marks = marks.map { moved[$0.id] ?? $0 }
        case let .adjust(original, current, _):
            if let index = marks.firstIndex(where: { $0.id == original.id }) { marks[index] = current }
        case let .marquee(start, current, retaining):
            let rect = rectangle(from: start, to: current)
            marqueeRect = rect
            selection = retaining.union(markIDs(in: rect, model: model))
        default: break
        }
        for mark in marks where !selection.contains(mark.id) {
            draw(mark, selected: false)
        }
        for selected in marks where selection.contains(selected.id) {
            draw(selected, selected: true)
            if selection.count == 1, marqueeRect == nil, selected.tool != .pin {
                let layout = MarkLayout(mark: selected, imageRect: imageRect, scale: scale, unit: markerUnit)
                for point in [layout.start, layout.end] {
                    let radius = 4.5 * markerUnit
                    let grip = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    Ink.fill(context, grip.insetBy(dx: -1, dy: -1), appearance.foreground, radius: 2)
                    Ink.fill(context, grip, appearance.fill, radius: 2)
                }
            }
        }
        if case let .mark(start, current, tool) = gesture {
            let preview = Mark(number: model.review.nextNumber, tool: tool, start: ImagePoint(start), end: ImagePoint(current))
            draw(preview, selected: true)
        }
        context.restoreGState()
        if let marqueeRect {
            context.setFillColor(NSColor.black.withAlphaComponent(0.08).cgColor)
            context.fill(marqueeRect)
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(marqueeRect)
        }
    }

    private func position(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

    private func imagePoint(_ coordinate: CGPoint) -> CGPoint {
        let area = imageRect
        return CGPoint(x: max(0, min(area.width, coordinate.x - area.minX)) / scale,
                       y: max(0, min(area.height, coordinate.y - area.minY)) / scale)
    }

    private func findMark(at point: CGPoint, model: ReviewModel) -> Mark? {
        let ordered = model.review.marks.reversed()
        let overStroke = { [self] (mark: Mark) in
            MarkLayout(mark: mark, imageRect: imageRect, scale: scale, unit: markerUnit)
                .hitTest(point, number: mark.number)
        }
        if let mark = ordered.first(where: { model.review.selectedIDs.contains($0.id) && overStroke($0) }) { return mark }
        if let mark = ordered.first(where: overStroke) { return mark }
        guard model.tool == nil, imageRect.contains(point) else { return nil }
        return ordered.first {
            $0.tool == .region && MarkLayout(mark: $0, imageRect: imageRect, scale: scale, unit: markerUnit).region.contains(point)
        }
    }

    private func rectangle(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    private func markIDs(in rect: CGRect, model: ReviewModel) -> Set<UUID> {
        guard rect.width >= 3, rect.height >= 3 else { return [] }
        let area = rect.intersection(imageRect)
        guard !area.isEmpty else { return [] }
        return Set(model.review.marks.lazy.filter {
            MarkLayout(mark: $0, imageRect: self.imageRect, scale: self.scale, unit: self.markerUnit).intersects(area)
        }.map(\.id))
    }

    private func reveal(_ mark: Mark) {
        let layout = MarkLayout(mark: mark, imageRect: imageRect, scale: scale, unit: markerUnit)
        let badge = layout.badge(for: mark.number)
        guard !bounds.insetBy(dx: 24, dy: 24).contains(badge) else { return }
        pan.x += bounds.midX - badge.midX
        pan.y += bounds.midY - badge.midY
    }

    private func grip(at point: CGPoint, of mark: Mark) -> Endpoint? {
        guard mark.tool != .pin else { return nil }
        let layout = MarkLayout(mark: mark, imageRect: imageRect, scale: scale, unit: markerUnit)
        let startDistance = hypot(point.x - layout.start.x, point.y - layout.start.y)
        let endDistance = hypot(point.x - layout.end.x, point.y - layout.end.y)
        guard min(startDistance, endDistance) <= 8 * markerUnit else { return nil }
        return startDistance < endDistance ? .start : .end
    }

    override func mouseDown(with event: NSEvent) {
        guard let model else { return }
        window?.makeFirstResponder(self)
        let point = position(event)
        let extending = model.tool == nil && !event.modifierFlags.intersection([.shift, .command]).isEmpty
        if spaceHeld {
            beginPan(point)
        } else if !extending, let mark = model.selectedMark, let endpoint = grip(at: point, of: mark) {
            gesture = .adjust(original: mark, current: mark, endpoint: endpoint)
        } else if let mark = findMark(at: point, model: model) {
            if extending {
                model.select(model.review.selectedIDs.symmetricDifference([mark.id]))
                gesture = nil
            } else {
                if !model.review.selectedIDs.contains(mark.id) { model.select(mark.id) }
                let selected = model.review.marks.filter { model.review.selectedIDs.contains($0.id) }
                gesture = .move(start: point, original: selected, offset: .zero)
                NSCursor.closedHand.set()
            }
        } else if let tool = model.tool, imageRect.contains(point) {
            let start = imagePoint(point)
            gesture = .mark(start: start, current: start, tool: tool)
        } else if model.tool == nil {
            gesture = .marquee(start: point, current: point, retaining: extending ? model.review.selectedIDs : [])
        } else {
            model.select(nil)
            gesture = nil
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) { drag(to: position(event)) }

    override func mouseUp(with event: NSEvent) {
        guard let model else { return }
        let active = gesture
        gesture = nil
        switch active {
        case let .mark(start, _, tool):
            let end = imagePoint(position(event))
            if tool == .pin {
                model.add(tool, start: start, end: start)
            } else if tool == .region && abs(end.x - start.x) * scale >= 5 && abs(end.y - start.y) * scale >= 5 {
                model.add(tool, start: start, end: end)
            } else if tool == .arrow && hypot(end.x - start.x, end.y - start.y) * scale >= 8 {
                model.add(tool, start: start, end: end)
            } else {
                model.notify(tool.instruction)
            }
        case let .move(_, original, offset):
            model.updatePositions(original.map { $0.translated(by: offset) })
        case let .adjust(_, current, _):
            model.updatePositions([current])
        case let .marquee(start, _, retaining):
            model.select(retaining.union(markIDs(in: rectangle(from: start, to: position(event)), model: model)))
        case .pan, nil:
            break
        }
        refreshCursor(at: position(event))
        needsDisplay = true
    }

    override func otherMouseDown(with event: NSEvent) { beginPan(position(event)) }
    override func otherMouseDragged(with event: NSEvent) { drag(to: position(event)) }
    override func otherMouseUp(with event: NSEvent) { mouseUp(with: event) }

    override func rightMouseDown(with event: NSEvent) { beginPan(position(event)) }
    override func rightMouseDragged(with event: NSEvent) { drag(to: position(event)) }
    override func rightMouseUp(with event: NSEvent) { mouseUp(with: event) }

    private func beginPan(_ origin: CGPoint) {
        gesture = .pan(origin: origin, previous: pan)
        NSCursor.closedHand.set()
    }

    private func drag(to point: CGPoint) {
        switch gesture {
        case let .pan(origin, previous):
            pan = CGPoint(x: previous.x + point.x - origin.x, y: previous.y + point.y - origin.y)
            constrainPan()
        case let .mark(start, _, tool):
            gesture = .mark(start: start, current: tool == .pin ? start : imagePoint(point), tool: tool)
        case let .move(start, original, _):
            guard let size = model?.review.source?.size else { return }
            let distance = CGSize(width: (point.x - start.x) / scale, height: (point.y - start.y) / scale)
            let offset = hypot(distance.width, distance.height) * scale < 3
                ? .zero : Mark.constrainedOffset(distance, for: original, within: size)
            gesture = .move(start: start, original: original, offset: offset)
        case let .marquee(start, _, retaining):
            gesture = .marquee(start: start, current: point, retaining: retaining)
        case let .adjust(original, current, endpoint):
            var next = original
            let destination = ImagePoint(imagePoint(point))
            switch endpoint {
            case .start: next.start = destination
            case .end: next.end = destination
            }
            let width = next.bounds.width * scale
            let height = next.bounds.height * scale
            let valid = next.tool == .region ? width >= 5 && height >= 5 : hypot(width, height) >= 8
            gesture = .adjust(original: original, current: valid ? next : current, endpoint: endpoint)
        case nil:
            break
        }
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            zoom(at: position(event), by: exp(Double(event.scrollingDeltaY) * 0.028))
        } else {
            pan.x += event.scrollingDeltaX
            pan.y -= event.scrollingDeltaY
            constrainPan()
            needsDisplay = true
        }
    }

    override func magnify(with event: NSEvent) {
        zoom(at: position(event), by: exp(event.magnification))
    }

    private func zoom(at point: CGPoint, by factor: CGFloat) {
        guard let model, let source = model.review.source else { return }
        let relative = imagePoint(point)
        let next = min(8, max(0.05, scale * factor))
        let newWidth = source.size.width * next
        let newHeight = source.size.height * next
        zoomRequest = next
        pan = CGPoint(x: point.x - relative.x * next - (bounds.width - newWidth) / 2,
                      y: point.y - relative.y * next - (bounds.height - newHeight) / 2)
        constrainPan()
        model.zoom = next
        relayZoom()
        needsDisplay = true
    }

    override func cursorUpdate(with event: NSEvent) { refreshCursor(at: position(event)) }
    override func mouseMoved(with event: NSEvent) { refreshCursor(at: position(event)) }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    private func refreshCursor(at position: CGPoint) {
        if spaceHeld {
            NSCursor.openHand.set()
        } else if let selected = model?.selectedMark, grip(at: position, of: selected) != nil {
            NSCursor.crosshair.set()
        } else if let model, findMark(at: position, model: model) != nil {
            NSCursor.openHand.set()
        } else if model?.tool != nil, imageRect.contains(position) {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func handleKeyboard(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyUp, event.keyCode == 49, spaceHeld {
            spaceHeld = false
            if let window { refreshCursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)) }
            return nil
        }
        guard event.type == .keyDown, let window, window.isKeyWindow, let model, model.review.source != nil else { return event }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let responder = window.firstResponder
        let editing = responder is NSTextView || responder is NSTextField || responder is NSTextInputClient
        let key = event.charactersIgnoringModifiers?.lowercased()

        if event.keyCode == 53, editing {
            if let text = responder as? NSTextInputClient, text.hasMarkedText() {
                return event
            }
            window.makeFirstResponder(self)
            return nil
        }
        guard !editing else { return event }
        if key == "a", flags == .control || flags == .command {
            gesture = nil
            model.selectAllMarks()
            window.makeFirstResponder(self)
            refreshCursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
            return nil
        }
        guard flags.isEmpty else { return event }

        switch event.keyCode {
        case 49:
            spaceHeld = true
            if bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)) { NSCursor.openHand.set() }
            return nil
        case 51, 117:
            if !model.review.selectedIDs.isEmpty { model.removeSelected(); return nil }
        case 53:
            if gesture != nil { gesture = nil; needsDisplay = true }
            else { model.select(nil) }
            return nil
        default:
            break
        }
        if key == "v" {
            model.tool = nil
            refreshCursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
            return nil
        }
        if let tool = MarkTool.allCases.first(where: { $0.shortcut == key }) {
            model.tool = tool
            refreshCursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
            return nil
        }
        if key == "0" {
            model.fit()
            return nil
        }
        return event
    }
}
