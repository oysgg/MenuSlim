# 菜单栏间距 1.1.1（效果验证中）

中文原生 Swift / SwiftUI 工具，Apple Silicon，无第三方依赖。带阻尼刻度条、0–40 pt 数字刻度、整数吸附、方向键与步进微调、预设和恢复原设置。关闭窗口即退出。

## 当前边界

目标包含时钟和控制中心。初版写入后，用户反馈系统图标没有变化，未达到需求。1.1 已对照本机安装的 Menu Bar Spacing 1.2.2 修正内边距计算和系统服务刷新目标；用户反馈原版在点击 Relaunch All Apps 后才出现变化。因此 1.1 增加相同的一键重启普通应用入口；新版完整重启后的效果仍待用户操作确认，不以设置写入或进程刷新宣称验收。

数字代表系统偏好设置值（逻辑点），不保证每两个图标的可见边缘距离相等。普通应用需重新打开读取新值；可点击「重启所有 App」请求普通应用正常退出再打开；不会强制结束拒绝退出或等待保存的应用。

## 实现

只读写当前用户、当前主机的全局设置：

| 选择值 | NSStatusItemSpacing | NSStatusItemSelectionPadding |
| --- | --- | --- |
| 0–15 | 选择值 | max(2, min(选择值 - 2, 10)) |
| 16–40 | 选择值 | 删除该覆盖项 |

通过本机参考软件 1.2.2 的二进制控制流和 4、12、24 档实际偏好设置读回核对了规则。应用/恢复后只向当前用户的 com.apple.controlcenter、com.apple.systemuiserver 和已在运行的 com.apple.TextInputMenuAgent 发送 SIGTERM，由系统重新启动。菜单栏会短暂刷新，可能影响正在进行的屏幕共享；不刷新 MenuBarAgent。「重启所有 App」是独立的用户确认操作，列出实际候选应用；跳过本工具、Finder、系统服务和应用内部登录辅助程序。应用退出后从 Launch Services 注册的路径重新打开，无法退出或打开的项目显示在结果中。

首次应用前将原始两个设置备份到 ~/Library/Application Support/com.yangshuai.MenuSpacing/original.plist。后续不会覆盖备份。「恢复使用前设置」精确恢复数值或原先未设置的状态。未修改 SIP、权限或开机启动项。

macOS 未公开保证这些设置，升级系统后可能改变行为。原版作者的[兼容性说明](https://sindresorhus.com/menu-bar-spacing)与部分其他工具的说明存在差异，不能替代本机效果验证。

## 构建

使用现有 Apple Command Line Tools：

```sh
zsh build.sh /absolute/output/directory
```

产物本地 ad-hoc 签名，未做 Apple 公证。代码独立编写，参考软件仅用于行为对照，不包含其二进制或源代码。

1.1.1：单独重启 TextInputMenuAgent 后，用户确认微信输入法间距缩小，因此将其加入应用/恢复的刷新范围。天气菜单需通过系统设置中的天气开关重新加载，效果仍待确认，未加入自动刷新。
