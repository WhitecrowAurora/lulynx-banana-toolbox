@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Always run from project root (the folder where this script is).
cd /d "%~dp0"

echo [INFO] Project: %CD%
echo [INFO] Preparing build environment...

REM Paths (adjust these if your local installation differs).
set "FLUTTER_BIN=C:\flutter\flutter\bin\flutter.bat"
set "ANDROID_HOME=C:\android-sdk"
set "ANDROID_SDK_ROOT=C:\android-sdk"
set "JAVA_HOME=C:\java\jdk-17.0.13+11"

REM Keep Gradle/Android user data in project directory to avoid permission issues.
set "GRADLE_USER_HOME=%CD%\.gradle-home"
set "ANDROID_USER_HOME=%CD%\.android-home"
set "GRADLE_PROJECT_CACHE=%CD%\.gradle-project-cache"
set "BUILD_LOG=%CD%\build\release_build.log"
set "APK_ARCHIVE_DIR=%CD%\build\apk_archive"

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
if not exist "%APK_ARCHIVE_DIR%" mkdir "%APK_ARCHIVE_DIR%"

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
echo [INFO] Log file: %BUILD_LOG%
echo.
echo [INFO] Stopping stale Gradle daemons...
call "%CD%\android\gradlew.bat" --stop >nul 2>&1
if exist "%GRADLE_USER_HOME%\daemon\8.3\registry.bin.lock" del /f /q "%GRADLE_USER_HOME%\daemon\8.3\registry.bin.lock" >nul 2>&1
if exist "%GRADLE_USER_HOME%\daemon\8.3\registry.bin" del /f /q "%GRADLE_USER_HOME%\daemon\8.3\registry.bin" >nul 2>&1
echo [INFO] Clearing stale Android build caches...
if exist "%CD%\build\app\intermediates" rmdir /s /q "%CD%\build\app\intermediates"
REM Keep previous APKs under build/app/outputs and archive each successful build separately.
if exist "%GRADLE_USER_HOME%\caches\transforms-3" rmdir /s /q "%GRADLE_USER_HOME%\caches\transforms-3"
echo [INFO] Starting release build...
echo.

call "%FLUTTER_BIN%" build apk --release -v > "%BUILD_LOG%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo [ERROR] Build failed with exit code %EXIT_CODE%.
  echo [ERROR] See log: %BUILD_LOG%
  echo.
  findstr /c:"NoUsableDaemonFoundException" "%BUILD_LOG%" >nul && echo [HINT] Detected Gradle daemon connection failure.
  findstr /c:"A new daemon was started but could not be connected" "%BUILD_LOG%" >nul && echo [HINT] Detected daemon IPC issue. Check firewall/security software loopback rules.
  findstr /c:"Could not create service of type OutputFilesRepository" "%BUILD_LOG%" >nul && echo [HINT] Detected Gradle cache lock issue.
  findstr /c:"buildOutputCleanup.lock" "%BUILD_LOG%" >nul && echo [HINT] Flutter SDK directory lock denied. Project cache redirection has been enabled in this script.
  echo.
  echo [INFO] Last 40 log lines:
  powershell -NoProfile -Command "Get-Content -Path '%BUILD_LOG%' -Tail 40"
  goto :fail
)

set "APK_PATH=%CD%\build\app\outputs\flutter-apk\app-release.apk"
set "APK_DIR=%CD%\build\app\outputs\flutter-apk"
set "LATEST_APK="
if exist "%APK_PATH%" set "LATEST_APK=%APK_PATH%"
if not defined LATEST_APK if exist "%APK_DIR%" (
  for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -Path '%APK_DIR%' -Filter '*.apk' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName"') do set "LATEST_APK=%%F"
)

if defined LATEST_APK (
  echo [SUCCESS] Build completed.
  for %%I in ("!LATEST_APK!") do (
    set "APK_SIZE=%%~zI"
    set "APK_TIME=%%~tI"
    set "APK_EXT=%%~xI"
  )
  for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "BUILD_STAMP=%%T"
  set "ARCHIVED_APK=%APK_ARCHIVE_DIR%\banana_toolbox_!BUILD_STAMP!!APK_EXT!"
  copy /y "!LATEST_APK!" "!ARCHIVED_APK!" >nul
  echo [INFO] APK: !LATEST_APK!
  echo [INFO] Size: !APK_SIZE! bytes
  echo [INFO] Updated: !APK_TIME!
  echo [INFO] Archived copy: !ARCHIVED_APK!
) else (
  echo [WARN] Build command returned success but no APK was found.
  echo [WARN] Check: %CD%\build\app\outputs\flutter-apk\
)

echo.
echo [INFO] Done.
goto :end

:fail
echo.
echo [INFO] Build script finished with errors.
pause
exit /b 1

:end
pause
exit /b 0
