@echo off
@rem -------------------------------------------------------------------------------
@rem Hvigor command line tool for Windows.
@rem Requires: Node.js, Hvigor installed via DevEco Studio or HarmonyOS SDK.
@rem -------------------------------------------------------------------------------

set DIR=%~dp0
set DEVECO_HVIGORW=D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat

if not exist "%DEVECO_HVIGORW%" (
  echo ERROR: Cannot find DevEco Hvigor at '%DEVECO_HVIGORW%'.
  exit /b 1
)

set HVIGOR_DIR=%DIR%hvigor
set HVIGOR_NODE16_POLYFILLS=%HVIGOR_DIR%\node16-polyfills.js
set HVIGOR_NODE16_POLYFILLS_OPTION=%HVIGOR_NODE16_POLYFILLS:\=/%

pushd "%DIR%"
set NODE_PATH=%DIR%node_modules;%NODE_PATH%
if exist "%HVIGOR_NODE16_POLYFILLS%" (
  set NODE_OPTIONS=--require "%HVIGOR_NODE16_POLYFILLS_OPTION%" %NODE_OPTIONS%
)
call "%DEVECO_HVIGORW%" %*
set HVIGOR_EXIT_CODE=%ERRORLEVEL%
popd
exit /b %HVIGOR_EXIT_CODE%
