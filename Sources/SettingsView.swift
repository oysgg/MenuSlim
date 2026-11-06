import AppKit
import SwiftUI

@MainActor final class SpacingModel: ObservableObject {
    @Published var language = Localization.selection
    @Published var value: Double = 8
    @Published var current = L("读取中")
    @Published var message = ""
    @Published var hasBackup = false
    @Published var busy = false
    @Published var error: String?
    @Published var confirmRelaunch = false
    @Published var relaunchResult: String?
    @Published var presentedReport: String?
    var auditReport: String?
    var auditBaseline: [MenuBarMeasurement]?
    var pendingRelaunch: [AppRelauncher.Candidate] = []
    let store = SpacingStore()

    init() { reload(setSlider: true) }
    func changeLanguage(_ choice: String) {
        Localization.selection = choice
        language = choice
        message = ""
        error = nil
        auditReport = nil
        presentedReport = nil
        relaunchResult = nil
        reload()
        NotificationCenter.default.post(name: Localization.changed, object: nil)
    }
    func reload(setSlider: Bool = false) {
        do {
            let state = try store.read()
            current = state.spacing.map { "\($0) pt" } ?? L("系统默认")
            if setSlider { value = Double(min(40, max(0, state.spacing ?? 8))) }
            hasBackup = FileManager.default.fileExists(atPath: store.backupURL.path)
        } catch { self.error = error.localizedDescription }
    }
    func apply(restore: Bool = false) {
        guard !busy else { return }
        busy = true
        auditBaseline = try? MenuBarAudit.capture()
        Task { @MainActor in
            do {
                if restore { try store.restore() } else { try store.apply(Int(value.rounded())) }
                let refreshed = await store.refreshSystemItems()
                reload(setSlider: restore)
                message =
                    (restore ? L("已恢复原设置。") : L("已保存设置。"))
                    + (refreshed.isEmpty ? L("已刷新系统项目，正在测量实际效果…") : refreshed.joined(separator: "; "))
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                measure()
                if !refreshed.isEmpty {
                    auditReport = L("刷新异常：%@\n\n", refreshed.joined(separator: "; ")) + (auditReport ?? "")
                }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    func measure() {
        do {
            let now = try MenuBarAudit.capture()
            if let before = auditBaseline {
                auditReport = MenuBarAudit.report(before, now)
                let results = MenuBarAudit.compare(before, now)
                message = L(
                    "自动检测：%ld 项变化，%ld 项未变化，%ld 项无法比较。", results.filter { $0.status == .changed }.count,
                    results.filter { $0.status == .unchanged }.count,
                    results.filter { $0.status == .unmeasurable }.count)
            } else {
                auditBaseline = now
                auditReport = L("已记录 %ld 个项目。下次应用间距后自动比较，也可点击检测重新测量。", now.count)
            }
        } catch {
            message = L("设置操作已结束；实际效果尚未验证。")
            auditReport =
                error.localizedDescription + L("\n\n可在系统设置 → 隐私与安全性 → 辅助功能中自行授权本工具。权限仅用于读取菜单栏尺寸，程序不会自动请求或开启。")
        }
    }
    func prepareRelaunch() {
        pendingRelaunch = AppRelauncher.candidates()
        if pendingRelaunch.isEmpty {
            error = L("没有可重新打开的普通应用。")
            return
        }
        confirmRelaunch = true
    }
    func relaunchApps() {
        busy = true
        Task { @MainActor in
            relaunchResult = await AppRelauncher.run(pendingRelaunch) { self.message = $0 }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            measure()
            busy = false
        }
    }
}

final class RulerInteraction: ObservableObject {
    @Published var dragging = false
}

struct DampedRuler: View {
    @Binding var value: Double
    @StateObject private var interaction = RulerInteraction()
    private let accent = Color.accentColor
    private func position(_ width: CGFloat) -> CGFloat { value / 40 * width }
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 24
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.primary.opacity(0.10)).frame(width: width, height: 6).offset(
                    x: 12, y: 16)
                Capsule().fill(accent).frame(width: max(0, position(width)), height: 6).offset(x: 12, y: 16)
                ForEach(0...40, id: \.self) { step in
                    let x = CGFloat(step) / 40 * width + 12
                    Circle().fill(Int(value.rounded()) == step ? accent : Color.secondary.opacity(0.4))
                        .frame(width: 3, height: 3).position(x: x, y: 39)
                    Text(step % 2 == 0 ? "\(step)" : "").font(
                        .system(
                            size: 9, weight: Int(value.rounded()) == step ? .bold : .regular,
                            design: .monospaced)
                    )
                    .foregroundStyle(Int(value.rounded()) == step ? accent : Color.secondary)
                    .position(x: x, y: 55)
                }
                Circle().fill(.white).frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(
                            accent.opacity(interaction.dragging ? 0.65 : 0.25),
                            lineWidth: interaction.dragging ? 5 : 3)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .position(x: 12 + position(width), y: 19)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        interaction.dragging = true
                        let next = min(40, max(0, Double((drag.location.x - 12) / width) * 40))
                        withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) {
                            value = next
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            value = value.rounded()
                            interaction.dragging = false
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("图标间距"))
            .accessibilityValue(L("%ld 点", Int(value.rounded())))
            .accessibilityAdjustableAction { direction in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                    switch direction {
                    case .increment: value = min(40, value.rounded() + 1)
                    case .decrement: value = max(0, value.rounded() - 1)
                    @unknown default: break
                    }
                }
            }
            .focusable()
            .onKeyPress(.leftArrow) {
                value = max(0, value.rounded() - 1)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                value = min(40, value.rounded() + 1)
                return .handled
            }
        }.frame(height: 68)
    }
}

