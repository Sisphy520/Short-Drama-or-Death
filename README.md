# 🍅 Short Drama or Death
**For Short Drama Addicts Who Consider Picking Up a Phone a Violation of Their Fundamental Human Rights.**
Target users：ShortDramaAddicts and PhonePickupHaters
**献给那些认为拿起手机侵犯了自己基本人权的短剧成瘾者。**
**目标用户：短剧成瘾者和拿起手机厌恶者**

> **Mission-critical infrastructure for absolutely non-critical entertainment.**  
> 为毫无战略意义的娱乐活动，建设高度严肃的技术基础设施。

**An unnecessarily elaborate way to watch Chinese short dramas on a Mac without picking up a phone.**  
**一种为了不拿起手机看短剧，而写出了几百行 Shell 脚本的解决方案。**

**Tested on:** Samsung Galaxy Z Fold6 · **Maintenance:** Emotionally available · **Next release:** Classified, possibly nonexistent

---

## 🧠 Why does this exist? / 这个项目为什么存在？

I wanted to watch short dramas on my Mac. Unfortunately, they were on my Android phone.

我想在 Mac 上看短剧。不幸的是，短剧在 Android 手机上。

I had two options:

1. Pick up my phone.
2. Build a wireless Android streaming system with ADB, scrcpy, mDNS discovery, a virtual display, audio forwarding, interactive setup, and experimental power management.

Naturally, I chose option 2.
Actually, It can significantly reduce your screen time  (not really).

摆在我面前的有两条路：拿起手机，或者研究无线调试、虚拟显示、音视频编码、设备发现与屏幕电源管理。

**显然，第二条路更符合人类文明的发展方向。**
**这还显著的减少了你的手机使用时间（也许，但是我不在乎）**

This project does **not** implement its own video codec or streaming protocol. It automates excellent existing tools to solve an extremely personal inconvenience.

本项目没有自己发明视频编解码器，也没有重造网络协议。它只是把现有工具组合起来，解决开发者一个极其私人且完全可以通过拿起手机解决的问题。

---

## 🎬 What does it actually do? / 它究竟能干什么？

- **Wireless connection / 无线连接：** Connect to an already paired Android phone through ADB wireless debugging. / 使用 ADB 无线调试连接已配对的手机。
- **Automatic discovery / 自动发现：** Reuse a cached address or search for a new one via mDNS. / 优先复用现有连接，必要时使用缓存和 mDNS 寻找手机。
- **Independent display / 独立显示：** Run Fanqie on a separate Android virtual display shown on your Mac. / 在 Mac 上显示独立的 Android 虚拟屏幕，手机实体屏幕仍可使用。
- **Audio forwarding / 音频转发：** Send Android playback audio to the Mac through scrcpy. / 将 Android 的播放音频转发至 Mac。
- **Remote control / 远程操作：** Click, swipe, and interact from your Mac. / 在 Mac 上使用鼠标和键盘操作应用。
- **Interactive onboarding / 交互式引导：** Guide new users through pairing, or help previously paired users reconnect. / 连接失败时提供首次配对与已有配对的不同操作入口。
- **Dependency checks / 依赖检查：** Ask to install missing tools, without repeatedly asking to install tools that are already present. / 缺少依赖才询问安装，已经安装过的就别再烦用户。
- **Experimental screen guard / 实验性屏幕守护：** Attempt to keep virtual-display playback alive when the physical screen is turned off. / 尝试在实体屏幕熄灭后维持虚拟显示播放。
- **Quality controls / 画质选项：** Quality-first defaults, low-bandwidth fallback, and optional H.265. / 默认画质优先，支持省带宽模式以及可选的 H.265 编码。

**Important:** Independent display means separate *display surfaces*, not separate phones. Apps, sound, battery, system state, and Android restrictions can still interact.

**注意：** 独立显示不是凭空创造第二台手机。两个显示界面仍然共享 Android 系统、应用资源、音频和电源状态。

---

## 🧪 Compatibility / 兼容性

**Tested device: Samsung Galaxy Z Fold6.**

**已测试设备：Samsung Galaxy Z Fold6。**

That's the entire official test fleet. One phone. An exceptionally prestigious fleet, admittedly.

以上即为全部官方测试设备。一台。规模不大，但精神可嘉（我已经很棒了）。

Other Android devices **may** work. This repository does not claim they will.

