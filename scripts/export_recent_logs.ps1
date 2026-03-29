param(
  [int]$Lines = 800
)

$homeDir = $env:USERPROFILE
if ([string]::IsNullOrWhiteSpace($homeDir)) {
  $homeDir = [Environment]::GetFolderPath('UserProfile')
}

$src = Join-Path $homeDir ".tg_ai_sales_desktop\logs\runtime.log"
$desktop = Join-Path $homeDir "Desktop"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$out = Join-Path $desktop "tg_ai_recent_logs_$stamp.log"

New-Item -ItemType Directory -Force -Path $desktop | Out-Null

if (-not (Test-Path $src)) {
  Write-Output "No runtime logs yet: $src"
  exit 0
}

Get-Content $src -Tail $Lines | Set-Content -Path $out -Encoding UTF8
Write-Output "Exported: $out"