struct SettingsView: View {
    @StateObject private var model = SpacingModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(L("菜单栏间距")).font(.system(size: 21, weight: .semibold))
                        Text(
                            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                                ?? ""
                        )
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    Text(L("兼容 macOS 27")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Picker(L("语言"), selection: Binding(get: { model.language }, set: model.changeLanguage)) {
                    Text(L("跟随系统")).tag("system")
                    Text("简体中文").tag("zh-Hans")
                    Text("English").tag("en")
                }.labelsHidden().frame(width: 132).controlSize(.small).disabled(model.busy)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("图标间距")).font(.system(size: 13, weight: .medium))
                    Text(L("当前：%@", model.current)).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.value.rounded()))")
                        .font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("pt").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                DampedRuler(value: $model.value).id(model.language)
                HStack(spacing: 8) {
                    preset(L("紧凑 4"), 4)
                    preset(L("适中 8"), 8)
                    preset(L("宽松 16"), 16)
                    Spacer()
                    Stepper(L("微调"), value: $model.value, in: 0...40, step: 1)
                        .labelsHidden().fixedSize().help(L("每次调整 1 pt"))
                }.controlSize(.small)
            }.disabled(model.busy)
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Menu(L("更多")) {
                    Button(L("恢复使用前设置")) { model.apply(restore: true) }.disabled(!model.hasBackup)
                    Button(L("检测实际效果")) {
                        model.measure()
                        model.presentedReport = model.auditReport
                    }
                    Button(L("查看上次检测结果")) { model.presentedReport = model.auditReport }.disabled(
                        model.auditReport == nil)
                    Divider()
                    Button(L("重启所有 App…")) { model.prepareRelaunch() }
                    Button(L("兼容性说明")) { model.presentedReport = L("compatibility.details") }
                }.fixedSize().menuStyle(.borderlessButton).disabled(model.busy)
                Spacer()
                Button(model.busy ? L("正在刷新…") : L("应用间距")) { model.apply() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut(.defaultAction).disabled(model.busy)
            }
        }
        .padding(24).frame(width: 560)
        .environment(\.locale, Locale(identifier: Localization.language))
        .sheet(
            isPresented: Binding(
                get: { model.presentedReport != nil }, set: { if !$0 { model.presentedReport = nil } })
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("详细信息")).font(.headline)
                ScrollView {
                    Text(model.presentedReport ?? "").font(.system(size: 12)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button(L("关闭")) { model.presentedReport = nil }.keyboardShortcut(.cancelAction)
                }
            }.padding(24).frame(width: 500, height: 340)
        }
        .alert(
            L("未能完成操作"),
            isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
        ) {
            Button(L("知道了")) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        .alert(L("重启所有 App？"), isPresented: $model.confirmRelaunch) {
            Button(L("取消"), role: .cancel) {}
            Button(L("退出并重新打开")) { model.relaunchApps() }
        } message: {
            Text(
                L(
                    "将请求 %ld 个应用正常退出并重新打开，包括浏览器和工作应用。请先保存内容；遇到保存提示请自行处理，不会强制退出。\n\n%@",
                    model.pendingRelaunch.count, model.pendingRelaunch.map(\.name).joined(separator: ", ")))
        }
        .alert(
            L("应用重启结果"),
            isPresented: Binding(
                get: { model.relaunchResult != nil }, set: { if !$0 { model.relaunchResult = nil } })
        ) {
            Button(L("知道了")) { model.relaunchResult = nil }
        } message: {
            Text(model.relaunchResult ?? "")
        }
    }
    private func preset(_ title: String, _ value: Double) -> some View {
        Button(title) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { model.value = value }
        }
    }
}