其他 Android 设备可能（对的你没看错，是可能，至于为什么不是保证，你真该去学学逻辑学）可以运行，但不作任何兼容性保证。

> **When will my phone be supported?**  
> When I buy one. Maybe. Or you could buy me a flagship phone(strongly recommended). Either way, no updates are guaranteed—even if you buy me the phone
> **什么时候支持我的手机？**  
> 等我买了再说。买了也不一定。或者你也可以给我买个旗舰手机(强烈推荐）。不过，即使你真的给我买了手机，更新也不是保证的，因为白嫖是人类的第一驱动力。

### Requirements / 环境要求

- macOS with **zsh** / 使用 zsh 的 macOS
- Android with **Wireless Debugging** / 支持无线调试的 Android 手机
- **ADB** (`android-platform-tools`) and **scrcpy**
- scrcpy **3.0+** for the independent virtual-display mode / 独立显示模式需要 scrcpy 3.0 或更新版本
- Android **11+** for audio forwarding / 音频转发需要 Android 11 或以上
- A local network that permits communication between your Mac and phone / Mac 与手机之间可以互相通信的局域网

The experimental screen guard is enabled only when Android reports a supported display-control command and the device is on Android 15+; results can differ by device and ROM.

实验性屏幕守护只会在 Android 15+ 且检测到相关显示控制命令时启用。不同设备与系统版本的实际效果可能不同。

---

## 🚀 Installation / 安装

### 1. Get the script / 获取脚本

Download this repository and open Terminal in its directory. Then run:

下载仓库，在项目目录中打开终端，赋予脚本执行权限：

```bash
chmod +x mirror_fanqie.sh
```

This is a **zsh** script. Run it with `./mirror_fanqie.sh` or `zsh mirror_fanqie.sh`, **not** `bash mirror_fanqie.sh`.

这是一个 zsh 脚本。不要因为看到 Shell 就条件反射地用 Bash 执行。

### 2. Dependencies / 检查依赖

The launcher checks for `adb` and `scrcpy`. If either is missing, an interactive terminal may offer to install it using Homebrew. Existing working commands are skipped.

脚本会检查 `adb` 和 `scrcpy`。缺少工具时才会询问是否通过 Homebrew 安装。已经安装的工具不会反复要求安装。

Manual installation / 手动安装：

```bash
brew install scrcpy
brew install --cask android-platform-tools
```

The script may also offer to install Homebrew if necessary, **but only after asking permission**. Review what you are agreeing to; the author is not responsible for your terminal habits.

如果缺少 Homebrew，交互模式也可能询问是否安装，但不会未经同意直接执行安装。请认真阅读提示。开发者（也就是我）不负责替用户（也就是你）管理点击确认的冲动。

### 3. Enable Wireless Debugging / 开启无线调试

On a Samsung phone / 在三星手机（也就是我的手机，fold6，至于为什么不是fold8，你看我名字「忧郁的穷逼孩子」啊）上：

1. Open **Settings → About phone → Software information**. / 打开**设置 → 关于手机 → 软件信息**。
2. Tap **Build number** seven times to enable Developer options. / 连续点击**版本号**七次开启开发者选项。
3. Open **Developer options → Wireless debugging**. / 进入**开发者选项 → 无线调试**。
4. Choose **Pair device with pairing code**. / 选择**使用配对码配对设备**。

Use a trusted Wi-Fi network. ADB wireless debugging is a development feature, not something to leave enabled indiscriminately on untrusted networks（Yes, you can. No, you probably shouldn't).

请使用可信任的 Wi-Fi 网络。无线调试是开发功能，不建议在不可信的网络上随意开启（尽管你完全有能力做到，但是，不能，至少不应该）。

### 4. Pair once / 首次配对

For guided pairing / 使用交互式配对：

```bash
./mirror_fanqie.sh pair
```

Or provide the details directly / 也可以直接输入配对信息：

```bash
./mirror_fanqie.sh pair IP:PAIR_PORT PAIR_CODE
```

**Pairing port ≠ connection port.** Android provides both, because apparently one port would have been insufficiently dramatic.

**配对端口 ≠ 连接端口。** Android 提供两套端口，显然是为了让这件事稍微更有戏剧性。

### 5. Watch something questionable / 开始观看(批判）严肃的短剧内容

```bash
./mirror_fanqie.sh
```

The script checks dependencies, tries to connect to your phone, and launches Fanqie (`com.dragon.read`) through scrcpy.

脚本会检查依赖，尝试自动连接手机，并通过 scrcpy 启动番茄小说（`com.dragon.read`）。

**In the default independent-display mode, enter the short-drama tab yourself from the Mac window.** The script does *not* claim to navigate there automatically in this mode.

**默认独立显示模式不会自动点击短剧入口。** 请在 Mac 投屏窗口中自行进入短剧板块。至少这一步，开发者（真诚的）认为用户仍有能力完成。

If no connection can be established, the interactive menu offers first-time pairing, manual connection, or another automatic search.

如果无法自动连接，脚本会提供首次配对、手动输入地址和重新搜索等交互选项。

---

## ⌨️ Usage / 命令用法

| Command | What it does / 功能 |
|---|---|
| `./mirror_fanqie.sh` | Auto-connect and open the independent virtual display / 自动连接并开启独立虚拟显示 |
| `./mirror_fanqie.sh pair` | Guided pairing / 交互式配对 |
| `./mirror_fanqie.sh pair IP:PORT CODE` | Pair with explicit details / 使用指定配对信息 |
| `./mirror_fanqie.sh IP:PORT` | Connect to a specified address / 指定连接地址 |
| `./mirror_fanqie.sh --lq` | Low-bandwidth mode / 省带宽模式 |
| `./mirror_fanqie.sh --hq` | Alias for the quality-first defaults / 恢复默认高画质设置 |
| `./mirror_fanqie.sh --h265` | Request H.265 encoding / 尝试使用 H.265 编码 |
| `./mirror_fanqie.sh --mirror` | Mirror the physical phone screen / 镜像手机实体屏幕 |
| `./mirror_fanqie.sh --no-guard` | Disable the experimental screen guard / 禁用实验性屏幕守护 |
| `./mirror_fanqie.sh --restore-screen` | Attempt to reset the physical display / 尝试恢复实体屏幕状态 |
| `./mirror_fanqie.sh --audio-source playback` | Try application-playback capture / 尝试捕获应用播放音频 |
| `./mirror_fanqie.sh --audio-buffer 200` | Change audio buffer in milliseconds / 调整音频缓冲 |
| `./mirror_fanqie.sh --aac` | Request AAC audio / 使用 AAC 音频编码 |
| `./mirror_fanqie.sh --no-audio` | Disable audio forwarding / 关闭音频转发 |
| `./mirror_fanqie.sh --no-drama` | Skip automatic drama-tab navigation in mirror mode / 镜像模式下跳过自动进入短剧 |
| `./mirror_fanqie.sh -s SERIAL` | Choose an ADB device / 指定目标设备 |
| `./mirror_fanqie.sh --debug` | Diagnostic output / 输出调试信息 |
| `./mirror_fanqie.sh --help` | Show help / 查看帮助 |

### Video settings / 画质设置

| Setting | Default / 默认 | `--lq` |
|---|---|---|
| Resolution cap / 分辨率上限 | No downscaling (`--max-size 0`) / 不主动缩放 | Longest side 1280 / 最长边 1280 |
| Video bitrate / 视频码率 | 16 Mbps | 6 Mbps |
| Frame-rate cap / 帧率上限 | 60 FPS | 30 FPS |
| Video codec / 视频编码 | scrcpy default / scrcpy 默认 | scrcpy default / scrcpy 默认 |
| Audio buffer / 音频缓冲 | 100 ms | 100 ms |

`--h265` is **optional**, not the default. A 60 FPS cap does not magically turn 30 FPS source video into 60 FPS. High bitrate also cannot create detail missing from the source.

`--h265` 是**可选项**，不是默认开启。60 FPS 只是帧率上限，不会让 30 FPS 原片凭空多出一倍帧数。再高的码率也无法修复原视频本来就不清晰的问题。

For a fixed vertical virtual display / 固定竖屏虚拟显示示例：

```bash
FANQIE_VD=1080x1920/420 ./mirror_fanqie.sh --h265
```

For other advanced settings, inspect `./mirror_fanqie.sh --help` and the script's environment variables, including `FANQIE_PKG`, `FANQIE_MODE`, `FANQIE_CACHE`, and `FANQIE_SCRCPY_ARGS`.

其他高级设置可以参阅 `--help` 与脚本中的环境变量，包括包名、显示模式、缓存地址和附加的 scrcpy 参数。

---

## 🔒 Screen guard / 屏幕守护

The independent display and the physical phone screen are different displays. However, entering certain sleep states can still interrupt virtual-display rendering on some devices.

独立虚拟屏幕和手机实体屏幕不是同一个显示器，但某些系统休眠状态仍然可能让虚拟屏幕黑掉。

On a supported device, the experimental guard watches the Android wakefulness state and attempts to keep the device active while manipulating the physical display's power state. The script tries to restore the display when it exits.

在支持的设备上，实验性守护程序会监测 Android 的唤醒状态，并尝试在关闭实体屏幕的同时维持设备活跃。脚本退出时也会尝试恢复屏幕状态。

**This is not a security lock.** Screen off ≠ securely locked. It is also not guaranteed to behave identically across Android releases or manufacturers.

**这不是安全锁屏。** 实体屏幕熄灭不代表系统已安全锁定。不同 Android 版本和厂商也不保证行为一致。

Emergency command / 应急命令：
I hope you never use it./我希望你永远不要用到它。

I sincerely hope I never have to use it either./我希望我也永远不要用到它，真心的，我真的不想，不愿意，也不希望，有用到它的一天。

```bash
./mirror_fanqie.sh --restore-screen
```

This requires ADB to be connected and the necessary display-control commands to work. If your phone behaves oddly, stop the script and use the phone's normal controls before trying anything heroic.

该命令仍需要正常的 ADB 连接和受支持的显示控制命令。如果屏幕表现异常，请先结束脚本并尝试手机本身的正常操作，不必立即开展史诗级抢救工程。

---

## 🧯 Troubleshooting / 常见问题

**Can't connect? / 连不上？**  
Confirm both devices can communicate over the same network, Wireless Debugging is enabled, and the phone has been paired. Try `--debug` or specify `IP:PORT` manually.

确认网络可互通、无线调试已开启且已配对。尝试 `--debug` 或手动指定连接地址。

**No audio? / 没声音？**  
Some apps or Android configurations may restrict capture. Try `--aac` if the audio encoder fails, or `--audio-source playback` if supported. The default `output` source may mute the physical phone's sound.

部分应用或系统可能限制音频捕获。如果编码器报错可以尝试 `--aac`，符合条件时也可测试 `--audio-source playback`。默认 `output` 捕获模式可能让手机本身不再出声。

**H.265 fails? / H.265 报错？**  
Remove `--h265`. You are trying to watch short dramas, not certify video encoders.

去掉 `--h265`。我们的目标是看短剧，不是给硬件编码器颁发合格证书。

**Video stutters? / 视频卡顿？**  
Try `--lq`, improve Wi-Fi conditions, or adjust buffering. More bitrate is not always better.

尝试 `--lq`，改善 Wi-Fi 条件或调整缓冲。码率越高，不一定越快乐。

**Why won't the script automatically tap the drama tab? / 为什么没有自动点进短剧？**  
Automatic UI-label navigation is attempted only in **mirror mode**. In the default independent mode, open the tab yourself.

自动识别并点击短剧标签仅在**镜像模式**中尝试。默认独立模式需要手动点击。

---

## 📱 Compatibility policy / 兼容性政策

**Q: Does it work on my phone?**  
A: I don't know. I don't own your phone.

**问：我的手机能用吗？**  
答：我不知道。我没有你的手机。

**Q: Can you add support for my device?**  
A: I'll consider it when I buy that device.

**问：能适配我的设备吗？**  
答：等我买了再考虑。

**Q: When will you buy it?**  
A: That is a personal financial decision, not a project milestone.

**问：你什么时候买？**  
答：这是我的个人消费决策，不是项目里程碑。

**Q: Can I fork it and make it work myself?**  
A: You can inspect and fork the public repository. Check its actual license before assuming redistribution rights.

**问：那我可以自己改吗？**  
答：你可以查看并 Fork 公开仓库。涉及重新分发时，请以仓库实际附带的许可证为准。

---

## 🔮 Future development / 未来开发计划

### YubiKey authentication / YubiKey 硬件认证

**Status: Conceptually magnificent. Technically inconvenient.**  
**状态：概念上极其伟大，实现起来有点麻烦。**

YubiKey is not cheap, but I have two of them.
Prepare two of them, because if you lose one of them, it can be a disaster.
这东西蛮贵的，但是我有俩。
你最好准备两个，如果你丢了一个，卧槽，那你遭老罪咯。

I am considering requiring a physical YubiKey before launching this extraordinarily sensitive short-drama viewing infrastructure.

我正在考虑为这套高度敏感的短剧观看基础设施加入 YubiKey 实体安全密钥认证。届时，观看霸总（也就是我）失忆前，或许还需要完成硬件身份验证。

A launcher-level check would **not** secure ADB or prevent someone from running scrcpy directly. A real security boundary would require more work. Unfortunately, I also have a life to live.

当然，仅仅保护脚本入口，并不能保护 ADB，也无法阻止别人直接运行 scrcpy。要实现真正的访问控制，需要更完整的设计。不幸的是，开发者还打算过自己的生活。

Possible outcomes / 可能结果：

- Implemented someday. / 某天实现。
- Considered forever. / 永久考虑。
- Implemented locally and never published. / 本地实现，但永不公开。
- Forgotten entirely.(**most likely**) / 彻底忘记此事。 （**最可能**）

**ETA: When I feel like it. Possibly never.**  
**预计完成时间：等我哪天想起来，也可能永远没有。**

---

## 🛠️ Maintenance policy / 维护政策

**This is a personal project, not a public utility, a subscription service, or a contractual obligation.**

**这是个人项目，不是公共事业，不是订阅服务，更不是开发者对全世界承担的合同义务。**

1. **Updates are optional.** I make them when I want or need them.  
   **更新随缘。** 本人认为有必要，且本人愿意动手时，才可能更新。
2. **Release schedules do not exist.** There is no SLA, timetable, or delivery guarantee.  
   **不存在更新周期。** 没有服务等级协议，没有截止日期，没有交付承诺。
3. **Finished does not mean published.** Code may work perfectly on my Mac and still never appear here.  
   **写完不代表上传。** 本地更新即使已经完成，也不保证出现在 GitHub。
4. **Issues are suggestions, not summonses.** They may be read, ignored, postponed, or forgotten.  
   **Issue 是建议，不是传票。** 可能阅读，可能忽略，可能搁置，也可能忘记。
5. **Pull requests are not purchase orders.** Submitting one does not guarantee review or acceptance.  
   **PR 不是采购订单。** 提交不代表保证审查，更不代表保证合并。
6. **The author reserves the right to watch short dramas instead of maintaining this project.**  
   **开发者保留放弃维护工作，转而使用本软件观看短剧的全部自由。**

> **This project is neither abandoned nor actively maintained. It simply exists.**  
> **本项目既未被遗弃，也不保证处于积极维护状态。它只是存在着。**

**No roadmap. No deadlines. No promises.**  
**没有路线图，没有截止日期，没有任何承诺。**

---

## ⚖️ Disclaimer / 免责声明

This is an independent, unofficial personal project. It is not affiliated with or endorsed by Fanqie, ByteDance, Samsung, Google, or scrcpy's maintainers. All relevant trademarks belong to their respective owners.

本项目为独立的非官方个人项目，与番茄小说、字节跳动、三星、Google 及 scrcpy 维护者不存在官方关联或背书关系。相关商标归各自权利人所有。

The software is provided **AS IS**, without promises of compatibility, performance, safety, or fitness for any particular purpose. Android debugging and experimental display-power controls carry risks; use them only if you understand what you are doing.

本软件按现状提供，不对兼容性、性能、安全性或特定用途作任何保证。无线调试和实验性的显示电源控制具有一定风险，请在理解相关功能的前提下使用。

**License:** Consult the `LICENSE` file if the repository includes one. A public repository alone does not automatically grant permission to redistribute modified copies.

**许可证：** 如仓库包含 `LICENSE` 文件，请以该文件为准。GitHub 仓库公开可见，并不自动意味着允许重新分发修改后的代码。

---

## ❤️ Final words / 最后的话

I don't want to build the next Netflix.

I don't want to revolutionize Android.

I don't even want to hold my phone.

我不打算开发下一个 Netflix。

我不打算革命性地改变 Android。

我甚至不想拿起手机。

**I just want to watch short dramas on my Mac.**  
**我只是想在 Mac 上看个短剧。**

If you find this project useful, wonderful. If not, that's fine too. I have a drama to finish.

如果这个项目恰好帮到了你，那很好。如果没有，也无所谓。我还有一部短剧没看完。

**Short Drama or Death. 🍅**  
*Developed when necessary. Maintained when convenient. Published when remembered.*  
*有需要时开发，有兴致时维护，想起来时上传。*
