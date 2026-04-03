<#
.SYNOPSIS
    借 TrustedInstaller 的壳，弹个 SYSTEM 权限的 CMD 窗口。
.DESCRIPTION
    这脚本通过 NtObjectManager 模块把 TrustedInstaller.exe 的令牌“借”过来，
    然后用它生成一个新的 cmd.exe 进程，这样新窗口就有 TrustedInstaller 身份（基本等于 SYSTEM）。
    纯 PowerShell 官方模块实现，不依赖第三方工具。
.NOTES
    需要以管理员身份运行。
    玩的时候小心点，别乱动系统文件，建议先在测试环境试试。
#>

#requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "[*] 检查环境，准备执行命令..." -ForegroundColor Cyan

# 1. 临时放宽执行策略（仅当前用户）
try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -notin @("Unrestricted", "Bypass", "RemoteSigned")) {
        Write-Host "[*] 当前执行策略是 $currentPolicy，先临时改成 Unrestricted 方便加载模块" -ForegroundColor Yellow
        Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    }
}
catch {
    Write-Warning "执行策略无法修改，加载模块可能会失败：$_"
}

# 2. 检查 NtObjectManager 模块，没有就装上
if (-not (Get-Module -ListAvailable -Name NtObjectManager)) {
    Write-Host "[*] 没找到 NtObjectManager 模块，马上安装..." -ForegroundColor Yellow
    try {
        Install-Module -Name NtObjectManager -Force -Scope CurrentUser -AllowClobber
    }
    catch {
        Write-Error "安装模块失败：$_"
        exit 1
    }
}
else {
    Write-Host "[+] NtObjectManager 模块已经安装。" -ForegroundColor Green
}

# 3. 导入模块
try {
    Import-Module NtObjectManager -Force
    Write-Host "[+] 模块导入成功。" -ForegroundColor Green
}
catch {
    Write-Error "导入模块时出问题：$_"
    exit 1
}

# 4. 确保 TrustedInstaller 服务在运行
$svc = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
if ($svc.Status -ne 'Running') {
    Write-Host "[*] 启动 TrustedInstaller 服务..." -ForegroundColor Yellow
    try {
        Start-Service -Name TrustedInstaller
        # 等它完全跑起来
        Wait-Process -Name TrustedInstaller -Timeout 10 -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Error "服务启动失败：$_"
        exit 1
    }
}
else {
    Write-Host "[+] TrustedInstaller 服务已经是运行状态。" -ForegroundColor Green
}

# 5. 给自己开调试权限（SeDebugPrivilege）
try {
    Enable-NtTokenPrivilege SeDebugPrivilege
    Write-Host "[+] 已启用 SeDebugPrivilege 权限，可以转向其他进程了。" -ForegroundColor Green
}
catch {
    Write-Error "权限问题，确定是以管理员身份运行的吗？：$_"
    exit 1
}

# 6. 找到 TrustedInstaller.exe 的进程对象
$tiProcess = Get-NtProcess -Name TrustedInstaller.exe -First 1
if (-not $tiProcess) {
    Write-Error "找不到 TrustedInstaller.exe 进程，服务可能未正常启动。"
    exit 1
}
Write-Host "[+] 抓到 TrustedInstaller 进程了，PID 是 $($tiProcess.ProcessId)。" -ForegroundColor Green

# 7. 借它的令牌生一个子进程（CMD 窗口
Write-Host "[*] 正在用 TrustedInstaller 的身份开新 CMD 窗口..." -ForegroundColor Cyan
try {
    $proc = New-Win32Process cmd.exe -CreationFlags NewConsole -ParentProcess $tiProcess
    Write-Host "[+] 新窗口已经弹出来了，进程 ID：$($proc.ProcessId)" -ForegroundColor Green
    Write-Host "[*] 验证权限：在新窗口里运行 whoami /groups | find ""TrustedInstaller""" -ForegroundColor Cyan
}
catch {
    Write-Error "子进程创建失败：$_"
    exit 1
}

Write-Host "[*] 按任意键退出..."
Read-Host
