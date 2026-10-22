$ErrorActionPreference = 'Stop'
$teacherRoot = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $teacherRoot 'player')
try {
    # pub get writes the plugin list even when symlink creation is unavailable.
    & flutter.bat pub get
    $teacherPlugins = Get-Content -LiteralPath '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    $teacherLinks = Join-Path (Get-Location) 'windows\flutter\ephemeral\.plugin_symlinks'
    New-Item -ItemType Directory -Path $teacherLinks -Force | Out-Null
    foreach ($teacherPlugin in $teacherPlugins.plugins.windows) {
        $teacherLink = Join-Path $teacherLinks $teacherPlugin.name
        if (-not (Test-Path -LiteralPath $teacherLink)) {
            New-Item -ItemType Junction -Path $teacherLink -Target $teacherPlugin.path | Out-Null
        }
    }
    & flutter.bat pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency preparation failed.' }
} finally { Pop-Location }
