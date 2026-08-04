param(
  [string]$Device = ""
)

$ErrorActionPreference = "Stop"

$flutterBin = "D:\flutter_ohos_latest\bin\flutter.bat"
$projectDir = "D:\PixelPlannerBuild\mobile_app"
$devecoSdk = "D:\DevEco Studio\sdk"
$toolchains = Join-Path $devecoSdk "default\openharmony\toolchains"

$env:PATH = "D:\DevEco Studio\tools\ohpm\bin;D:\DevEco Studio\tools\hvigor\bin;$toolchains;D:\flutter_ohos_latest\bin;" + $env:PATH
$env:DEVECO_SDK_HOME = $devecoSdk
$env:HarmonyOS_SDK_HOME = $devecoSdk

if (-not (Test-Path $flutterBin)) {
  throw "Flutter OHOS SDK not found: $flutterBin"
}

if (-not (Test-Path $projectDir)) {
  throw "Build project not found: $projectDir"
}

Push-Location $projectDir
try {
  if ([string]::IsNullOrWhiteSpace($Device)) {
    & $flutterBin run
  } else {
    & $flutterBin run -d $Device
  }
} finally {
  Pop-Location
}
