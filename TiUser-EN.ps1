<#
.SYNOPSIS
    Borrow the TrustedInstaller token to spawn a SYSTEM-privileged CMD window.
.DESCRIPTION
    This script uses the NtObjectManager module to "borrow" the token of TrustedInstaller.exe,
    then spawns a new cmd.exe process with that token, giving the new window TrustedInstaller identity (essentially SYSTEM).
    Pure PowerShell implementation using an official module, no third-party tools required.
.NOTES
    Must be run as Administrator.
    Be careful – do not modify system files arbitrarily. Test in a safe environment first.
#>

#requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "[*] Checking environment and preparing for execution..." -ForegroundColor Cyan

# 1. Temporarily relax execution policy (current user only)
try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -notin @("Unrestricted", "Bypass", "RemoteSigned")) {
        Write-Host "[*] Current execution policy is $currentPolicy, temporarily changing to Unrestricted to facilitate module loading" -ForegroundColor Yellow
        Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    }
}
catch {
    Write-Warning "Unable to modify execution policy, module loading may fail: $_"
}

# 2. Check for NtObjectManager module; install if missing
if (-not (Get-Module -ListAvailable -Name NtObjectManager)) {
    Write-Host "[*] NtObjectManager module not found. Installing now..." -ForegroundColor Yellow
    try {
        Install-Module -Name NtObjectManager -Force -Scope CurrentUser -AllowClobber
    }
    catch {
        Write-Error "Module installation failed: $_"
        exit 1
    }
}
else {
    Write-Host "[+] NtObjectManager module is already installed." -ForegroundColor Green
}

# 3. Import the module
try {
    Import-Module NtObjectManager -Force
    Write-Host "[+] Module imported successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to import module: $_"
    exit 1
}

# 4. Ensure TrustedInstaller service is running
$svc = Get-Service -Name TrustedInstaller -ErrorAction SilentlyContinue
if ($svc.Status -ne 'Running') {
    Write-Host "[*] Starting TrustedInstaller service..." -ForegroundColor Yellow
    try {
        Start-Service -Name TrustedInstaller
        # Wait for it to fully start
        Wait-Process -Name TrustedInstaller -Timeout 10 -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Error "Service start failed: $_"
        exit 1
    }
}
else {
    Write-Host "[+] TrustedInstaller service is already running." -ForegroundColor Green
}

# 5. Enable SeDebugPrivilege for ourselves
try {
    Enable-NtTokenPrivilege SeDebugPrivilege
    Write-Host "[+] SeDebugPrivilege enabled – can now access other processes." -ForegroundColor Green
}
catch {
    Write-Error "Privilege issue. Are you running as Administrator? $_"
    exit 1
}

# 6. Find the TrustedInstaller.exe process object
$tiProcess = Get-NtProcess -Name TrustedInstaller.exe -First 1
if (-not $tiProcess) {
    Write-Error "Cannot find TrustedInstaller.exe process. The service may not have started correctly."
    exit 1
}
Write-Host "[+] Found TrustedInstaller process. PID is $($tiProcess.ProcessId)." -ForegroundColor Green

# 7. Borrow its token and spawn a child process (CMD window)
Write-Host "[*] Spawning a new CMD window with TrustedInstaller identity..." -ForegroundColor Cyan
try {
    $proc = New-Win32Process cmd.exe -CreationFlags NewConsole -ParentProcess $tiProcess
    Write-Host "[+] New window spawned. Process ID: $($proc.ProcessId)" -ForegroundColor Green
    Write-Host "[*] Verify privileges: In the new window, run 'whoami /groups | find \"TrustedInstaller\"'" -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to create child process: $_"
    exit 1
}

Write-Host "[*] Press any key to exit..."
Read-Host
