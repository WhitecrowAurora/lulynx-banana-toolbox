@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

echo [INFO] Project: %CD%
echo [INFO] Preparing analyze environment...

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%CD%"
set "GRADLE_USER_HOME=%PROJECT_ROOT%\.gradle-home"
set "ANDROID_USER_HOME=%PROJECT_ROOT%\.android-home"
set "GRADLE_PROJECT_CACHE=%PROJECT_ROOT%\.gradle-project-cache"
set "ANALYZE_LOG=%PROJECT_ROOT%\build\flutter_analyze.log"

call :resolve_flutter
if errorlevel 1 goto :fail
call :resolve_java
if errorlevel 1 goto :fail
call :resolve_android
if errorlevel 1 goto :fail

if not exist "%GRADLE_USER_HOME%" mkdir "%GRADLE_USER_HOME%"
if not exist "%ANDROID_USER_HOME%" mkdir "%ANDROID_USER_HOME%"
if not exist "%GRADLE_PROJECT_CACHE%" mkdir "%GRADLE_PROJECT_CACHE%"
if not exist "%PROJECT_ROOT%\build" mkdir "%PROJECT_ROOT%\build"

set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"
set "GRADLE_OPTS=-Dorg.gradle.daemon=false -Dorg.gradle.vfs.watch=false -Dorg.gradle.parallel=false -Dorg.gradle.workers.max=2 -Dorg.gradle.internal.instrumentation.agent=false -Dorg.gradle.projectcachedir=%GRADLE_PROJECT_CACHE% -Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false %GRADLE_OPTS%"
set "JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true -Dfile.encoding=UTF-8 %JAVA_TOOL_OPTIONS%"

echo [INFO] FLUTTER_BIN=%FLUTTER_BIN%
echo [INFO] JAVA_HOME=%JAVA_HOME%
echo [INFO] ANDROID_HOME=%ANDROID_HOME%
echo [INFO] Log file: %ANALYZE_LOG%
echo.

if /I "%~1"=="--with-pub-get" (
  echo [INFO] Running flutter pub get...
  call "%FLUTTER_BIN%" pub get >> "%ANALYZE_LOG%" 2>&1
  if not "%ERRORLEVEL%"=="0" (
    echo [ERROR] flutter pub get failed.
    echo [ERROR] See log: %ANALYZE_LOG%
    goto :tail_and_fail
  )
)

echo [INFO] Running flutter analyze...
call "%FLUTTER_BIN%" analyze --no-fatal-infos --no-fatal-warnings -v > "%ANALYZE_LOG%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo [ERROR] Analyze failed with exit code %EXIT_CODE%.
  echo [ERROR] See log: %ANALYZE_LOG%
  goto :tail_and_fail
)

echo [SUCCESS] Analyze completed with exit code 0.
powershell -NoProfile -Command "Get-Content -Path '%ANALYZE_LOG%' -Tail 60"
goto :end

:resolve_flutter
if defined FLUTTER_BIN if exist "%FLUTTER_BIN%" exit /b 0
for /f "delims=" %%F in ('where flutter.bat 2^>nul') do (
  set "FLUTTER_BIN=%%F"
  goto :flutter_found
)
echo [ERROR] Flutter not found. Set FLUTTER_BIN or add flutter.bat to PATH.
exit /b 1
:flutter_found
exit /b 0

:resolve_java
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" exit /b 0
for /f "delims=" %%J in ('where java.exe 2^>nul') do (
  set "JAVA_EXE=%%J"
  goto :java_found
)
echo [ERROR] Java not found. Set JAVA_HOME or add java.exe to PATH.
exit /b 1
:java_found
for %%J in ("%JAVA_EXE%") do set "JAVA_HOME=%%~dpJ.."
exit /b 0

:resolve_android
if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%" (
  set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
  exit /b 0
)
if defined ANDROID_HOME if exist "%ANDROID_HOME%" exit /b 0
if exist "%LOCALAPPDATA%\Android\Sdk" (
  set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
  set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
  exit /b 0
)
echo [ERROR] Android SDK not found. Set ANDROID_HOME or ANDROID_SDK_ROOT.
exit /b 1

:tail_and_fail
echo.
powershell -NoProfile -Command "Get-Content -Path '%ANALYZE_LOG%' -Tail 120"
goto :fail

:fail
echo.
echo [INFO] Analyze script finished with errors.
pause
exit /b 1

:end
echo.
echo [INFO] Done.
pause
exit /b 0
