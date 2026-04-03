# TrustedInstaller Token Spawner

利用 Windows 的 TrustedInstaller 服务实现权限提升，弹出一个具有特权的命令行窗口（CMD）。  
纯 PowerShell 实现，仅依赖官方 PowerShell 模块 `NtObjectManager`，无需第三方二进制文件。

[![PowerShell Gallery](https://img.shields.io/badge/PowerShell%20Gallery-NtObjectManager-blue.svg)](https://www.powershellgallery.com/packages/NtObjectManager)

## 功能特性
- 自动检查并安装 `NtObjectManager` 模块（若缺失）
- 启用 `SeDebugPrivilege` 调试权限
- 启动 TrustedInstaller 服务（若未运行）
- 复制 TrustedInstaller.exe 进程的令牌，生成新的 CMD 进程（继承 TrustedInstaller 权限）
- 纯 PowerShell 实现，不依赖外部工具

## 前置要求
- **操作系统**：Windows 7/8/10/11 或 Windows Server 2012+（需支持 `NtObjectManager` 模块）
- **运行身份**：必须**以管理员身份**运行 PowerShell
- **PowerShell 版本**：建议 PowerShell 5.1 或更高版本

## 使用步骤
1. 以管理员身份打开 PowerShell 窗口。
2. 将以下脚本保存为 `.ps1` 文件，或直接复制脚本内容到 PowerShell 中执行。
3. 执行脚本：
4. 等待脚本自动完成环境准备、启动服务、创建新窗口。新弹出的 CMD 窗口将拥有 TrustedInstaller 权限。

## 验证权限
在新弹出的 CMD 窗口中运行以下命令，检查是否存在 `TrustedInstaller` 安全组：
```cmd
whoami /groups | find "TrustedInstaller"
```
如果看到输出包含 `S-1-5-80-...` 的 SID 和 "TrustedInstaller" 字样，说明权限提升成功。

## 工作原理
1. **检查并安装 `NtObjectManager` 模块**：该模块提供了 Windows NT 对象操作的高级接口。
2. **启动 TrustedInstaller 服务**：该服务以 `NT SERVICE\TrustedInstaller` 账户运行，拥有高权限。
3. **启用调试权限**：通过 `Set-NtTokenPrivilege SeDebugPrivilege -Enable` 获取访问其他进程的权限。
4. **获取 TrustedInstaller 进程对象**：使用 `Get-NtProcess` 查找 TrustedInstaller.exe 的进程对象。
5. **以 TrustedInstaller 为父进程创建子进程**：调用 `New-Win32Process` 将新 CMD 进程的父进程设置为 TrustedInstaller.exe，从而继承其令牌权限。

## 注意事项
- **仅限合法测试**：该工具仅应用于安全研究、渗透测试授权环境或个人系统管理。滥用可能导致系统不稳定或违反法律法规。
- **系统文件风险**：TrustedInstaller 权限可以修改系统保护文件，请谨慎操作，避免误删或篡改关键文件。
- **执行策略**：脚本会自动临时放宽当前用户的执行策略（`Unrestricted`）以允许运行，但不会影响系统全局策略。
- **模块依赖**：`NtObjectManager` 模块从 PowerShell Gallery 自动安装，需确保网络畅通。

## 故障排除
| 问题 | 可能原因 | 解决方法 |
|------|---------|---------|
| `Install-Module` 失败 | NuGet 提供程序缺失 | 手动运行 `Install-PackageProvider -Name NuGet -Force` |
| 找不到 TrustedInstaller 进程 | 服务启动失败 | 手动运行 `Start-Service TrustedInstaller` 并检查事件日志 |
| 权限不足 | 未以管理员身份运行 | 关闭当前 PowerShell，右键选择“以管理员身份运行” |
| `New-Win32Process` 报错 | 令牌复制失败 | 确认 `SeDebugPrivilege` 已启用，并且 TrustedInstaller 进程仍在运行 |

## 免责声明
本脚本仅供学习和授权测试使用。作者不对因使用本脚本造成的任何直接或间接损失负责。请在遵守当地法律法规的前提下使用。

## 参考
- [NtObjectManager 官方文档](https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools/tree/main/NtObjectManager)

