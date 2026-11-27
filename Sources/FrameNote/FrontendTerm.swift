import Foundation

enum TermCategory: CaseIterable {
    case structure, controls, navigation, feedback, interaction, styling, responsive, media
    case style, color, typography, motion, principles, access, system, writing

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .structure: language.text("页面结构", "Page structure")
        case .interaction: language.text("交互状态", "Interaction states")
        case .responsive: language.text("响应式布局", "Responsive layout")
        case .media: language.text("图片与图标", "Images & icons")
        case .access: language.text("可访问性", "Accessibility")
        case .system: language.text("设计系统", "Design systems")
        case .writing: language.text("界面文案", "Interface writing")
        case .controls: language.text("表单控件", "Form controls")
        case .navigation: language.text("导航", "Navigation")
        case .feedback: language.text("容器与反馈", "Containers & feedback")
        case .styling: language.text("布局与样式", "Layout & style")
        case .style: language.text("风格", "Visual styles")
        case .color: language.text("配色", "Color palettes")
        case .typography: language.text("字体", "Typography")
        case .motion: language.text("动效", "Motion")
        case .principles: language.text("设计理念", "Design principles")
        }
    }
}

enum MotionConcept: Hashable { case duration, easing, fade, slide }

enum DesignConcept: Hashable {
    case minimalism, editorial, glass, flat
    case accentColor, monochromatic, complementary, semantic
    case serif, sansSerif, monospace, weight
    case motion(MotionConcept)
    case hierarchy, proximity, disclosure, recognition
}

struct FrontendTerm: Identifiable {
    enum Kind {
        case button, input, dropdown, checkbox, radio, toggle, tabs, breadcrumb, pagination
        case card, badge, dialog, toast, padding, margin, gap, radius, lineHeight
        case design(DesignConcept)
        case illustrated(ReferenceIllustration)
    }

    var id: String { english }
    let kind: Kind
    let category: TermCategory
    let chinese: String
    let english: String
    private let aliases: String
    private let definitionZH: String
    private let definitionEN: String
    private let exampleZH: String
    private let exampleEN: String

    init(_ kind: Kind, _ category: TermCategory, _ chinese: String, _ english: String,
                 _ definitionZH: String, _ definitionEN: String, _ exampleZH: String, _ exampleEN: String,
                 aliases: String = "") {
        self.kind = kind
        self.category = category
        self.chinese = chinese
        self.english = english
        self.aliases = aliases
        self.definitionZH = definitionZH
        self.definitionEN = definitionEN
        self.exampleZH = exampleZH
        self.exampleEN = exampleEN
    }

    func definition(_ language: AppLanguage) -> String { language.text(definitionZH, definitionEN) }
    func example(_ language: AppLanguage) -> String { language.text(exampleZH, exampleEN) }

    func searchRank(for words: [String]) -> Int? {
        guard !words.isEmpty else { return 0 }
        let names = [chinese, english, aliases].joined(separator: " ")
        let content = [names, category.title(.chinese), category.title(.english),
                       definitionZH, definitionEN, exampleZH, exampleEN].joined(separator: " ")
        guard words.allSatisfy({ content.localizedCaseInsensitiveContains($0) }) else { return nil }
        if [chinese, english].contains(where: { $0.localizedCaseInsensitiveCompare(words.joined(separator: " ")) == .orderedSame }) { return 0 }
        return words.allSatisfy { names.localizedCaseInsensitiveContains($0) } ? 1 : 2
    }

