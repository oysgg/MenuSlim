import SwiftUI
import AppKit

@MainActor final class SpacingModel: ObservableObject {
    @Published var value: Double = 8
    @Published var current = "读取中"
    @Published var message = "实验版：仅保存普通应用图标设置，重新打开对应应用后检查效果。"
    @Published var hasBackup = false
    @Published var busy = false
    @Published var error: String?
    let store = SpacingStore()

    init() { reload(setSlider: true) }
    func reload(setSlider: Bool = false) {
        do {
            let state = try store.read()
            current = state.spacing.map { "\($0) pt" } ?? "系统默认"
            if setSlider { value = Double(min(28, max(1, state.spacing ?? 8))) }
            hasBackup = FileManager.default.fileExists(atPath: store.backupURL.path)
        } catch { self.error = error.localizedDescription }
    }
    func apply(restore: Bool = false) {
        guard !busy else { return }
        busy = true
        do {
            if restore { try store.restore() } else { try store.apply(Int(value.rounded())) }
            reload(setSlider: restore)
            message = restore ? "已恢复使用前设置；普通应用重新打开后读取原设置。"
                : "设置已保存；请重新打开对应的普通应用检查效果。"
        } catch { self.error = error.localizedDescription }
        busy = false
    }
}

final class RulerInteraction: ObservableObject {
    @Published var dragging = false
}

struct DampedRuler: View {
    @Binding var value: Double
    @StateObject private var interaction = RulerInteraction()
    private let accent = Color.accentColor
    private func position(_ width: CGFloat) -> CGFloat { (value - 1) / 27 * width }
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 24
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.primary.opacity(0.10)).frame(width: width, height: 6).offset(x: 12, y: 16)
                Capsule().fill(accent).frame(width: max(0, position(width)), height: 6).offset(x: 12, y: 16)
                ForEach(1...28, id: \.self) { step in
                    let x = CGFloat(step - 1) / 27 * width + 12
                    Circle().fill(Int(value.rounded()) == step ? accent : Color.secondary.opacity(0.4))
                        .frame(width: 3, height: 3).position(x: x, y: 39)
                    Text("\(step)").font(.system(size: 9, weight: Int(value.rounded()) == step ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(Int(value.rounded()) == step ? accent : Color.secondary)
                        .position(x: x, y: 55)
                }
                Circle().fill(.white).frame(width: 24, height: 24)
                    .overlay(Circle().stroke(accent.opacity(interaction.dragging ? 0.65 : 0.25), lineWidth: interaction.dragging ? 5 : 3))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .position(x: 12 + position(width), y: 19)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    interaction.dragging = true
                    let next = min(28, max(1, 1 + Double((drag.location.x - 12) / width) * 27))
                    withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.86)) { value = next }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { value = value.rounded(); interaction.dragging = false }
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("图标间距")
            .accessibilityValue("\(Int(value.rounded())) 点")
            .accessibilityAdjustableAction { direction in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                    switch direction {
                    case .increment: value = min(28, value.rounded() + 1)
                    case .decrement: value = max(1, value.rounded() - 1)
                    @unknown default: break
                    }
                }
            }
            .focusable()
            .onKeyPress(.leftArrow) { value = max(1, value.rounded() - 1); return .handled }
            .onKeyPress(.rightArrow) { value = min(28, value.rounded() + 1); return .handled }
        }.frame(height: 68)
    }
}

struct SettingsView: View {
    @StateObject private var model = SpacingModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("菜单栏间距").font(.system(size: 24, weight: .semibold))
                    Text("实验版 · 普通应用图标").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("当前：\(model.current)").font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
            VStack(spacing: 10) {
                HStack(spacing: CGFloat(model.value)) {
                    Image(systemName: "cloud")
                    Image(systemName: "headphones")
                    Image(systemName: "terminal")
                    Image(systemName: "paperplane")
                    Image(systemName: "folder")
                }
                .font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity).frame(height: 36)
                .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.85), value: model.value)
                Text("间距示意 · 不同图标自身的留白可能不同").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth: .infinity).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("图标间距").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(Int(model.value.rounded()))").font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("pt").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                DampedRuler(value: $model.value)
                HStack(spacing: 8) {
                    preset("紧凑 4", 4)
                    preset("适中 8", 8)
                    preset("宽松 16", 16)
                    Spacer()
                    Stepper("微调", value: $model.value, in: 1...28, step: 1)
                        .fixedSize().help("每次调整 1 pt")
                }.controlSize(.small)
            }.disabled(model.busy)
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Text(model.message).font(.system(size: 12)).foregroundStyle(.secondary)
                Text("macOS 27 的时钟、控制中心、Wi-Fi、电池不跟随此设置。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.frame(height: 38, alignment: .topLeading)
            HStack {
                Button("恢复使用前设置") { model.apply(restore: true) }
                    .disabled(!model.hasBackup || model.busy)
                    .help("恢复首次点击应用前的两项间距设置")
                Spacer()
                Button("保存第三方图标设置") { model.apply() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(model.busy)
            }.controlSize(.large)
        }
        .padding(28).frame(width: 580)
        .alert("未能完成操作", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private func preset(_ title: String, _ value: Double) -> some View {
        Button(title) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { model.value = value }
        }
    }
}
