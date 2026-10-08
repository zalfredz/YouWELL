param(
  [ValidateRange(1, 65535)]
  [int]$Port = 8080,

  [string]$HostName = '127.0.0.1'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -ne $flutterCommand) {
  $flutter = $flutterCommand.Source
} else {
  $localFlutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'
  if (-not (Test-Path -LiteralPath $localFlutter)) {
    throw 'Flutter belum tersedia. Install Flutter lalu pastikan perintah flutter masuk PATH.'
  }
  $flutter = $localFlutter
}

$environmentFile = if ($env:YOUWELL_ENV_FILE) {
  $env:YOUWELL_ENV_FILE
} else {
  'config/env/development.json'
}
if (-not (Test-Path -LiteralPath $environmentFile)) {
  $environmentFile = 'config/env/development.example.json'
}

Write-Host "Menyiapkan YouWell mobile preview di http://${HostName}:$Port ..."
& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $flutter run `
  -d web-server `
  --web-hostname $HostName `
  --web-port $Port `
  --dart-define=MOBILE_PREVIEW=true `
  --dart-define-from-file=$environmentFile
exit $LASTEXITCODE
