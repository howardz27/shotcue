import SwiftUI

struct InterfaceSample: View {
    let control: InterfaceSpecimen
    let language: AppLanguage
    private let accent = Color(nsColor: Ink.color(0x4959AD))
    private let muted = Palette.muted

    var body: some View {
        sample.frame(maxWidth: 200).font(.system(size: 11))
            .allowsHitTesting(false)
    }

    private func label(_ zh: String, _ en: String) -> String { language.text(zh, en) }

    private func tag(_ name: String, filled: Bool = false) -> some View {
        Text(name).fontWeight(.medium).padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(filled ? .white : accent)
            .background(filled ? accent : .white, in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(accent.opacity(0.6)) }
    }

    private func field(_ name: String, icon: String? = nil) -> some View {
        HStack {
            if let icon { Image(systemName: icon).foregroundStyle(muted) }
            Text(name)
            Spacer(minLength: 0)
        }
        .padding(5).frame(width: 154).background(.white, in: RoundedRectangle(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.line) }
    }

    @ViewBuilder private var sample: some View {
        switch control {
        case .textarea:
            VStack(alignment: .leading) {
                Text(label("当前问题", "Current issue")).bold()
                Text(label("标题换行后，\n右侧按钮被挤出。", "When the title wraps,\nthe button overflows."))
                    .frame(width: 145, alignment: .leading).padding(5).background(.white).border(Palette.line)
            }
        case .combo, .command:
            VStack(alignment: .leading, spacing: 2) {
                field(control == .combo ? "Li" : label("导出", "Export"), icon: "magnifyingglass")
                HStack { Text(control == .combo ? "Lin Chen" : label("导出图片", "Export image")); Spacer(); Text("↵") }
                    .padding(4).frame(width: 154).background(accent.opacity(0.12))
            }
        case .slider:
            HStack {
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line).frame(width: 110, height: 5)
                    Capsule().fill(accent).frame(width: 66, height: 5)
                    Circle().fill(accent).frame(width: 13).offset(x: 59)
                }.frame(height: 18)
                Text("60%").monospacedDigit()
            }
        case .stepper:
            HStack(spacing: 16) { Text("−"); Text("3").bold(); Text("+") }.padding(7).background(.white).border(Palette.line)
        case .date:
            VStack(alignment: .leading, spacing: 4) {
                Text(label("六月", "June")).bold()
                HStack(spacing: 6) {
                    ForEach(9..<15) { day in
                        Text(String(day)).frame(width: 18, height: 18)
                            .foregroundStyle(day == 12 ? .white : Palette.primary)
                            .background(day == 12 ? accent : .clear, in: Circle())
                            .overlay { if day == 10 { Circle().strokeBorder(accent) } }
                    }
                }
            }.padding(5).background(.white)
        case .segment:
            HStack(spacing: 3) { Text(label("日", "Day")); tag(label("周", "Week"), filled: true); Text(label("月", "Month")) }
                .padding(4).background(.white, in: RoundedRectangle(cornerRadius: 5))
        case .upload:
            Label(label("拖入 PNG 或 JPG", "Drop PNG or JPG"), systemImage: "square.and.arrow.up")
                .padding(12).overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(accent, style: StrokeStyle(lineWidth: 1, dash: [4, 3])) }
        case .search:
            HStack { Image(systemName: "magnifyingglass"); Text("Studio"); Spacer(); Image(systemName: "xmark.circle.fill") }
                .padding(6).frame(width: 155).background(.white, in: Capsule())
        case .chip:
            HStack { tag("PNG  ×"); tag(label("本周  ×", "This week  ×")) }
        case .required, .invalid, .helper, .placeholder, .readonly:
            VStack(alignment: .leading, spacing: 3) {
                switch control {
                case .required:
                    Text(label("邮箱 · 必填", "Email · Required")).bold(); field("name@example.com")
                case .invalid:
                    field("name@"); Label(label("请输入有效邮箱", "Enter a valid email"), systemImage: "exclamationmark.circle").foregroundStyle(.red)
                case .helper:
                    field("••••••••"); Text(label("至少输入 8 个字符", "Use at least 8 characters")).foregroundStyle(muted)
                case .placeholder:
                    Text(label("街道地址", "Street address")).bold(); field(label("例如：中山路 18 号", "e.g. 18 Maple Street")).foregroundStyle(muted)
                default:
                    Text(label("订单编号", "Order ID")).bold(); field("ORD-1042", icon: "doc.on.doc")
                }
            }
        case .steps, .taborder:
            let items = control == .steps ? [label("配送", "Ship"), label("付款", "Pay"), label("确认", "Review")] : [label("邮箱", "Email"), label("密码", "Password"), label("登录", "Sign in")]
            HStack(spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, name in
                    if i > 0 { Image(systemName: "chevron.right").font(.caption2) }
                    VStack(spacing: 3) { Text(String(i + 1)).foregroundStyle(accent).bold(); Text(name) }
                }
            }
        case .menu:
            VStack(alignment: .leading, spacing: 4) {
                Label(label("重命名", "Rename"), systemImage: "pencil")
                Label(label("移动", "Move"), systemImage: "folder")
                Divider()
                Label(label("删除", "Delete"), systemImage: "trash").foregroundStyle(.red)
            }.frame(width: 96, alignment: .leading).padding(5).background(.white)
        case .tooltip, .iconname:
            VStack(spacing: 5) {
                Image(systemName: control == .tooltip ? "crop" : "trash").foregroundStyle(accent)
                Text(control == .tooltip ? label("裁剪图片", "Crop image") : label("删除此附件", "Delete attachment"))
                    .font(.caption).padding(4).foregroundStyle(.white).background(Palette.primary, in: RoundedRectangle(cornerRadius: 3))
            }
        case .popover:
            VStack(spacing: 2) {
                Circle().fill(accent).frame(width: 12, height: 12)
                Image(systemName: "arrowtriangle.up.fill").font(.system(size: 7)).foregroundStyle(.white)
                HStack { ForEach([Color.indigo, .mint, .orange], id: \.self) { c in Circle().fill(c).frame(width: 18) } }
                    .padding(5).background(.white, in: RoundedRectangle(cornerRadius: 4))
            }
        case .accordion:
            VStack(alignment: .leading, spacing: 4) {
                Label(label("配送方式", "Delivery"), systemImage: "chevron.down").bold()
                Text(label("标准配送 · 3 天", "Standard · 3 days")).foregroundStyle(muted)
                Divider()
                Label(label("退换政策", "Returns"), systemImage: "chevron.right")
            }.frame(width: 145, alignment: .leading)
        case .banner:
            Label(label("离线，等待重新连接", "Offline · Reconnecting"), systemImage: "wifi.slash")
                .padding(7).frame(maxWidth: .infinity).background(.orange.opacity(0.2))
        case .progress:
            VStack(alignment: .leading) {
                Text(label("正在上传 65%", "Uploading 65%"))
                ProgressView(value: 0.65).tint(accent)
            }.frame(width: 150)
        case .empty, .retry, .noresults:
            VStack(spacing: 4) {
                Text(control == .empty ? label("还没有项目", "No projects yet") : control == .retry ? label("加载失败", "Could not load") : label("没有匹配的项目", "No matching items"))
                tag(control == .empty ? label("新建项目", "Create project") : control == .retry ? label("重试", "Retry") : label("清除筛选", "Clear filters"))
            }
        case .cta, .variants, .disabled, .focus, .destructive, .expansion:
            HStack {
                switch control {
                case .cta: tag(label("查看演示  →", "View demo  →"), filled: true)
                case .variants: tag(label("预览", "Preview")); tag(label("保存", "Save"), filled: true)
                case .disabled: tag(label("上传", "Upload")).opacity(0.45); Text(label("请先选择文件", "Select a file first"))
                case .focus: tag(label("继续", "Continue")).padding(3).overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(accent, lineWidth: 2) }
                case .destructive: tag(label("取消", "Cancel")); Text(label("删除 3 个附件", "Delete 3 files")).foregroundStyle(.red)
                default: tag("Save"); tag("Speichern")
                }
            }
        case .toolbar:
            HStack(spacing: 10) {
                Image(systemName: "crop"); Image(systemName: "rotate.right"); Image(systemName: "magnifyingglass")
                Divider().frame(height: 17); Image(systemName: "square.and.arrow.up")
            }.padding(8).background(.white)
        case .table:
            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 3) {
                GridRow { Text(label("项目", "Item")).bold(); Text(label("金额", "Total")).bold() }
                GridRow { Text("Studio"); Text("128.00").gridColumnAlignment(.trailing) }
                GridRow { Text("Notes"); Text("49.00") }
            }.monospacedDigit().padding(6).background(.white)
        case .row, .hover:
            HStack {
                Image(systemName: "doc"); VStack(alignment: .leading) { Text("Guide.pdf"); Text(label("今天更新", "Updated today")).font(.caption).foregroundStyle(muted) }
                Spacer(); Image(systemName: "ellipsis")
            }.padding(7).frame(width: 155).background(control == .hover ? accent.opacity(0.12) : .white)
        case .skip:
            Label(label("跳到正文", "Skip to content"), systemImage: "arrow.turn.down.right")
                .padding(6).background(.white).overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(accent, lineWidth: 2) }
        case .status:
            HStack { Label(label("已保存", "Saved"), systemImage: "checkmark.circle"); Label(label("失败", "Failed"), systemImage: "exclamationmark.triangle") }
        case .avatars:
            HStack(spacing: -4) {
                ForEach(["AL", "JC", "MS", "+2"], id: \.self) { name in
                    Text(name).font(.caption.bold()).frame(width: 28, height: 28)
                        .background(name == "+2" ? .white : .indigo.opacity(0.22), in: Circle()).overlay { Circle().strokeBorder(.white, lineWidth: 2) }
                }
            }
        case .bulk:
            HStack { Image(systemName: "checkmark.square.fill"); Text(label("已选 3 项", "3 selected")); tag(label("归档", "Archive")) }
        case .reorder:
            VStack(alignment: .leading, spacing: 4) {
                Label(label("设计评审", "Design review"), systemImage: "line.3.horizontal")
                Rectangle().fill(accent).frame(width: 120, height: 2)
                Label(label("验收", "Acceptance"), systemImage: "line.3.horizontal")
            }
        case .loadmore:
            VStack { Divider(); Label(label("正在加载下一页", "Loading next page"), systemImage: "arrow.clockwise") }.frame(width: 155)
        }
    }
}
