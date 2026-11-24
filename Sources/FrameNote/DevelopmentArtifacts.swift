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
        try check(model.chosenLanguage == nil, "A fresh installation should prompt for a language")
        model.chooseLanguage(.chinese)
        try check(ReviewModel(store: store, preferences: preferences).chosenLanguage == .chinese,
                  "The first-run Chinese selection was not restored")
        model.chooseLanguage(.english)
        try check(ReviewModel(store: store, preferences: preferences).chosenLanguage == .english,
                  "The switch to English was not restored")
        guard let (englishSource, englishMarks) = Demo.make(in: .english) else {
            throw VerificationError("Could not create the English sample")
        }
        model.accept(englishSource, marks: englishMarks)
        let englishMarkdown = model.review.markdown(in: model.language)
        try check(englishSource.name == "Workspace review sample.png" &&
                  englishMarkdown.contains("# Screenshot review") &&
                  englishMarkdown.contains("## 1. Box top-left") &&
                  englishMarkdown.contains("**Requested change**") &&
                  englishMarkdown.range(of: "\\p{Han}", options: .regularExpression) == nil,
                  "English sample and exported feedback were not fully localized")
        let englishPNG = try ImageExport.png(model.review, language: model.language)
        try englishPNG.write(to: directory.appending(path: "english-feedback.png"))
        model.chooseLanguage(.chinese)
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
        try check(model.review.markdown().contains("## 3. 点 (52, 91)"), "Markdown coordinates are missing")
        try check(model.review.markdown().contains(longNote.trimmingCharacters(in: .whitespaces)), "Markdown lost a long note")

        let data = try ImageExport.png(model.review)
        guard let decoded = ReviewImage.read(data, name: "marked.png") else {
            throw VerificationError("PNG could not be decoded")
        }
        try check(decoded.image.width == 1120 && decoded.image.height > 1100, "PNG note layout has invalid dimensions")
        try data.write(to: directory.appending(path: "示例-标注.png"))
        try Data(model.review.markdown().utf8).write(to: directory.appending(path: "示例-反馈.md"))
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

        guard let bitmap = Ink.bitmap(width: 100, height: 80) else { throw VerificationError("Color test bitmap unavailable") }
        let blue = AnnotationAppearance(0x3264C8)
        let nearbyBlue = AnnotationAppearance(0x3B6ACD)
        let distinctBlue = AnnotationAppearance(0x4678DC)
        let green = AnnotationAppearance(0x12AA34)
        let foreground = AnnotationAppearance(0x0A1428)
        let mixedEdge = AnnotationAppearance(0x1E3C78)
        let brushBase = Ink.color(0x404040)
        Ink.onBitmap(bitmap, height: 80) {
            Ink.fill(bitmap, CGRect(x: 5, y: 5, width: 12, height: 9), blue.fill)
            Ink.fill(bitmap, CGRect(x: 17, y: 5, width: 6, height: 9), nearbyBlue.fill)
            Ink.fill(bitmap, CGRect(x: 23, y: 5, width: 6, height: 9), distinctBlue.fill)
            Ink.fill(bitmap, CGRect(x: 6, y: 14, width: 6, height: 1), mixedEdge.fill)
            Ink.fill(bitmap, CGRect(x: 6, y: 15, width: 6, height: 3), foreground.fill)
            Ink.fill(bitmap, CGRect(x: 5, y: 60, width: 18, height: 10), blue.fill)
            Ink.fill(bitmap, CGRect(x: 70, y: 12, width: 17, height: 13), brushBase)
        }
        guard let colorImage = bitmap.makeImage(), let preview = Ink.bitmap(width: 100, height: 80),
              let sample = ColorSample.make(in: colorImage, at: ImagePoint(CGPoint(x: 8, y: 8))) else {
            throw VerificationError("Could not sample the upper blue region")
        }
        try check(sample.original == blue, "Color sampling used the wrong channels or image origin")
        Ink.onBitmap(preview, height: 80) {
            sample.drawPreview(of: colorImage, target: green, in: CGRect(x: 0, y: 0, width: 100, height: 80), context: preview)
        }
        guard let changed = preview.makeImage() else { throw VerificationError("Could not render the color preview") }
        func color(at x: CGFloat, _ y: CGFloat) -> AnnotationAppearance? {
            ColorSample.make(in: changed, at: ImagePoint(CGPoint(x: x, y: y)))?.original
        }
        try check(color(at: 8, 8) == green && color(at: 20, 8) == green, "Preview missed the sampled or adjacent similar color")
        try check(color(at: 26, 8) == distinctBlue, "Preview leaked into an adjacent, visibly different color")
        try check(color(at: 8, 65) == blue && color(at: 30, 8) == nil, "Preview changed a disconnected region or transparency")
        let edgeColor = color(at: 8, 14)?.hex
        try check((edgeColor == 0x0E5E2E || edgeColor == 0x0E5F2E) && color(at: 8, 15) == foreground,
                  "Preview did not replace the background contribution of an antialiased edge")

        model.accept(ReviewImage(name: "color-test.png", image: colorImage))
        model.zoom = 1
        let canvas = MarkCanvas(frame: CGRect(x: 0, y: 0, width: 200, height: 160))
        func draw(_ tool: MarkTool, points: [CGPoint]) throws {
            model.chooseTool(tool)
            canvas.update(from: model)
            for (index, point) in points.enumerated() {
                let location = canvas.convert(CGPoint(x: point.x + 50, y: point.y + 40), to: nil)
                let type: NSEvent.EventType = index == 0 ? .leftMouseDown : index == points.count - 1 ? .leftMouseUp : .leftMouseDragged
                guard let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: 0,
                                                     windowNumber: 0, context: nil, eventNumber: index, clickCount: 1, pressure: 1) else {
                    throw VerificationError("Could not create a test mouse event")
                }
                switch type {
                case .leftMouseDown: canvas.mouseDown(with: event)
                case .leftMouseUp: canvas.mouseUp(with: event)
                default: canvas.mouseDragged(with: event)
                }
            }
        }
        let lassoPoints = [CGPoint(x: 30, y: 30), CGPoint(x: 68, y: 33), CGPoint(x: 54, y: 60),
                           CGPoint(x: 35, y: 48), CGPoint(x: 31, y: 32)]
        let brushPoints = [CGPoint(x: 60, y: 20), CGPoint(x: 72, y: 22), CGPoint(x: 85, y: 20)]
        try draw(.lasso, points: lassoPoints)
        try draw(.brush, points: brushPoints)
        guard model.review.marks.count == 2, let lasso = model.review.marks.first, let brush = model.selectedMark else {
            throw VerificationError("Could not create the freehand annotations")
        }
        try check(lasso.stroke == lassoPoints.map(ImagePoint.init) && brush.stroke == brushPoints.map(ImagePoint.init),
                  "The canvas did not record the freehand points in image coordinates")
        let imageRect = CGRect(x: 0, y: 0, width: colorImage.width, height: colorImage.height)
        let lassoLayout = MarkLayout(mark: lasso, imageRect: imageRect, scale: 1, unit: 0.5)
        try check(lasso.closesStroke == true && lassoLayout.containsArea(CGPoint(x: 49, y: 43)) &&
                  !lassoLayout.containsArea(CGPoint(x: 65, y: 52)),
                  "Lasso selection used its bounding box instead of its path")
        try check(lasso.bounds.maxX == 68 && lasso.bounds.maxY == 60, "Lasso bounds missed its intermediate points")
        let movedBrush = brush.translated(by: CGSize(width: 2, height: 8))
        model.updatePositions([movedBrush])
        try check(model.selectedMark?.stroke == movedBrush.stroke, "Moving the brush lost its path")
        model.undo()
        let freehand = try ImageExport.render(model.review, appearance: model.annotationAppearance)
        guard let brushPixel = ColorSample.make(in: freehand, at: ImagePoint(CGPoint(x: 72, y: 22)))?.original.fill else {
            throw VerificationError("The exported brush pixel was missing")
        }
        let mixedBrush = Ink.color(0x804E4E)
        let redDifference = abs(brushPixel.redComponent - mixedBrush.redComponent)
        let greenDifference = abs(brushPixel.greenComponent - mixedBrush.greenComponent)
        let blueDifference = abs(brushPixel.blueComponent - mixedBrush.blueComponent)
        try check(redDifference + greenDifference + blueDifference <= 4.0 / 255,
                  "The exported brush path did not blend with the image beneath it")
        try check(ColorSample.make(in: freehand, at: ImagePoint(CGPoint(x: 49, y: 43))) != nil,
                  "PNG omitted the lasso fill")

        model.beginColorReplacement()
        model.sampleColor(at: CGPoint(x: 8.7, y: 8.6))
        let sampleTimeout = Date().addingTimeInterval(5)
        while model.colorReplacement?.sample == nil && Date() < sampleTimeout {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        try check(model.colorReplacement?.sample?.original == blue, "Color sample was not delivered to the workspace")
        model.setReplacementHex("#1Z")
        model.useColorReplacement()
        try check(model.review.marks.count == 2, "An invalid target color created feedback")
        model.setReplacementHex("12aa34")
        model.useColorReplacement()
        let feedback = "将该处的颜色替换成“#12AA34”"
        try check(model.colorReplacement == nil && model.selectedMark?.desired == feedback &&
                  model.selectedMark?.start.point == CGPoint(x: 8, y: 8) && model.review.markdown().contains(feedback),
                  "Confirmed color replacement did not create feedback at the sampled pixel")
        try check(model.review.source.flatMap { ColorSample.make(in: $0.image, at: ImagePoint(CGPoint(x: 8, y: 8))) }?.original == blue,
                  "Confirming feedback changed the original pixels")
        model.undo()
        try check(model.review.marks.count == 2, "Undo did not remove the replacement feedback")
        model.redo()
        let shortLine = [CGPoint(x: 8, y: 34), CGPoint(x: 10, y: 34)]
        try draw(.lasso, points: shortLine)
        try check(model.selectedMark?.stroke == shortLine.map(ImagePoint.init) && model.selectedMark?.closesStroke == false,
                  "Lasso rejected a short, straight stroke")
        try check(model.review.markdown().contains("圈选范围左上 (8, 34) · 2 × 1 px"), "A straight lasso lost its location in Markdown")
        let openPoints = [CGPoint(x: 8, y: 34), CGPoint(x: 8, y: 58), CGPoint(x: 32, y: 58)]
        try draw(.lasso, points: openPoints)
        guard let openMark = model.selectedMark else { throw VerificationError("The open lasso was not recorded") }
        let openLayout = MarkLayout(mark: openMark, imageRect: imageRect, scale: 1, unit: 0.5)
        try check(openMark.stroke == openPoints.map(ImagePoint.init) && !openMark.isClosedLasso &&
                  !openLayout.hitTest(CGPoint(x: 20, y: 46), number: openMark.number),
                  "The open lasso added a segment between its start and end")
        var legacyLasso = lasso
        legacyLasso.closesStroke = nil
        let legacyRecord = try JSONEncoder().encode(legacyLasso)
        let legacyRestored = try JSONDecoder().decode(Mark.self, from: legacyRecord)
        try check(legacyRestored.isClosedLasso, "A lasso from an older draft lost its closed outline")
        model.flush()
        try check(store.load().marks == model.review.marks, "Draft round trip lost freehand paths or replacement feedback")
        print("Verified freehand annotations, local recoloring and feedback, PNG and Markdown export, undo/redo, clipboard and draft restore.")
    }
}
