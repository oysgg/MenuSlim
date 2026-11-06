# macOS 27 兼容性 / Compatibility

支持在 macOS 27 调整菜单栏间距，但并非每个系统项目都响应这两项偏好设置。
MenuSlim supports spacing adjustment on macOS 27; not every system item responds.

## 本机验证（2026-11-06）

macOS 27.0.1、Apple Silicon、单显示器。本表仅记录系统项，不包含本机第三方应用清单。自动矩阵临时应用 0、8、24 并刷新组件，随后读回确认恢复到运行前的 0 / 2。

| 系统项目 | 0 / 8 / 24 档占位宽度（pt） | 结果 |
| --- | --- | --- |
| 天气 | 54 / 62 / 78 | 单独重新打开天气组件后随档位变化 |
| 电池 | 26 / 26 / 26 | 未测得变化；右侧空隙始终 8 |
| 控制中心 | 26 / 26 / 26 | 未测得变化；右侧到时钟空隙始终 12.5 |
| 时钟 | 144.5 / 144.5 / 144.5 | 未测得变化 |
| 专注模式 | 22 / 22 / 22 | 未测得变化；右侧空隙始终 16 |
| 屏幕镜像 | 20.5 / 20.5 / 20.5 | 未测得占位变化，相邻项不稳定 |
| 音频和视频控制 | 20 / 20 / 20 | 未测得占位变化，相邻项不稳定 |
| 聚焦 | — | 遮挡，无法可靠比较 |
| 输入菜单 | — | 单独刷新后有人工缩小确认；自动检测中标识不稳定，未计为自动通过 |

早期矩阵的 24 档曾报告 SystemUIServer 暂时未运行，检测保留此类异常。最终 0 / 8 / 24 回归三个档位均无刷新异常，恢复后天气为单实例。额外在 24 档重新启动 MenuBarAgent 后，上述时钟、控制中心、电池等占位仍与基线一致，因此没有把重启 MenuBarAgent 加入产品。未开启的 Wi-Fi、蓝牙等项目没有临时替用户开启，不宣称已经覆盖。天气另外通过系统设置开关重载，以及直接重新打开后台组件，两种方式均验证了 24 → 0 档的 78 → 54 pt 变化。


## Measurement limits

Weather measured 54 / 62 / 78 pt at settings 0 / 8 / 24 on macOS 27.0.1, Apple Silicon, one display. The input menu became narrower after a separate refresh, but its identity was not stable enough for automated grading. Clock, Control Center, Battery, Focus, Screen Mirroring and Audio & Video Controls did not change in these tests. Spotlight was obscured. Disabled items, other macOS versions, multiple displays and third-party menu bar managers have not been verified.

测量读取系统提供的标识和占位，不读取 AXValue / AXHelp，不截屏或上传。未知、重名、遮挡、消失的项目不计为通过；温度、时间等动态内容也会改变尺寸。图标内部留白无法单独测量。

Measurement reads identifiers and bounds, without AXValue / AXHelp, screenshots or uploads. Unknown, duplicate, obscured and missing items are not marked as passed. Dynamic content can change widths; internal icon padding cannot be measured separately.

## 普通应用重启流程

macOS 27.0.1 上，独立原生 NSStatusItem 对照项在 0 / 24 档重新启动后，占位宽度为 32 / 56 pt。这个结果证明标准状态项可以读取所保存的参数，不代表所有第三方实现均有相同响应。

1.0.0 build 2 修正了「改变滑条后只点重启，仍使用旧设置」的流程：确认时冻结所选间距，保存成功后才开始退出应用。实测覆盖确认前不写入、保存失败不退出，以及新进程读取 24 pt 并测得 56 pt 占位。重启优先保留当前应用路径，并核对进程 ID 已改变。独立登录辅助程序和应用自身的透明留白仍可能不响应。

On macOS 27.0.1, an isolated native NSStatusItem measured 32 / 56 pt after relaunching with spacing 0 / 24. Build 2 applies the confirmed value before quitting apps, aborts on write failure, preserves the running app path, and checks for a different process ID. This does not establish compatibility with every third-party implementation or independent helper.
