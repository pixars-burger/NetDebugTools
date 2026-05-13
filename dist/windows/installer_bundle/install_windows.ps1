$ErrorActionPreference = 'Stop'

$appName = 'NetDebugTool'
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\$appName"
$payloadZip = Join-Path $PSScriptRoot 'net_debug_tool_windows_release.zip'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) "$appName.lnk"
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$startMenuShortcut = Join-Path $startMenuDir "$appName.lnk"
$exePath = Join-Path $installRoot 'net_debug_tool.exe'

Add-Type -AssemblyName System.Windows.Forms

if (!(Test-Path $payloadZip)) {
  throw "Missing payload: $payloadZip"
}

if (Test-Path $installRoot) {
  Remove-Item -Recurse -Force $installRoot
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
Expand-Archive -Path $payloadZip -DestinationPath $installRoot -Force

$shell = New-Object -ComObject WScript.Shell

$desktop = $shell.CreateShortcut($desktopShortcut)
$desktop.TargetPath = $exePath
$desktop.WorkingDirectory = $installRoot
$desktop.IconLocation = $exePath
$desktop.Save()

$startMenu = $shell.CreateShortcut($startMenuShortcut)
$startMenu.TargetPath = $exePath
$startMenu.WorkingDirectory = $installRoot
$startMenu.IconLocation = $exePath
$startMenu.Save()

[System.Windows.Forms.MessageBox]::Show(
  "安装完成。`n路径: $installRoot",
  'NetDebugTool',
  [System.Windows.Forms.MessageBoxButtons]::OK,
  [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null

Start-Process -FilePath $exePath