    static let all = original + extended
    private static let original: [Self] = [
        .init(.button, .controls, "按钮", "Button",
              "点击后执行操作。实心主按钮强调首选操作，描边按钮用于次要操作。",
              "Triggers an action. A filled button emphasizes the primary action, while an outline gives a secondary action less weight.",
              "把「保存」设为实心主按钮，「取消」改为描边按钮。",
              "Give Save a solid fill and use an outline for Cancel."),
        .init(.input, .controls, "输入框", "Text field",
              "用于输入文字。标签说明要填什么，占位文字在输入后消失。",
              "Accepts typed text. Its label identifies the field, while the placeholder disappears as you type.",
              "把「邮箱」移到输入框上方作为标签，框内用示例邮箱作占位文字。",
              "Place Email above the field as its label and use a sample address as the placeholder.", aliases: "input textbox 文本框"),
        .init(.dropdown, .controls, "下拉选择框", "Select / Dropdown",
              "收起时显示当前值，展开后从列表里选择选项。",
              "Shows the selected value when closed and offers a list of options when opened.",
              "将排序方式放入下拉选择框，默认显示「最近更新」。",
              "Put the sort options in a dropdown and select Recently updated by default."),
        .init(.checkbox, .controls, "复选框", "Checkbox",
              "方框内的勾表示已选中，同组的多个选项可以同时选中。",
              "A check mark indicates selection. Several options in the same group can be checked together.",
              "将筛选项改为复选框，允许同时选择图片和视频。",
              "Use checkboxes so users can filter for both images and videos."),
        .init(.radio, .controls, "单选按钮", "Radio button",
              "圆点标记当前选择，同组内一次只能选一项。",
              "A filled dot marks the selection. Only one option in a group can be selected at a time.",
              "把月付和年付放入同一组单选按钮，默认选中月付。",
              "Group Monthly and Yearly as radio buttons and select Monthly by default."),
        .init(.toggle, .controls, "开关", "Switch / Toggle",
              "用滑块位置表示开或关，常用于立即生效的设置。",
              "The thumb position shows whether a setting is on or off. Changes typically take effect immediately.",
              "在「邮件通知」右侧加一个开关，切换后立即生效。",
              "Add a switch beside Email notifications and apply changes immediately."),
        .init(.tabs, .navigation, "标签页", "Tabs",
              "在同一区域切换并列内容，下划线或底色标记当前页。",
              "Switch between related views in place. An underline or fill identifies the active tab.",
              "给当前标签页加一条 2 px 的底部指示线。",
              "Add a 2 px underline to the active tab."),
        .init(.breadcrumb, .navigation, "面包屑导航", "Breadcrumb",
              "从上级到当前页依次列出路径，让用户可以返回上级。",
              "Shows the path from the parent pages to the current page, with links back up the hierarchy.",
              "在标题上方显示面包屑，让用户可以返回项目列表。",
              "Place a breadcrumb above the title with a link back to Projects."),
        .init(.pagination, .navigation, "分页器", "Pagination",
              "将长列表分成多页，用页码和前后翻页按钮导航。",
              "Divides a long list into pages with page numbers and previous or next controls.",
              "为当前页码添加实心底色，并在第一页禁用上一页按钮。",
              "Fill the current page number and disable Previous on the first page."),
        .init(.card, .feedback, "卡片", "Card",
              "用边框或背景将同一对象的标题、摘要和操作聚在一起。",
              "Groups an item's title, summary and actions within a shared border or background.",
              "把项目名称和更新时间放进同一张卡片，并让两行文字左对齐。",
              "Group the project name and update time in one card and align their left edges."),
        .init(.badge, .feedback, "徽标", "Badge",
              "用一小块颜色和简短文字显示状态或数量，常放在名称旁边。",
              "A compact label beside an item shows a status or count using a short caption and color.",
              "在项目名右侧加「已发布」徽标，使用浅绿底和深绿字。",
              "Add a Published badge beside the project name with dark green text on pale green."),
        .init(.dialog, .feedback, "模态对话框", "Modal dialog",
              "浮在遮罩上，用户需要先处理或关闭它才能继续操作背景页面。",
              "Appears over a backdrop and requires a response or dismissal before the page behind it can be used.",
              "删除项目前显示确认对话框，写明项目名并提供取消按钮。",
              "Before deleting a project, show a confirmation dialog with its name and a Cancel button.", aliases: "modal 弹窗 弹框"),
        .init(.toast, .feedback, "轻提示", "Toast",
              "操作后短暂出现的状态消息，自动消失，用户可以继续使用页面。",
              "A brief status message that disappears automatically while the page remains usable.",
              "保存成功后在页面底部显示「已保存」轻提示，3 秒后消失。",
              "Show a Saved toast at the bottom of the page for 3 seconds.", aliases: "消息提示 提示条"),
        .init(.padding, .styling, "内边距", "Padding",
              "内容到自身边框之间的留白。按钮的左右内边距决定文字离边缘多远。",
              "Space between content and its own border. Horizontal padding sets how far a button label sits from its edges.",
              "把按钮左右内边距从 8 px 增至 16 px，上下内边距保持原值。",
              "Increase the button's horizontal padding from 8 px to 16 px and keep its vertical padding."),
        .init(.margin, .styling, "外边距", "Margin",
              "元素边框外侧的留白，用于拉开它与周围元素的距离。",
              "Space outside an element's border that separates it from its surroundings.",
              "给卡片增加 16 px 的上外边距，拉开它与标题的距离。",
              "Add a 16 px top margin to the card to separate it from the heading."),
        .init(.gap, .styling, "元素间距", "Gap",
              "在网格或弹性布局中控制相邻项之间的距离，常用于卡片列表或按钮组。",
              "The space between neighboring items in a grid or flex layout, such as cards or grouped buttons.",
              "将按钮组内的间距统一为 12 px。",
              "Set a consistent 12 px gap between buttons in the group."),
        .init(.radius, .styling, "圆角半径", "Border radius",
              "决定边角的弯曲程度。半径越大，拐角越圆。",
              "Controls the curvature of a corner. A larger radius produces a rounder corner.",
              "把卡片圆角半径从 4 px 改为 12 px。",
              "Increase the card's border radius from 4 px to 12 px."),
        .init(.lineHeight, .styling, "行高", "Line height",
              "每一行文字占用的高度。字号相同时，增大行高会让相邻行更疏朗。",
              "The height allocated to each line of text. At a fixed font size, a taller line height spaces lines farther apart.",
              "正文保留 16 px 字号，将行高设为 24 px。",
              "Keep body text at 16 px and set its line height to 24 px."),

        .init(.design(.minimalism), .style, "极简风格", "Minimalism",
              "用留白、少量颜色和清楚的对齐组织内容，画面里最醒目的元素通常也是最重要的操作。",
              "Whitespace, a small palette and deliberate alignment draw attention to the essential action.",
              "移除下载卡片的渐变和投影，保留标题、文件大小和一个下载按钮。",
              "Remove the gradient and shadow from the download card. Keep the title, file size and one download button."),
        .init(.design(.editorial), .style, "编辑式设计", "Editorial design",
              "借用杂志排版，用醒目的大标题、细小的栏目名和分隔线引导阅读顺序。",
              "Magazine-like layouts use expressive headlines, small section labels and rules to guide reading order.",
              "把专题名移到标题上方，用小号字显示；文章标题换成大号衬线体，并在下方加一条细线。",
              "Place a small section label above the article title, set the title in a large serif face and add a thin rule below."),
        .init(.design(.glass), .style, "毛玻璃风格", "Glassmorphism",
              "半透明表面透出模糊的背景色，细亮边标出浮层的轮廓。背景越复杂，文字越需要稳定的底色。",
              "A translucent surface lets blurred background colors show through. A fine highlight defines its edge, and a tint keeps text readable.",
              "给浮动工具栏加半透明浅底和背景模糊，滚到深色图片上时也要能读清按钮文字。",
              "Give the floating toolbar a lightly tinted, blurred backdrop so its labels stay legible over dark images.", aliases: "玻璃拟态 frosted glass backdrop filter"),
        .init(.design(.flat), .style, "扁平化设计", "Flat design",
              "用纯色块、简洁图形和清晰边界区分功能，适合需要快速扫读的工具界面。",
              "Solid shapes, simple icons and clear edges distinguish functions in interfaces meant for quick scanning.",
              "工具栏的三个入口统一为纯色图标和短标签，去掉立体高光。",
              "Use solid-color icons and short labels for all three toolbar actions. Remove the beveled highlights."),

        .init(.design(.accentColor), .color, "强调色", "Accent color",
              "用一种醒目的颜色突出关键操作或当前选项。周围的中性色让这个重点更容易被找到。",
              "One distinctive color highlights a key action or selection. Neutral surrounding elements help it stand out.",
              "只给「发布」按钮使用靛蓝色填充，「预览」和「取消」使用中性色。",
              "Fill Publish with indigo and use neutral colors for Preview and Cancel.", aliases: "主色 品牌色"),
        .init(.design(.monochromatic), .color, "单色配色", "Monochromatic palette",
              "保留同一色相，通过深浅和饱和度区分背景、边框和文字，适合需要统一感的区域。",
              "Variations in lightness and saturation within one hue give fills, borders and text a shared character.",
              "把信息卡统一成蓝色系，用浅蓝铺底、中蓝描边、深蓝显示标题。",
              "Use pale blue for the card surface, medium blue for its border and deep blue for its heading.", aliases: "同色系 单色系"),
        .init(.design(.complementary), .color, "互补配色", "Complementary colors",
              "选取色环上相对的色相，例如蓝和橙。一种作大面积基底，另一种少量点缀，就能拉开重点。",
              "Hues opposite each other on a color wheel, such as blue and orange, create a strong accent when used in unequal proportions.",
              "保留封面的深蓝底，只用橙色突出活动日期，让日期先被看到。",
              "Keep the cover deep blue and reserve orange for the event date so the date catches the eye first.", aliases: "撞色"),
        .init(.design(.semantic), .color, "语义色", "Semantic colors",
              "颜色和状态有固定对应关系，例如绿色表示成功。搭配图标和文字，状态在灰度画面中也能区分。",
              "Colors have consistent meanings, such as green for success. Icons and labels keep states distinguishable in grayscale.",
              "成功状态用绿勾和「已同步」，失败状态用红色叹号和「同步失败」。",
              "Show a green check with Synced on success and a red exclamation mark with Sync failed on error.", aliases: "状态色"),

        .init(.design(.serif), .typography, "衬线体", "Serif",
              "笔画末端有小装饰，宋体是中文常见例子。用在文章或专题标题上，容易形成出版物的气质。",
              "Small strokes finish the ends of letterforms. Song-style Chinese typefaces share this quality, often used in editorial headlines.",
              "把专题标题换成宋体，保留正文原有字体，让标题更像刊物篇名。",
              "Set the feature headline in a serif face and retain the body font for an editorial feel.", aliases: "宋体 明体"),
        .init(.design(.sansSerif), .typography, "无衬线体", "Sans serif",
              "笔画末端收得干净，黑体属于这一类。常用于导航、按钮和需要快速辨认的短标签。",
              "Letter strokes end cleanly. Common in navigation, buttons and short labels people need to recognize quickly.",
              "把侧栏导航统一为无衬线体，选中项加粗，其他项用常规字重。",
              "Use a sans serif face throughout the sidebar. Make the selected item bold and keep other items regular.", aliases: "黑体 sans-serif"),
        .init(.design(.monospace), .typography, "等宽字体", "Monospace",
              "每个拉丁字母和数字占据相同宽度，适合代码、色号或需要逐位对照的数值。",
              "Each Latin letter and digit occupies the same width, making code, hex values and digit-by-digit comparisons easier to scan.",
              "把两行色号换成等宽字体，并让井号左对齐，方便逐位比较。",
              "Use monospace for both hex values and align the hash signs so each character lines up.", aliases: "monospaced 等宽体"),
        .init(.design(.weight), .typography, "字重", "Font weight",
              "字重描述笔画的粗细。同样的字号下，加粗选中项就能表达层级，同时保持一行文字的节奏。",
              "Weight describes stroke thickness. A heavier selected label creates emphasis while keeping the same type size.",
              "导航字号都保留 14 px，把选中项字重从 400 调到 600。",
              "Keep all navigation labels at 14 px and change the selected item's weight from 400 to 600.", aliases: "粗体 bold semibold"),

        .init(.design(.motion(.duration)), .motion, "动画时长", "Duration",
              "从开始到结束经过的时间。同样的移动距离，时长越短，动作显得越利落。",
              "The time from start to finish. Over the same distance, a shorter duration makes a transition feel quicker.",
              "把筛选指示条的移动时长从 400 ms 缩短到 160 ms，让切换更跟手。",
              "Shorten the filter indicator's transition from 400 ms to 160 ms so it tracks selection more promptly.", aliases: "animation transition duration"),
        .init(.design(.motion(.easing)), .motion, "缓动曲线", "Easing",
              "决定动画在途中如何加速或减速。匀速移动节奏固定，缓出先快后慢，接近终点时收住。",
              "Controls how speed changes during a transition. Linear motion keeps a steady pace, while ease-out starts fast and slows near the end.",
              "抽屉展开时改用缓出曲线，让面板先迅速进入，再平稳停住。",
              "Use ease-out when opening the drawer so the panel enters quickly and settles gently.", aliases: "ease-out linear timing function"),
        .init(.design(.motion(.fade)), .motion, "淡入", "Fade-in",
              "保持位置不动，逐渐提高不透明度。适合提示或图片出现时，减少内容突然跳出的感觉。",
              "Opacity increases while position stays fixed. It softens the appearance of a message or a newly loaded image.",
              "让「已保存」提示在原位用 200 ms 淡入，提示出现时保留周围布局。",
              "Fade the Saved message in over 200 ms in place and keep the surrounding layout steady.", aliases: "透明度 opacity fade in"),
        .init(.design(.motion(.slide)), .motion, "滑入", "Slide-in",
              "元素从一个方向移动到最终位置。运动方向能说明抽屉、菜单等面板从哪里展开。",
              "An element moves into its final position from one side. Direction helps explain where a drawer or panel comes from.",
              "点击筛选后，让筛选面板从列表右侧滑入，并停靠在右边缘。",
              "When Filters is clicked, slide the panel in from the right and dock it to the list's right edge.", aliases: "位移 translate slide in"),

        .init(.design(.hierarchy), .principles, "视觉层级", "Visual hierarchy",
              "通过大小、字重、颜色和位置安排阅读顺序。先确定用户第一眼要看什么，再降低次要信息的分量。",
              "Size, weight, color and position establish reading order. Decide what people should notice first, then give supporting details less emphasis.",
              "把订单金额放大加粗，订单号缩小并移到下一行，让金额成为第一眼看到的信息。",
              "Enlarge and bold the order total. Move the smaller order ID to the next line so the total is read first."),
        .init(.design(.proximity), .principles, "亲密性原则", "Proximity",
              "距离近的元素容易被理解为一组。组内间距小于组间间距，就能让对应关系更清楚。",
              "Nearby elements tend to be perceived as a group. Smaller gaps within a group than between groups clarify which items belong together.",
              "将标签和对应输入框的间距设为 4 px，两组字段之间留 16 px。",
              "Leave 4 px between each label and its field, with 16 px between field groups.", aliases: "接近性 邻近性 格式塔 分组 gestalt"),
        .init(.design(.disclosure), .principles, "渐进式披露", "Progressive disclosure",
              "先展示完成当前任务需要的选项，把低频或复杂设置放进可展开的区域。",
              "Show the options needed for the current task first, with occasional or complex settings in an expandable area.",
              "导出面板默认显示文件格式，把色彩配置和压缩参数收进「高级设置」。",
              "Show file format by default in the export panel and group color profile and compression under Advanced settings."),
        .init(.design(.recognition), .principles, "识别优于回忆", "Recognition over recall",
              "把识别操作所需的线索直接放在界面上，例如给陌生图标加文字，让人能看出入口的用途。",
              "Put cues in the interface so people can recognize an action. A short label beside an unfamiliar icon makes its purpose easier to identify.",
              "在导出图标旁直接显示「导出」，让首次使用的人也能找到入口。",
              "Place an Export label beside the export icon so first-time users can recognize the action.", aliases: "recognition rather than recall 可识别性")
    ]
}
