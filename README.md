# 微信开机自动登录（Windows）

开机后自动启动微信，并在登录窗口自动点“进入微信”，省掉每天那一次点击。
已经登录时不做任何事；需要扫码时不会乱点。

> 仅适用于 Windows + 微信 4.x 桌面版（开发测试环境：Windows 11 25H2 build 26200、微信 4.1.15.13）。

## 效果

- 登录 Windows 进入桌面后，微信自动出现并已进入主界面
- 主窗口出现前约 5–10 秒，全程无需操作
- 安装过程不改系统设置、不需要管理员权限

## 原理

登录窗口本质是一个自绘 UI（`mmui` 框架）。脚本没有用“切前台 + 回车”，因为开机瞬间前台焦点常被其他启动项抢走，`SetForegroundWindow` 会被系统静默拒绝，导致回车打空。

实际做法是：

1. 检测 `Weixin` 进程，没有就启动 `C:\Program Files\Tencent\Weixin\Weixin.exe`
2. 用 UI Automation 轮询微信顶层窗口，识别类名 `mmui::LoginWindow`
3. 在该窗口内找到名为“进入微信”的按钮，读出它的屏幕坐标
4. 把微信窗口临时置顶（不依赖焦点），在按钮坐标发送真实鼠标点击
5. 取消置顶，确认登录窗口消失后退出

另外两点关键细节：

- 微信的自绘按钮虽然暴露了 UIA `InvokePattern`，但调用无效，必须真实点击
- 脚本必须保存为 **UTF-8 带 BOM**，否则 Windows PowerShell 5.1 会按 ANSI 解码，中文字符串（“进入微信”）会乱码并导致语法错误

## 系统要求

- Windows 10 / 11
- 微信 4.x 桌面版（默认安装在 `C:\Program Files\Tencent\Weixin`）
- Windows PowerShell 5.1（系统自带）
- 手机端微信已开启“自动登录”（否则每次仍会要求手机确认）

## 安装

### 一键安装

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装脚本会：

- 把 `wechat-autologin.ps1` 复制到 `%LOCALAPPDATA%\WeChatAutoLogin\`
- 在启动文件夹创建 `微信.lnk`，以隐藏窗口方式调用该脚本

装完可立即验证（不用重启）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\WeChatAutoLogin\wechat-autologin.ps1"
```

### 手动安装

1. 复制 `wechat-autologin.ps1` 到 `%LOCALAPPDATA%\WeChatAutoLogin\`
2. 在 `shell:startup` 里新建快捷方式，目标填：

```
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

参数填：

```
-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LOCALAPPDATA%\WeChatAutoLogin\wechat-autologin.ps1"
```

## 卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

或直接删除启动文件夹里的 `微信.lnk`，以及 `%LOCALAPPDATA%\WeChatAutoLogin\` 目录。

## 配置项

脚本头部区域的常量可以直接改：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `$wechatExe` | `C:\Program Files\Tencent\Weixin\Weixin.exe` | 微信安装路径 |
| `$loginClass` | `mmui::LoginWindow` | 登录窗口的 UIA 类名 |
| 整体等待上限 | 150 秒 | 等登录窗口出现的时间 |
| 已登录判定 | 窗口宽度 > 800 | 大于该宽度视为已登录主窗口 |
| 按钮名 | `进入微信` | UI Automation 里按名字查找 |
| 按钮加载等待 | 15 秒 | 登录窗出现后等按钮渲染 |
| 完成确认 | 25 秒 | 点击后等登录窗消失 |

## 日志

路径：`%LOCALAPPDATA%\WeChatAutoLogin\log.txt`（超过 200 KB 自动清空）

常见记录：

| 日志 | 含义 |
|---|---|
| `wechat not running, started it` | 由脚本启动微信 |
| `clicking 进入微信 at x,y hwnd=...` | 找到按钮，准备点击 |
| `login completed` | 登录成功 |
| `already logged in, nothing to do` | 本来就在线 |
| `login window without enter-button (maybe QR state), give up` | 需要扫码，脚本不处理 |
| `no login window detected within timeout` | 150 秒内没出现登录窗口 |
| `login did not complete (phone confirm or QR needed)` | 点了没进去，多半是手机端自动登录失效 |

## 已知限制

- 微信要求**扫码登录**时脚本无能为力，需要手动扫一次
- 手机端关闭“自动登录”后会要求手机确认，脚本不会代确认
- 微信大版本改版可能改变控件类名/按钮名，需同步调整 `$loginClass` 或按钮名
- 脚本执行时会短暂把微信窗口置顶并移动鼠标，属正常现象
- 仅在单机单账号环境验证过

## 安全说明

- 本项目不是腾讯官方工具，只是本地 UI 自动化脚本，不联网、不读取聊天内容
- “自动登录”意味着任何能登录此 Windows 账户的人都能直接进入微信，共用电脑请谨慎使用
- 安装/卸载只改动启动文件夹和 `%LOCALAPPDATA%`，不写注册表、不需要管理员权限

## License

MIT，见 [LICENSE](LICENSE)。发布前把版权人改成你自己。
