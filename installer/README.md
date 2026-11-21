# AFTERSELF 第一版原生安装器

`AfterselfSetup.cs` 使用 Windows 内置 .NET Framework 的 WinForms 与 ZIP 解包功能。美术复用项目已确认的安装器原型，图标从已选母版生成，不依赖网页预览、WebView2、CDN 或联网下载。

`scripts/build_first_release.py` 先从当前 Godot 源工程导出游戏，再收录游戏、图标、试玩说明、制作来源和许可证；用 .NET Framework 编译器分别编译卸载器和嵌入 ZIP 资源的单文件安装器。安装文件、免安装 ZIP 和 SHA-256 在 `build/first-installer/`。`--reuse-export` 仅适用于已经验证且没有游戏资源变更的成品。

默认安装到当前用户的 `%LOCALAPPDATA%/Programs/Afterself`，可选择其他本机空目录。桌面、开始菜单、自动启动都可以关闭。逐块写入时计算 SHA-256，进度基于实际字节；所有文件匹配内嵌清单才登记完成。安装取消、写入失败、路径冲突均回滚本次创建的文件，不覆盖已有目录。

真实安装在 HKCU 的 Windows 卸载登记项下创建 `Afterself.StartupPhase`。卸载器核对内嵌清单、安装回执和当前文件哈希，删除未修改的包内文件及仍指向本安装目录的快捷方式；修改过的文件和自行添加的文件保留。安装与卸载均不接触游戏的 AppData 存档。自身清理由隐藏的 PowerShell 等待卸载进程退出后完成，仅删除准确的卸载器文件；目录为空才删除目录，不递归清空。

QA 使用 `Setup.exe --test-install <workspace-absolute-directory>`：真实解包、真实文件校验、隔离快捷方式、取消回滚、清单篡改拒绝、真实卸载，并输出原生窗口截图。此模式不会登记 HKCU，也不会创建用户桌面快捷方式或自动启动游戏。游戏的独立 EXE 另由 `scripts/check_release.py` 检查，测试不读写玩家存档。普通发行用户双击即可，无需命令行。

Windows 10/11 提供所需 .NET Framework 运行库；其他电脑兼容性尚未验收。Windows 应用设置中的登记与卸载入口没有在 QA 模式下实际操作，不能把隔离卸载测试视为这个入口已验收。发行文件未签名。
