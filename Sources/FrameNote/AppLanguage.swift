enum AppLanguage: String, CaseIterable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    var name: String {
        switch self {
        case .chinese: "简体中文"
        case .english: "English"
        }
    }

    func text(_ chinese: @autoclosure () -> String, _ english: @autoclosure () -> String) -> String {
        self == .chinese ? chinese() : english()
    }

    func annotationCount(_ count: Int) -> String {
        text("\(count) 条标注", count == 1 ? "1 annotation" : "\(count) annotations")
    }
}
