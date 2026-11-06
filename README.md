# 菜单栏间距（未完成的实验版）

**未达到“包括时钟、控制中心在内一起调整”的需求。** macOS 27.0.1 上实际保存设置和刷新 MenuBarAgent 后，用户反馈系统菜单栏没有变化。不能将此程序视为完整交付。已删除无效的菜单栏进程刷新操作及系统图标会生效的提示。

此路线仅可能影响重新启动后的普通 AppKit 应用。系统图标不跟随这两个键；本机第三方应用的视觉效果尚未验证。参考 [独立工具的测量和限制](https://github.com/nlink-jp/menubar-spacer#limits)。

为当前 Mac 制作的免费、无第三方依赖的小工具。原生 Swift / SwiftUI，Apple Silicon。

- 带弹簧阻尼动画的刻度滑条；1–28 pt，每一档显示数字，松手吸附整数。
- 支持方向键、步进按钮、预设和辅助功能调整。
- 预览不修改系统；点击「保存第三方图标设置」才保存设置，不重启任何进程。
- 「恢复使用前设置」恢复首次应用之前的两个设置，包括原来不存在的键。
- 关闭窗口即退出，无开机自启或后台常驻。

数字是系统偏好设置值（逻辑点），不是承诺所有图标可见边缘之间都有相同像素距离。第三方应用通常需要重新打开才能读取新间距，本工具不会批量重启其他应用。

## 构建

使用已安装的 Apple Command Line Tools，不下载或安装依赖：

```sh
zsh build.sh /absolute/output/directory
```

产物为本地 ad-hoc 签名，未做 Apple 公证；目标为本机使用。

## 实现和恢复

读写当前用户、当前主机全局偏好中的 `NSStatusItemSpacing` 和 `NSStatusItemSelectionPadding`。首次应用前将两个值备份到 `~/Library/Application Support/com.yangshuai.MenuSpacing/original.plist`，后续应用不会覆盖备份。

这是未公开保证的 macOS 设置，后续系统更新可能改变效果。初始实现路线参考 [Dimble 的公开源码说明](https://github.com/fif7y/dimble/blob/main/Pelmet/App/IconSpacingApplier.swift)，但其系统图标会生效的说明与本机实测不符。本项目代码独立编写。
