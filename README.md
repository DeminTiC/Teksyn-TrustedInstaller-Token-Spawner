# TrustedInstaller Token Spawner

- [中文](README/README-CN.md)

Elevate privileges using the Windows TrustedInstaller service and spawn a privileged command prompt (CMD).  
Pure PowerShell implementation, relying only on the official PowerShell module `NtObjectManager` – no third-party binaries required.

[![PowerShell Gallery](https://img.shields.io/badge/PowerShell%20Gallery-NtObjectManager-blue.svg)](https://www.powershellgallery.com/packages/NtObjectManager)

## Features
- Automatically checks for and installs the `NtObjectManager` module if missing
- Enables `SeDebugPrivilege` for debugging rights
- Starts the TrustedInstaller service if not already running
- Duplicates the token of the TrustedInstaller.exe process and spawns a new CMD process (inheriting TrustedInstaller privileges)
- Pure PowerShell implementation – no external tools required

## Prerequisites
- **Operating System**: Windows 7/8/10/11 or Windows Server 2012+ (must support the `NtObjectManager` module)
- **Execution Context**: Must **run PowerShell as Administrator**
- **PowerShell Version**: PowerShell 5.1 or higher recommended

## Usage Steps
1. Open a PowerShell window as Administrator.
2. Save the script as a `.ps1` file, or copy the script content directly into the PowerShell window.
3. Execute the script:
4. The script will automatically prepare the environment, start the service, and create a new window. The newly spawned CMD window will have TrustedInstaller privileges.

## Verifying Privileges
In the newly spawned CMD window, run the following command to check for the presence of the `TrustedInstaller` security group:
```cmd
whoami /groups | find "TrustedInstaller"
```
If the output contains the SID `S-1-5-80-...` and the string "TrustedInstaller", privilege elevation succeeded.

## How It Works
1. **Check and install `NtObjectManager` module**: This module provides advanced interfaces for Windows NT object manipulation.
2. **Start the TrustedInstaller service**: This service runs under the `NT SERVICE\TrustedInstaller` account, which possesses high privileges.
3. **Enable debugging privilege**: Use `Set-NtTokenPrivilege SeDebugPrivilege -Enable` to gain access to other processes.
4. **Obtain the TrustedInstaller process object**: Use `Get-NtProcess` to locate the TrustedInstaller.exe process.
5. **Create a child process under TrustedInstaller**: Call `New-Win32Process` to set the parent process of the new CMD to TrustedInstaller.exe, thereby inheriting its token privileges.

## Important Notes
- **Legal testing only**: This tool is intended solely for security research, authorized penetration testing, or personal system administration. Misuse may lead to system instability or violation of laws/regulations.
- **System file risk**: TrustedInstaller privileges allow modification of system-protected files. Operate carefully to avoid accidental deletion or tampering with critical files.
- **Execution policy**: The script temporarily relaxes the execution policy for the current user (`Unrestricted`) to allow execution, but does not affect the system-wide policy.
- **Module dependency**: The `NtObjectManager` module is automatically installed from the PowerShell Gallery; ensure network connectivity.

## Troubleshooting
| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| `Install-Module` fails | NuGet provider missing | Manually run `Install-PackageProvider -Name NuGet -Force` |
| Cannot find TrustedInstaller process | Service failed to start | Manually run `Start-Service TrustedInstaller` and check event logs |
| Insufficient privileges | Not running as Administrator | Close current PowerShell, right-click and select "Run as Administrator" |
| `New-Win32Process` error | Token duplication failed | Verify `SeDebugPrivilege` is enabled and the TrustedInstaller process is still running |

## Disclaimer
This script is for learning and authorized testing purposes only. The author is not responsible for any direct or indirect damages caused by its use. Please use it in compliance with local laws and regulations.

## References
- [NtObjectManager Official Documentation](https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools/tree/main/NtObjectManager)
