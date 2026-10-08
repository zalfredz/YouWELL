@echo off
setlocal
cd /d "%~dp0.."

set "FLUTTER_BIN="
for /f "delims=" %%F in ('where flutter 2^>nul') do if not defined FLUTTER_BIN set "FLUTTER_BIN=%%F"
if not defined FLUTTER_BIN if exist ".tools\flutter\bin\flutter.bat" set "FLUTTER_BIN=%CD%\.tools\flutter\bin\flutter.bat"
if not defined FLUTTER_BIN (
  echo Flutter belum tersedia. Install Flutter lalu pastikan perintah flutter masuk PATH.
  exit /b 1
)

set "PREVIEW_PORT=%~1"
if not defined PREVIEW_PORT set "PREVIEW_PORT=8080"

set "ENV_FILE=%YOUWELL_ENV_FILE%"
if not defined ENV_FILE set "ENV_FILE=config\env\development.json"
if not exist "%ENV_FILE%" set "ENV_FILE=config\env\development.example.json"

echo Menyiapkan YouWell mobile preview di http://localhost:%PREVIEW_PORT% ...
call "%FLUTTER_BIN%" pub get
if errorlevel 1 exit /b %ERRORLEVEL%

call "%FLUTTER_BIN%" run -d web-server --web-hostname 127.0.0.1 --web-port %PREVIEW_PORT% --dart-define=MOBILE_PREVIEW=true --dart-define-from-file="%ENV_FILE%"
exit /b %ERRORLEVEL%
