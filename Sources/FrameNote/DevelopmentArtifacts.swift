import AppKit

enum DevelopmentArtifacts {
    struct VerificationError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    static func icon(at directory: URL, source: URL?) throws {
        let icon: NSImage?
        if let source {
            guard let image = NSImage(contentsOf: source), image.size.width == image.size.height else {
                throw VerificationError("Expected a square icon at \(source.path)")
            }
            icon = image
        } else {
            icon = nil
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for density in 1...2 {
                let px = base * density
                guard let context = Ink.bitmap(width: px, height: px) else { throw ImageExport.Failure.encoding }
                Ink.onBitmap(context, height: CGFloat(px)) {
                    if let icon {
                        icon.draw(in: CGRect(x: 0, y: 0, width: px, height: px), from: .zero,
                                  operation: .copy, fraction: 1, respectFlipped: true,
                                  hints: [.interpolation: NSImageInterpolation.high])
                    } else {
                        context.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
                        drawAppIcon(in: context)
                    }
                }
                guard let image = context.makeImage() else { throw ImageExport.Failure.encoding }
                let suffix = density == 2 ? "@2x" : ""
                try ImageExport.pngData(image).write(to: directory.appending(path: "icon_\(base)x\(base)\(suffix).png"))
            }
        }
    }

    private static func drawAppIcon(in context: CGContext) {
        let ink = Ink.color(0x17191E)
        Ink.fill(context, CGRect(x: 91, y: 91, width: 842, height: 842), ink, radius: 193)

        context.saveGState()
        context.translateBy(x: 512, y: 512)
        context.rotate(by: .pi * 32 / 180)
        context.translateBy(x: -512, y: -512)

        Ink.fill(context, CGRect(x: 359, y: 272, width: 306, height: 334), .white, radius: 75)
        let shoulder = CGMutablePath()
        shoulder.move(to: CGPoint(x: 363, y: 558))
        shoulder.addLine(to: CGPoint(x: 661, y: 558))
        shoulder.addLine(to: CGPoint(x: 661, y: 640))
        shoulder.addLine(to: CGPoint(x: 549, y: 763))
        shoulder.addQuadCurve(to: CGPoint(x: 490, y: 753), control: CGPoint(x: 511, y: 780))
        shoulder.addLine(to: CGPoint(x: 363, y: 640))
        shoulder.closeSubpath()
        context.setFillColor(NSColor.white.cgColor)
        context.addPath(shoulder)
        context.fillPath()

        // Color the full end of the pen, using the same silhouette as the body.
        context.saveGState()
        context.addPath(shoulder)
        context.clip()
        context.setFillColor(Ink.color(Ink.logoBlue).cgColor)
        context.fill(CGRect(x: 363, y: 708, width: 298, height: 80))
        context.restoreGState()

        Ink.fill(context, CGRect(x: 430, y: 401, width: 50, height: 63), ink, radius: 25)
        Ink.fill(context, CGRect(x: 544, y: 401, width: 50, height: 63), ink, radius: 25)
        context.setStrokeColor(ink.cgColor)
        context.setLineWidth(24)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 474, y: 509))
        context.addQuadCurve(to: CGPoint(x: 550, y: 509), control: CGPoint(x: 512, y: 545))
        context.strokePath()
        context.restoreGState()
    }

    static func verify(at directory: URL) throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw VerificationError(message) }
        }

        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let (source, marks) = Demo.make() else { throw VerificationError("Demo creation failed") }
        let preferenceDomain = "ShotCue.SelfTest.\(UUID().uuidString)"
        guard let preferences = UserDefaults(suiteName: preferenceDomain) else {
            throw VerificationError("Could not open test preferences")
        }
        defer { preferences.removePersistentDomain(forName: preferenceDomain) }
        let store = ReviewStore(directory: directory.appending(path: "draft"))
        let model = ReviewModel(store: store, preferences: preferences)
        try check(model.annotationAppearance.hex == Ink.logoBlue, "Default annotation blue differs from the icon")
        model.annotationAppearance = AnnotationAppearance(0xF16668)
        try check(ReviewModel(store: store, preferences: preferences).annotationAppearance == model.annotationAppearance,
                  "Annotation color was not restored")
        model.accept(source, marks: marks)
        model.add(.pin, start: CGPoint(x: 52, y: 91), end: CGPoint(x: 52, y: 91))
        guard let new = model.selectedMark else { throw VerificationError("New mark was not selected") }
        model.edit(new.id, field: .problem, text: "中文、English、emoji 👋 都要可读。")
        let longNote = String(repeating: "这个段落用于检查导出说明能否自动换行。 ", count: 30)
        model.edit(new.id, field: .desired, text: "第一行\n第二行\n\n\(longNote)")
        model.undo()
        try check(model.selectedMark?.desired == "", "Undo did not restore the previous text")
        model.redo()
        try check(model.selectedMark?.desired.contains(longNote) == true, "Redo lost text")
        model.removeSelected()
        try check(model.review.marks.count == 2, "Delete count mismatch")
        model.undo()
        try check(model.review.marks.count == 3, "Undo did not restore the deleted mark")
        try check(model.review.markdown.contains("## 3. 点 (52, 91)"), "Markdown coordinates are missing")
        try check(model.review.markdown.contains(longNote.trimmingCharacters(in: .whitespaces)), "Markdown lost a long note")

        let data = try ImageExport.png(model.review)
        guard let decoded = ReviewImage.read(data, name: "marked.png") else {
            throw VerificationError("PNG could not be decoded")
        }
        try check(decoded.image.width == 1120 && decoded.image.height > 1100, "PNG note layout has invalid dimensions")
        try data.write(to: directory.appending(path: "示例-标注.png"))
        try Data(model.review.markdown.utf8).write(to: directory.appending(path: "示例-反馈.md"))
        try ImageExport.pngData(source.image).write(to: directory.appending(path: "示例-原图.png"))

        var blankNotes = model.review
        for index in blankNotes.marks.indices {
            blankNotes.marks[index].problem = " \n\t "
            blankNotes.marks[index].desired = ""
        }
        let marksOnly = try ImageExport.render(blankNotes, appearance: model.annotationAppearance)
        try check(marksOnly.width == source.image.width && marksOnly.height == source.image.height,
                  "Whitespace-only feedback added space to the export")
        try ImageExport.pngData(marksOnly).write(to: directory.appending(path: "示例-仅标注.png"))
        blankNotes.marks[0].desired = "保留这条建议"
        let withFeedback = try ImageExport.render(blankNotes, appearance: model.annotationAppearance)
        try check(withFeedback.height > source.image.height, "A nonempty desired change did not add the feedback section")

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        try check(pasteboard.writeObjects([item]), "Could not write PNG to a pasteboard")
        try check(ReviewImage.paste(from: pasteboard)?.size == decoded.size, "PNG pasteboard import changed the size")

        model.flush()
        let restored = ReviewStore(directory: directory.appending(path: "draft")).load()
        try check(restored.source?.size == source.size && restored.marks == model.review.marks, "Draft round trip failed")
        let tinyContext = Ink.bitmap(width: 64, height: 32)
        guard let tiny = tinyContext?.makeImage() else { throw VerificationError("Tiny bitmap was unavailable") }
        var tinyReview = Review(source: ReviewImage(name: "tiny.png", image: tiny), marks: marks.enumerated().map { index, mark in
            Mark(number: index + 1, tool: mark.tool, start: ImagePoint(CGPoint(x: 10, y: 10)), end: ImagePoint(CGPoint(x: 38, y: 20)))
        })
        let tinyMarksOnly = try ImageExport.render(tinyReview)
        try check(tinyMarksOnly.width == 64 && tinyMarksOnly.height == 32, "A marks-only image changed size")
        tinyReview.marks[0].problem = "示例"
        let tinyWithFeedback = try ImageExport.render(tinyReview)
        try check(tinyWithFeedback.width == 860 && tinyWithFeedback.height > 32, "Small screenshots lost their reading space")
        let beforeMove = model.review.marks
        model.selectAllMarks()
        try check(model.tool == nil && model.review.selectedIDs == Set(beforeMove.map(\.id)), "Select all missed an annotation")
        let offset = Mark.constrainedOffset(CGSize(width: 500, height: -500), for: beforeMove, within: source.size)
        model.updatePositions(beforeMove.map { $0.translated(by: offset) })
        try check(zip(beforeMove, model.review.marks).allSatisfy { original, current in
            current.start == original.start.translated(by: offset)
        }, "Selected annotations did not move together")
        model.undo()
        try check(model.review.marks == beforeMove && model.review.selectedIDs.count == beforeMove.count,
                  "Undo did not restore the group move")
        model.flush()
        try check(store.load().selectedIDs == model.review.selectedIDs, "Multiple selection was not restored")
        model.removeSelected()
        try check(model.review.marks.isEmpty, "Deleting a selection left selected annotations behind")
        model.undo()
        try check(model.review.marks == beforeMove, "Undo did not restore a deleted group")
        print("Verified annotation color persistence, PNG export with and without feedback, Chinese Markdown, undo/redo, clipboard and draft restore.")
    }
}
