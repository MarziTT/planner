@echo off
@rem -------------------------------------------------------------------------------
@rem Hvigor command line tool for Windows.
@rem Requires: Node.js, Hvigor installed via DevEco Studio or HarmonyOS SDK.
@rem -------------------------------------------------------------------------------

set DIR=%~dp0
set HVIGOR_DIR=%DIR%hvigor

if not exist "%HVIGOR_DIR%" (
  echo ERROR: Cannot find Hvigor directory '%HVIGOR_DIR%'.
  echo Please install DevEco Studio and ensure the HarmonyOS SDK is configured.
  exit /b 1
)

set HVIGOR_WRAPPER_PATH=%HVIGOR_DIR%\hvigor-wrapper.js

if exist "%HVIGOR_WRAPPER_PATH%" (
  node "%HVIGOR_WRAPPER_PATH%" %*
) else (
  echo Hvigor wrapper not found at %HVIGOR_WRAPPER_PATH%
  echo Run 'hvigorw install' or check your DevEco Studio installation.
  exit /b 1
)
