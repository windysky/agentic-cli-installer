@echo off
REM ###############################################
REM Agentic CLI Installer Deployment Script (Windows)
REM Copies install_coding_tools.bat to user's .local/bin directory
REM
REM Usage:
REM   setup.bat
REM
REM Version: 1.8.1
REM License: MIT
REM
REM Security improvements in v1.7.6:
REM - Enhanced file path sanitization
REM - Secure temporary file handling
REM ###############################################

setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "SOURCE_SCRIPT=%SCRIPT_DIR%install_coding_tools.bat"

REM ANSI color codes for Windows 10+
set "ESC="
if not defined ComSpec set "ComSpec=%SystemRoot%\\System32\\cmd.exe"
for /F %%a in ('echo prompt $E ^| "%ComSpec%"') do set "ESC=%%a"
if not defined ESC (
    set "RED="
    set "GREEN="
    set "YELLOW="
    set "BLUE="
    set "CYAN="
    set "BOLD="
    set "NC="
) else (
    set "RED=%ESC%[31m"
    set "GREEN=%ESC%[32m"
    set "YELLOW=%ESC%[33m"
    set "BLUE=%ESC%[34m"
    set "CYAN=%ESC%[36m"
    set "BOLD=%ESC%[1m"
    set "NC=%ESC%[0m"
)

echo.
echo %CYAN%%BOLD%=== Agentic CLI Installer Deployment ===%NC%
echo.

REM Get user's home directory
set "TARGET_DIR=%USERPROFILE%\.local\bin"
set "BACKUP_DIR=%USERPROFILE%\.local\bin.backup"

REM Create backup directory
if not exist "%BACKUP_DIR%" (
    echo %BLUE%[INFO]%NC% Creating backup directory: %BACKUP_DIR%
    mkdir "%BACKUP_DIR%"
)

REM Create target directory
if not exist "%TARGET_DIR%" (
    echo %BLUE%[INFO]%NC% Creating target directory: %TARGET_DIR%
    mkdir "%TARGET_DIR%"
)

REM Check if source script exists
if not exist "%SOURCE_SCRIPT%" (
    echo %RED%[ERROR]%NC% Source script not found: %SOURCE_SCRIPT%
    echo.
    echo Please run this script from the directory containing install_coding_tools.bat
    pause
    exit /b 1
)

REM Set target file path
set "TARGET_FILE=%TARGET_DIR%\install_coding_tools.bat"

REM Check if target file already exists
if exist "%TARGET_FILE%" (
    echo %YELLOW%[WARNING]%NC% Target file already exists: %TARGET_FILE%
    set /p "OVERWRITE=Overwrite existing file? [y/N]: "
    if /I not "!OVERWRITE!"=="y" (
        if /I not "!OVERWRITE!"=="yes" (
            echo %BLUE%[INFO]%NC% Installation cancelled.
            pause
            exit /b 0
        )
    )

    REM Create backup with timestamp (locale-independent)
    for /f "delims=" %%t in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')" 2^>nul') do set "TIMESTAMP=%%t"
    if not defined TIMESTAMP set "TIMESTAMP=%RANDOM%"

    set "BACKUP_FILE=%BACKUP_DIR%\install_coding_tools.bat.!TIMESTAMP!"
    echo %BLUE%[INFO]%NC% Creating backup: %BACKUP_FILE%
    copy "%TARGET_FILE%" "!BACKUP_FILE!" >nul
    if errorlevel 1 (
        echo %YELLOW%[WARNING]%NC% Failed to create backup (continuing anyway)
    ) else (
        echo %GREEN%[SUCCESS]%NC% Backup created
    )
)

REM Copy file
echo %BLUE%[INFO]%NC% Copying: %SOURCE_SCRIPT% -^> %TARGET_FILE%
copy "%SOURCE_SCRIPT%" "%TARGET_FILE%" >nul
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to copy file
    pause
    exit /b 1
)

echo %GREEN%[SUCCESS]%NC% File copied successfully

REM Verify installation
if exist "%TARGET_FILE%" (
    echo.
    echo %GREEN%%BOLD%=== Installation Summary ===%NC%
    echo.
    echo %GREEN%[SUCCESS]%NC% Deployment completed successfully!
    echo.
    echo Installed script:
    echo   %CYAN%%TARGET_FILE%%NC%
    echo.
    echo Backup location: %BACKUP_DIR%
    echo.
    echo You can now run the installer with:
    echo   %CYAN%%TARGET_FILE%%NC%
    echo.
) else (
    echo %RED%[ERROR]%NC% Installation verification failed
    pause
    exit /b 1
)

endlocal
