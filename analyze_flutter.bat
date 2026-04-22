@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Always run from project root (the folder where this script is).
cd /d "%~dp0"

echo [INFO] Project: %CD%
echo [INFO] Preparing analyze environment...

REM Paths (adjust these if your local installation differs).
set "FLUTTER_BIN=C:\flutter\flutter\bin\flutter.bat"
set "ANDROID_HOME=C:\android-sdk"
set "ANDROID_SDK_ROOT=C:\android-sdk"
set "JAVA_HOME=C:\java\jdk-17.0.13+11"

REM Keep Gradle/Android user data in project directory to avoid permission issues.
set "GRADLE_USER_HOME=%CD%\.gradle-home"
set "ANDROID_USER_HOME=%CD%\.android-home"
set "GRADLE_PROJECT_CACHE=%CD%\.gradle-project-cache"
set "ANALYZE_LOG=%CD%\build\flutter_analyze.log"

if not exist "%FLUTTER_BIN%" (
  echo [ERROR] Flutter not found: %FLUTTER_BIN%
  goto :fail
)
if not exist "%ANDROID_HOME%" (
  echo [ERROR] Android SDK not found: %ANDROID_HOME%
  goto :fail
)
if not exist "%JAVA_HOME%\bin\java.exe" (
  echo [ERROR] Java not found: %JAVA_HOME%\bin\java.exe
  goto :fail
)

if not exist "%GRADLE_USER_HOME%" mkdir "%GRADLE_USER_HOME%"
if not exist "%ANDROID_USER_HOME%" mkdir "%ANDROID_USER_HOME%"
if not exist "%GRADLE_PROJECT_CACHE%" mkdir "%GRADLE_PROJECT_CACHE%"
if not exist "%CD%\build" mkdir "%CD%\build"

set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"
set "GRADLE_OPTS=-Dorg.gradle.daemon=false -Dorg.gradle.vfs.watch=false -Dorg.gradle.parallel=false -Dorg.gradle.workers.max=2 -Dorg.gradle.internal.instrumentation.agent=false -Dorg.gradle.projectcachedir=%GRADLE_PROJECT_CACHE% -Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false %GRADLE_OPTS%"
set "JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true -Dfile.encoding=UTF-8 %JAVA_TOOL_OPTIONS%"

echo [INFO] JAVA_HOME=%JAVA_HOME%
echo [INFO] ANDROID_HOME=%ANDROID_HOME%
echo [INFO] GRADLE_USER_HOME=%GRADLE_USER_HOME%
echo [INFO] ANDROID_USER_HOME=%ANDROID_USER_HOME%
echo [INFO] GRADLE_PROJECT_CACHE=%GRADLE_PROJECT_CACHE%
echo [INFO] GRADLE_OPTS=%GRADLE_OPTS%
echo [INFO] JAVA_TOOL_OPTIONS=%JAVA_TOOL_OPTIONS%
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
echo [INFO] Non-fatal infos/warnings are allowed; only real errors will fail.
echo.
call "%FLUTTER_BIN%" analyze --no-fatal-infos --no-fatal-warnings -v > "%ANALYZE_LOG%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo [ERROR] Analyze failed with exit code %EXIT_CODE%.
  echo [ERROR] See log: %ANALYZE_LOG%
  goto :tail_and_fail
)

echo [SUCCESS] Analyze completed with exit code 0.
echo [INFO] Last 60 log lines:
powershell -NoProfile -Command "Get-Content -Path '%ANALYZE_LOG%' -Tail 60"
echo.
echo [INFO] Done.
goto :end

:tail_and_fail
echo.
echo [INFO] Last 120 log lines:
powershell -NoProfile -Command "Get-Content -Path '%ANALYZE_LOG%' -Tail 120"
goto :fail

:fail
echo.
echo [INFO] Analyze script finished with errors.
pause
exit /b 1

:end
pause
exit /b 0
