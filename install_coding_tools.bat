@echo off
setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"

REM ###############################################
REM Agentic Coders Installer v1.7.19
REM Interactive installer for AI coding CLI tools
REM Windows version (run in Anaconda Prompt or CMD)
REM
REM Recent improvements (v1.7.13-v1.7.19):
REM - oh-my-opencode plugin detection fix
REM - log_warning outputs to stderr
REM - Seccomp filter, Playwright CLI, and Playwright MCP auto-installation
REM
REM Security improvements (v1.7.12):
REM - Dynamic checksum fetching for Claude and MoAI installers
REM - SHA-256 verification for MoAI-ADK installer
REM - Sanitized PowerShell file paths
REM - Secure temporary file creation with restrictive permissions
REM ###############################################

REM Runtime flags (also configurable via env vars):
REM   --yes, -y       Non-interactive mode (auto-proceed with defaults)
REM   --debug         Enable verbose tracing and write a log file
REM   --log <path>    Write debug log to a specific file
REM   --color         Force-enable ANSI colors
REM   --no-color      Disable ANSI colors
REM   --no-prefetch   Skip latest-version prefetch (faster, fewer moving parts)
set "DEBUG=0"
set "AUTO_YES=0"
REM Default to color; if ANSI detection fails we fall back to no-color automatically.
set "NO_COLOR=0"
set "NO_PREFETCH=0"
set "LOGFILE="

if /I "%AGENTIC_DEBUG%"=="1" set "DEBUG=1"
if /I "%AGENTIC_YES%"=="1" set "AUTO_YES=1"
if /I "%AGENTIC_COLOR%"=="1" set "NO_COLOR=0"
if /I "%AGENTIC_NO_COLOR%"=="1" set "NO_COLOR=1"
if /I "%AGENTIC_NO_PREFETCH%"=="1" set "NO_PREFETCH=1"
if defined AGENTIC_LOGFILE set "LOGFILE=%AGENTIC_LOGFILE%"

call :parse_args %*
if "%DEBUG%"=="1" (
    if not defined LOGFILE set "LOGFILE=%TEMP%\agentic_installer_%RANDOM%.log"
    >"!LOGFILE!" echo [START] %DATE% %TIME% "%~f0" %*
)

REM ANSI color codes for Windows 10+
REM Use %ComSpec% (cmd.exe) explicitly since some conda envs shadow `cmd` on PATH.
set "ESC="
if not "%NO_COLOR%"=="1" (
    if not defined ComSpec set "ComSpec=%SystemRoot%\System32\cmd.exe"
    for /F %%a in ('echo prompt $E ^| "%ComSpec%"') do set "ESC=%%a"
)
REM If we failed to detect ESC, fall back to no-color to avoid printing raw "[36m" sequences.
if not defined ESC set "NO_COLOR=1"
if "%NO_COLOR%"=="1" (
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
REM Minimum versions (npm has its own versioning, separate from Node.js)
REM Node.js 22.9.0+ is required for modern npm (npm 11.x)
REM npm 10+ is sufficient for most modern tools
set "MIN_NODEJS_VERSION=22.9.0"
set "MIN_NPM_VERSION=10.0.0"
set "STATE_DIR=%USERPROFILE%\.local\share\agentic-cli-installer"
set "MOAI_STATE_FILE=%STATE_DIR%\moai-adk.path"
set "CLAUDE_INSTALL_URL=https://claude.ai/install.cmd"
set "CLAUDE_CHECKSUM_URL=https://claude.ai/checksums/install.cmd.sha256"
set "FALLBACK_CLAUDE_SHA256=f94ac8a946d6faf987e867788d69a974bdb4792e89620a6de721d24ea1b76466"
set "MOAI_INSTALL_URL=https://raw.githubusercontent.com/modu-ai/moai-adk/main/install.ps1"
set "MOAI_CHECKSUM_URL=https://api.github.com/repos/modu-ai/moai-adk/contents/install.ps1.sha256?ref=main"

REM Tool list: name|manager|package|description
set TOOLS_COUNT=7
set "TOOL_1=moai-adk|native|moai-adk|MoAI Agent Development Kit"
set "TOOL_2=claude-code|native|claude-code|Claude Code CLI"
set "TOOL_3=@openai/codex|npm|@openai/codex|OpenAI Codex CLI"
set "TOOL_4=@google/gemini-cli|npm|@google/gemini-cli|Google Gemini CLI"
set "TOOL_5=@google/jules|npm|@google/jules|Google Jules CLI"
set "TOOL_6=opencode-ai|npm|opencode-ai|OpenCode AI CLI"
set "TOOL_7=oh-my-opencode|addon|oh-my-opencode|OpenCode - oh-my-opencode"

REM Action states: 0=skip, 1=install, 2=remove
set ACTION_SKIP=0
set ACTION_INSTALL=1
set ACTION_REMOVE=2
set "OHMY_FLAGS=--no-tui --claude=no --openai=no --gemini=no --copilot=no --opencode-zen=no --zai-coding-plan=no"

REM Initialize tool data arrays
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    set "SEL_%%i=0"
    set "ACT_%%i=0"
    set "UPDATE_ONLY_%%i=0"
)

REM Cached version data to avoid repeated slow calls
set "UV_TOOL_LIST_READY=0"
set "UV_TOOL_LIST_CACHE="
set "NPM_LIST_JSON_READY=0"
set "NPM_LIST_JSON_CACHE="
set "NPM_ROOT_READY=0"
set "NPM_ROOT_CACHE="
set "LATEST_CACHE_DIR="
set "INPUT_FAIL_COUNT=0"
set "STDIN_REDIRECTED=0"
for /f "delims=" %%a in ('powershell -NoProfile -Command "[Console]::IsInputRedirected" 2^>nul') do set "STDIN_REDIRECTED=%%a"
if /I "%STDIN_REDIRECTED%"=="True" set "STDIN_REDIRECTED=1"
if /I "%STDIN_REDIRECTED%"=="False" set "STDIN_REDIRECTED=0"

REM GitHub API rate limit tracking
set "GITHUB_RATE_LIMIT_REMAINING=60"
set "GITHUB_RATE_LIMIT_RESET=0"

REM Load tool definitions
set "NAME_1=MoAI Agent Development Kit"
set "MGR_1=native"
set "PKG_1=moai-adk"
set "DESC_1=MoAI Agent Development Kit"
set "BIN_1=moai"
set "VERARG_1=version"

set "NAME_2=Claude Code CLI"
set "MGR_2=native"
set "PKG_2=claude-code"
set "DESC_2=Claude Code CLI"
set "BIN_2=claude"
set "VERARG_2=--version"

set "NAME_3=OpenAI Codex CLI"
set "MGR_3=npm"
set "PKG_3=@openai/codex"
set "DESC_3=OpenAI Codex CLI"
set "BIN_3=codex"
set "VERARG_3=--version"

set "NAME_4=Google Gemini CLI"
set "MGR_4=npm"
set "PKG_4=@google/gemini-cli"
set "DESC_4=Google Gemini CLI"
set "BIN_4=gemini"
set "VERARG_4=--version"

set "NAME_5=Google Jules CLI"
set "MGR_5=npm"
set "PKG_5=@google/jules"
set "DESC_5=Google Jules CLI"
set "BIN_5=jules"
set "VERARG_5=version"

set "NAME_6=OpenCode AI CLI"
set "MGR_6=npm"
set "PKG_6=opencode-ai"
set "DESC_6=OpenCode AI CLI"
set "BIN_6=opencode"
set "VERARG_6=--version"

set "NAME_7=OpenCode - oh-my-opencode"
set "MGR_7=addon"
set "PKG_7=oh-my-opencode"
set "DESC_7=OpenCode - oh-my-opencode"
set "BIN_7="
set "VERARG_7="

REM ###############################################
REM MAIN EXECUTION
REM ###############################################

if "%DEBUG%"=="1" call :debug_env

call :dbg %BLUE%[STEP]%NC% check_conda_environment
call :check_conda_environment
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    call :die "check_conda_environment" "%RC%"
    exit /b %RC%
)

call :dbg %BLUE%[STEP]%NC% check_curl
call :check_curl
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    call :die "check_curl" "%RC%"
    exit /b %RC%
)

call :dbg %BLUE%[STEP]%NC% initialize_tools
call :initialize_tools
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    call :die "initialize_tools" "%RC%"
    exit /b %RC%
)

REM Non-interactive mode: skip menu and proceed with defaults
if "%AUTO_YES%"=="1" (
    echo %BLUE%[INFO]%NC% Non-interactive mode: using default selections
    call :check_selected
    if errorlevel 1 (
        echo %YELLOW%[WARNING]%NC% No tools selected by default ^(all tools up-to-date^). Nothing to do.
        exit /b 0
    )
    call :show_selected_tools
    echo.
    echo %GREEN%[SUCCESS]%NC% Auto-proceeding with selected tools...
    goto confirm_actions
)

:menu_loop
call :render_menu

echo.
echo %BOLD%Enter selection:%NC%
REM Robust input handling:
REM - If user presses Enter: treat it as "proceed".
REM - If STDIN is closed/EOF and redirected (common when piped input runs out): exit safely.
set "input="
set /p "input=> "
set "INPUT_RC=%errorlevel%"
if "%INPUT_RC%"=="1" (
    if "%STDIN_REDIRECTED%"=="1" (
        echo %YELLOW%[WARNING]%NC% Input stream closed. Exiting without changes.
        exit /b 0
    )
)

REM Strip leading/trailing spaces and optional surrounding quotes
if defined input (
    for /f "tokens=* delims= " %%a in ("!input!") do set "input=%%a"
    if "!input:~0,1!"=="\"" if not "!input:~1!"=="" if "!input:~-1!"=="\"" set "input=!input:~1,-1!"
    if "!input!"=="""" set "input="
)

REM Use the first token so trailing spaces don't break quit detection
set "first="
for /f "tokens=1" %%a in ("!input!") do set "first=%%a"
REM Handle empty/whitespace-only input (treat same as 'P' for proceed)
if not defined first (
    set "input=P"
    set "first=P"
)

REM Check for quit
if /I "!first!"=="Q" (
    echo %BLUE%[INFO]%NC% Exiting without changes.
    exit /b 0
)

REM Allow explicit proceed token (helps terminals that can't send an empty line).
if /I "!first!"=="P" (
    call :check_selected
    if errorlevel 1 goto menu_loop
    goto confirm_actions
)

REM Parse selection
call :parse_selection "%input%"
goto menu_loop

:confirm_actions
call :display_action_summary
call :confirm_removals
if errorlevel 1 exit /b 0

call :selection_requires_npm
set "RC=%errorlevel%"
if "%RC%"=="0" (
    call :dbg %BLUE%[STEP]%NC% ensure_npm_prerequisite
    call :ensure_npm_prerequisite
    set "RC=%errorlevel%"
    if not "%RC%"=="0" (
        call :die "ensure_npm_prerequisite" "%RC%"
        exit /b %RC%
    )
)

call :selection_requires_uv
set "RC=%errorlevel%"
if "%RC%"=="0" (
    call :dbg %BLUE%[STEP]%NC% ensure_uv_prerequisite
    call :ensure_uv_prerequisite
    set "RC=%errorlevel%"
    if not "%RC%"=="0" (
        call :die "ensure_uv_prerequisite" "%RC%"
        exit /b %RC%
    )
)

call :dbg_step "check_dependencies"
call :check_dependencies
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    call :die "check_dependencies" "%RC%"
    exit /b %RC%
)

call :run_installation_steps
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    echo.
    echo %RED%%BOLD%Installation completed with errors.%NC%
    if "%DEBUG%"=="1" echo %YELLOW%See log:%NC% %CYAN%"%LOGFILE%"%NC%
    exit /b %RC%
)
echo.
echo %GREEN%%BOLD%Installation complete!%NC%
echo.
exit /b 0

REM ###############################################
REM UTILITY FUNCTIONS
REM ###############################################

:parse_args
if "%~1"=="" exit /b 0
if /I "%~1"=="--yes" (
    set "AUTO_YES=1"
    shift
    goto parse_args
)
if /I "%~1"=="-y" (
    set "AUTO_YES=1"
    shift
    goto parse_args
)
if /I "%~1"=="--debug" (
    set "DEBUG=1"
    shift
    goto parse_args
)
if /I "%~1"=="--color" (
    set "NO_COLOR=0"
    shift
    goto parse_args
)
if /I "%~1"=="--no-color" (
    set "NO_COLOR=1"
    shift
    goto parse_args
)
if /I "%~1"=="--no-prefetch" (
    set "NO_PREFETCH=1"
    shift
    goto parse_args
)
if /I "%~1"=="--log" (
    if not "%~2"=="" set "LOGFILE=%~2"
    shift
    shift
    goto parse_args
)
shift
goto parse_args

:log
if "%~1"=="" (
    echo.
    if defined LOGFILE >>"%LOGFILE%" echo.
    exit /b 0
)
set "msg=%*"
echo !msg!
if defined LOGFILE >>"%LOGFILE%" echo [%DATE% %TIME%] !msg!
exit /b 0

:dbg
if "%DEBUG%"=="1" call :log %*
exit /b 0

:dbg_step
if "%DEBUG%"=="1" call :log %BLUE%[STEP]%NC% %~1
exit /b 0

:die
set "step=%~1"
set "rc=%~2"
call :log %RED%[ERROR]%NC% Failed in %step% ^(errorlevel=%rc%^).
if "%DEBUG%"=="1" call :log %YELLOW%Log:%NC% %CYAN%"%LOGFILE%"%NC%
exit /b %rc%

:debug_env
call :log %CYAN%%BOLD%Debug mode enabled%NC%
call :log   Script: %CYAN%"%~f0"%NC%
call :log   CWD:    %CYAN%"%CD%"%NC%
call :log   ComSpec:%CYAN% "%ComSpec%"%NC%
call :log   CONDA_DEFAULT_ENV=%CYAN%!CONDA_DEFAULT_ENV!%NC%
call :log   DEBUG=%CYAN%!DEBUG!%NC% NO_COLOR=%CYAN%!NO_COLOR!%NC% NO_PREFETCH=%CYAN%!NO_PREFETCH!%NC%
call :resolve_conda_npm
call :log   CONDA_NPM=%CYAN%!CONDA_NPM!%NC%
call :log
call :log %BLUE%[INFO]%NC% Executable resolution (where):
where cmd 1>>"%LOGFILE%" 2>&1
where cmd
where uv 1>>"%LOGFILE%" 2>&1
where uv
where curl 1>>"%LOGFILE%" 2>&1
where curl
where powershell 1>>"%LOGFILE%" 2>&1
where powershell
call :log
exit /b 0

:resolve_conda_npm
set "CONDA_NPM="
set "CONDA_NODE="
set "CONDA_BASE="
if defined CONDA_PREFIX set "CONDA_BASE=!CONDA_PREFIX!"
if not defined CONDA_BASE if defined CONDA_DEFAULT_ENV (
    for /f "delims=" %%p in ('conda info --base 2^>nul') do set "CONDA_ROOT=%%p"
    if defined CONDA_ROOT set "CONDA_BASE=!CONDA_ROOT!\envs\!CONDA_DEFAULT_ENV!"
)

if defined CONDA_BASE (
    call :probe_conda_npm "!CONDA_BASE!"
)

if defined CONDA_NPM exit /b 0

REM Fallback: if npm is on PATH, only accept it if it's inside CONDA_BASE
if defined CONDA_BASE (
    set "BASE_LEN="
    for /f "delims=" %%l in ('powershell -NoProfile -Command "('%CONDA_BASE%').Length" 2^>nul') do set "BASE_LEN=%%l"
    if defined BASE_LEN (
        for /f "delims=" %%p in ('where npm 2^>nul') do (
            set "cand=%%p"
            if /I "!cand:~0,%BASE_LEN%!"=="%CONDA_BASE%" (
                set "CONDA_NPM=%%p"
                exit /b 0
            )
        )
    )
)
exit /b 1

:probe_conda_npm
set "base=%~1"
if "%base%"=="" exit /b 1
if exist "%base%\Scripts\npm.cmd" set "CONDA_NPM=%base%\Scripts\npm.cmd"
if not defined CONDA_NPM if exist "%base%\Scripts\npm.exe" set "CONDA_NPM=%base%\Scripts\npm.exe"
if not defined CONDA_NPM if exist "%base%\Library\bin\npm.cmd" set "CONDA_NPM=%base%\Library\bin\npm.cmd"
if not defined CONDA_NPM if exist "%base%\Library\bin\npm.exe" set "CONDA_NPM=%base%\Library\bin\npm.exe"

if exist "%base%\Scripts\node.exe" set "CONDA_NODE=%base%\Scripts\node.exe"
if not defined CONDA_NODE if exist "%base%\Library\bin\node.exe" set "CONDA_NODE=%base%\Library\bin\node.exe"

if defined CONDA_NPM exit /b 0
exit /b 1

:ensure_npm_prerequisite
call :dbg %BLUE%[DEBUG]%NC% enter ensure_npm_prerequisite
set "has_npm_tool=0"
set "NPM_VERSION="
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "MGR_CHECK=%%MGR_%%i%%"
    if /I "!MGR_CHECK!"=="npm" set "has_npm_tool=1"
    if /I "!MGR_CHECK!"=="addon" set "has_npm_tool=1"
)

call :dbg %BLUE%[DEBUG]%NC% has_npm_tool=!has_npm_tool!
if "!has_npm_tool!"=="0" exit /b 0

if not defined CONDA_DEFAULT_ENV if not defined CONDA_PREFIX (
    echo %RED%[ERROR]%NC% Conda environment is not active. npm tools require conda npm.
    echo Activate a conda environment and re-run this installer.
    exit /b 1
)

where conda >nul 2>nul
if errorlevel 1 (
    echo %RED%[ERROR]%NC% conda not found. npm tools require conda-provided Node.js/npm.
    exit /b 1
)

call :resolve_conda_npm
if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% npm is not installed in the active conda environment but required for npm-managed tools.
    echo Installing Node.js + npm via conda...
    call conda install -y -c conda-forge "nodejs>=%MIN_NODEJS_VERSION%"
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% Failed to install Node.js/npm via conda.
        exit /b 1
    )
)

call :resolve_conda_npm
if errorlevel 1 (
    echo %RED%[ERROR]%NC% npm installation via conda completed but npm is still not available.
    exit /b 1
)

REM Ensure Node.js meets minimum version inside the conda environment
set "NODE_VERSION="
if defined CONDA_NODE (
    for /f "delims=" %%v in ('"%CONDA_NODE%" --version 2^>nul') do (
        if not "%%v"=="" set "NODE_VERSION=%%v"
    )
)
if not defined NODE_VERSION (
    for /f "delims=" %%v in ('node --version 2^>nul') do (
        if not "%%v"=="" set "NODE_VERSION=%%v"
    )
)
if defined NODE_VERSION (
    if /I "!NODE_VERSION:~0,1!"=="v" set "NODE_VERSION=!NODE_VERSION:~1!"
)
set "NEED_NODE_UPDATE=0"
if not defined NODE_VERSION (
    set "NEED_NODE_UPDATE=1"
) else (
    powershell -NoProfile -Command "try { if ([version]'!NODE_VERSION!' -ge [version]'%MIN_NODEJS_VERSION%') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
    if errorlevel 1 set "NEED_NODE_UPDATE=1"
)
if "!NEED_NODE_UPDATE!"=="1" (
    echo %YELLOW%[WARNING]%NC% Node.js !NODE_VERSION! is below required %MIN_NODEJS_VERSION%. Updating via conda...
    call conda install -y -c conda-forge "nodejs>=%MIN_NODEJS_VERSION%"
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% Failed to install/update Node.js via conda.
        exit /b 1
    )
    call :resolve_conda_npm
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% npm/Node path not found after Node.js update.
        exit /b 1
    )
    set "NODE_VERSION="
    if defined CONDA_NODE (
        for /f "delims=" %%v in ('"%CONDA_NODE%" --version 2^>nul') do (
            if not "%%v"=="" set "NODE_VERSION=%%v"
        )
    )
    if defined NODE_VERSION (
        if /I "!NODE_VERSION:~0,1!"=="v" set "NODE_VERSION=!NODE_VERSION:~1!"
    )
    if not defined NODE_VERSION (
        echo %RED%[ERROR]%NC% Node.js update completed but version is unavailable.
        exit /b 1
    )
    powershell -NoProfile -Command "try { if ([version]'!NODE_VERSION!' -ge [version]'%MIN_NODEJS_VERSION%') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% Node.js version remains below %MIN_NODEJS_VERSION% (^!NODE_VERSION!^)
        exit /b 1
    )
    echo %GREEN%[SUCCESS]%NC% Node.js ready (^!NODE_VERSION!^) in conda env
)

call :dbg %BLUE%[DEBUG]%NC% querying conda npm --version
for /f "delims=" %%v in ('"!CONDA_NPM!" --version 2^>nul') do (
    if not "%%v"=="" set "NPM_VERSION=%%v"
)

call :dbg %BLUE%[DEBUG]%NC% NPM_VERSION=!NPM_VERSION!
if not defined NPM_VERSION (
    echo %RED%[ERROR]%NC% Unable to determine npm version from conda npm.
    exit /b 1
)

powershell -NoProfile -Command "try { if ([version]'%NPM_VERSION%' -ge [version]'%MIN_NPM_VERSION%') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% npm version %NPM_VERSION% is below required %MIN_NPM_VERSION%.
    echo Updating npm via conda npm...
    call "!CONDA_NPM!" install -g npm@latest
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% npm update failed. Please run: npm install -g npm@latest (within the conda env)
        exit /b 1
    )
    for /f "delims=" %%v in ('"!CONDA_NPM!" --version 2^>nul') do (
        if not "%%v"=="" set "NPM_VERSION=%%v"
    )
    powershell -NoProfile -Command "try { if ([version]'%NPM_VERSION%' -ge [version]'%MIN_NPM_VERSION%') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% npm update completed but version is still insufficient: !NPM_VERSION!
        exit /b 1
    )
    echo %GREEN%[SUCCESS]%NC% npm updated to !NPM_VERSION!
    exit /b 0
) else (
    echo %BLUE%[INFO]%NC% npm version %NPM_VERSION% detected. Minimum required: %MIN_NPM_VERSION%.
)
exit /b 0

:ensure_uv_prerequisite
call :dbg %BLUE%[DEBUG]%NC% enter ensure_uv_prerequisite
call :dbg %BLUE%[DEBUG]%NC% checking `where uv`
where uv >nul 2>nul
if errorlevel 1 (
    echo %RED%[ERROR]%NC% uv is not installed but required for uv-managed tools.
    echo Install uv with conda:
    echo   %CYAN%conda install -c conda-forge uv%NC%
    exit /b 1
)
exit /b 0

:check_curl
where curl >nul 2>nul
if errorlevel 1 (
    echo %RED%[ERROR]%NC% curl is required but not installed.
    echo Install curl or use Windows 10+
    exit /b 1
)
exit /b 0

:check_system_npm
REM System npm is not used on Windows; conda npm is required.
echo %BLUE%[INFO]%NC% Skipping system npm check on Windows ^(conda npm only^).
exit /b 0

:verify_file_sha256
set "verify_file=%~1"
set "verify_expected=%~2"
set "verify_actual="
set "AGENTIC_VERIFY_FILE=%verify_file%"
REM Sanitize file path for PowerShell by removing special characters that could cause injection
set "AGENTIC_VERIFY_FILE=%AGENTIC_VERIFY_FILE:"=%"
for /f "delims=" %%h in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $path = $env:AGENTIC_VERIFY_FILE; if (Test-Path -LiteralPath $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLower() }" 2^>nul') do set "verify_actual=%%h"
set "AGENTIC_VERIFY_FILE="
if not defined verify_actual (
    echo %RED%[ERROR]%NC% Unable to compute installer SHA-256 hash
    exit /b 1
)
if /I not "%verify_actual%"=="%verify_expected%" (
    echo %RED%[ERROR]%NC% Installer checksum mismatch.
    echo Expected: %verify_expected%
    echo Actual:   %verify_actual%
    exit /b 1
)
exit /b 0

:record_moai_install_path
set "MOAI_BIN_PATH="
for /f "delims=" %%p in ('where moai 2^>nul') do (
    if not defined MOAI_BIN_PATH set "MOAI_BIN_PATH=%%p"
)
if not defined MOAI_BIN_PATH exit /b 1
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>nul
if not exist "%STATE_DIR%" exit /b 1
>"%MOAI_STATE_FILE%" echo %MOAI_BIN_PATH%
if errorlevel 1 exit /b 1
exit /b 0

:fetch_claude_checksum
set "tmpfile=%TEMP%\claude_checksum_%RANDOM%.tmp"
curl -fsSL "%CLAUDE_CHECKSUM_URL%" -o "%tmpfile%" 2>nul
if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% Failed to fetch Claude checksum, using fallback
    set "CLAUDE_SHA256=%FALLBACK_CLAUDE_SHA256%"
    del "%tmpfile%" >nul 2>nul
    exit /b 0
)
REM Extract checksum (first 64 hex characters)
for /f "delims=" %%c in ('powershell -NoProfile -Command "$content = Get-Content -LiteralPath '%tmpfile%' -Raw; if ($content -match '^[a-f0-9]{64}') { $matches[0] }" 2^>nul') do set "CLAUDE_SHA256=%%c"
del "%tmpfile%" >nul 2>nul
if not defined CLAUDE_SHA256 (
    set "CLAUDE_SHA256=%FALLBACK_CLAUDE_SHA256%"
    echo %YELLOW%[WARNING]%NC% Failed to parse Claude checksum, using fallback
)
exit /b 0

:download_claude_installer
set "outfile=%~1"
REM Download Claude Code installer from official Anthropic source over HTTPS
curl -fsSL "%CLAUDE_INSTALL_URL%" -o "%outfile%"
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to download Claude Code installer
    exit /b 1
)
REM Fetch and verify checksum dynamically
call :fetch_claude_checksum
call :verify_file_sha256 "%outfile%" "%CLAUDE_SHA256%"
if errorlevel 1 exit /b 1
exit /b 0

:fetch_moai_checksum
set "tmpfile=%TEMP%\moai_checksum_%RANDOM%.tmp"
curl -fsSL "%MOAI_CHECKSUM_URL%" -o "%tmpfile%" 2>nul
if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% Failed to fetch MoAI checksum from GitHub API
    set "MOAI_SHA256="
    del "%tmpfile%" >nul 2>nul
    exit /b 0
)
REM Parse GitHub API response to extract base64-encoded content, then decode it
for /f "delims=" %%c in ('powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $json = Get-Content -LiteralPath '%tmpfile%' -Raw | ConvertFrom-Json; if ($json.content) { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($json.content)) }" 2^>nul') do set "checksum_raw=%%c"
del "%tmpfile%" >nul 2>nul
REM Extract first 64 hex characters (SHA-256 hash)
for /f "delims=" %%h in ('powershell -NoProfile -Command "$content = '%checksum_raw%'; if ($content -match '^[a-f0-9]{64}') { $matches[0] }" 2^>nul') do set "MOAI_SHA256=%%h"
if not defined MOAI_SHA256 (
    echo %YELLOW%[WARNING]%NC% Failed to parse MoAI checksum
    set "MOAI_SHA256="
)
exit /b 0

:run_moai_installer
REM Download and run MoAI-ADK installer from upstream main branch
set "moai_tmp=%TEMP%\moai_install_%RANDOM%.ps1"
curl -fsSL "%MOAI_INSTALL_URL%" -o "%moai_tmp%"
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to download MoAI-ADK installer
    exit /b 1
)
REM Secure the temporary file
attrib +R "%moai_tmp%" >nul 2>nul
REM Fetch and verify checksum if available
call :fetch_moai_checksum
if defined MOAI_SHA256 (
    call :verify_file_sha256 "%moai_tmp%" "%MOAI_SHA256%"
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% MoAI-ADK installer checksum verification failed
        del "%moai_tmp%" >nul 2>nul
        exit /b 1
    )
    echo %GREEN%[SUCCESS]%NC% MoAI-ADK installer checksum verified
) else (
    echo %YELLOW%[WARNING]%NC% MoAI-ADK installer checksum not available, proceeding without verification
)
set "AGENTIC_MOAI_INSTALLER=%moai_tmp%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; & $env:AGENTIC_MOAI_INSTALLER"
set "AGENTIC_MOAI_INSTALLER="
set "RC=%errorlevel%"
attrib -R "%moai_tmp%" >nul 2>nul
del "%moai_tmp%" >nul 2>nul
if not "%RC%"=="0" (
    echo %RED%[ERROR]%NC% Failed to run MoAI-ADK installer
    exit /b %RC%
)
exit /b 0

:check_conda_environment
REM Check if conda environment is active
if defined CONDA_DEFAULT_ENV (
    REM Conda environment is active
    if /I "%CONDA_DEFAULT_ENV%"=="base" (
        echo %RED%[ERROR]%NC% Cannot install tools in the base conda environment.
        echo.
        echo %YELLOW%For safety and to avoid conflicts, please create and use a non-base conda environment.%NC%
        echo.
        echo To create a new environment:
        echo   %CYAN%conda create -n agentic-tools python=3.11%NC%
        echo   %CYAN%conda activate agentic-tools%NC%
        echo.
        echo Then run this script again.
        echo.
        exit /b 1
    ) else (
        set "ENV_NAME=%CONDA_DEFAULT_ENV%"
        echo %BLUE%[INFO]%NC% Using conda environment: %CYAN%!ENV_NAME!%NC%
    )
)
exit /b 0

:check_selected
set count=0
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "sel=%%ACT_%%i%%"
    call set "sel=%%sel%%"
    if "!sel!" neq "0" set /a count+=1
)
if !count!==0 (
    echo %YELLOW%[WARNING]%NC% No tools selected. Please select at least one tool or press Q to quit.
    pause
    exit /b 1
)
if !count! EQU 1 (
    echo %GREEN%[SUCCESS]%NC% Starting installation/upgrade of 1 tool...
) else (
    echo %GREEN%[SUCCESS]%NC% Starting installation/upgrade of !count! tools...
)
exit /b 0

:selection_requires_npm
set "needs_npm=0"
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    if not "!act!"=="0" (
        call set "mgr=%%MGR_%%i%%"
        call set "mgr=%%mgr%%"
        if /I "!mgr!"=="npm" set "needs_npm=1"
        if /I "!mgr!"=="npm-self" set "needs_npm=1"
        if /I "!mgr!"=="addon" set "needs_npm=1"
    )
)
if "%needs_npm%"=="1" exit /b 0
exit /b 1

:selection_requires_uv
set "needs_uv=0"
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    if not "!act!"=="0" (
        call set "mgr=%%MGR_%%i%%"
        call set "mgr=%%mgr%%"
        if /I "!mgr!"=="uv" set "needs_uv=1"
    )
)
if "%needs_uv%"=="1" exit /b 0
exit /b 1

:print_sep
REM ASCII separator to avoid mojibake in different Windows code pages.
set "sep=--------------------------------------------------------------------------------"
echo %CYAN%!sep!%NC%
exit /b 0

:print_banner_sep
REM Slightly heavier separator for section banners (ASCII-only).
set "sep================================================================================="
echo %CYAN%!sep!%NC%
exit /b 0

:pad_right
set "text=%~1"
set "width=%~2"
set "outvar=%~3"
set "spaces=                                                                                "
set "text=!text!!spaces!"
set "%outvar%=!text:~0,%width%!"
exit /b 0

:get_semver_from_command
set "bin=%~1"
set "verarg=%~2"
set "outvar=%~3"
set "%outvar%="
if "%bin%"=="" exit /b 0
if "%verarg%"=="" set "verarg=--version"
call :dbg %BLUE%[DEBUG]%NC% get_semver_from_command bin="%bin%" verarg="%verarg%"
set "semver="
REM Run under cmd.exe (so .cmd shims work) and extract the first x.y.z from combined stdout/stderr.
REM Inline PowerShell via encoded command to avoid quoting issues or extra files.
REM The encoded PowerShell script extracts semantic version numbers (x.y.z format) from command output.
REM Decoded: It uses regex pattern '(?<!\d)(\d+\.\d+\.\d+(?:(?:-\w+)+)?)?' to find version strings.
REM Encoding is necessary because cmd.exe has complex parsing rules for special characters in code.
set "SEMVER_B64=JAB0AGUAeAB0ACAAPQAgAFsAQwBvAG4AcwBvAGwAZQBdADoAOgBJAG4ALgBSAGUAYQBkAFQAbwBFAG4AZAAoACkAOwAKAGkAZgAgACgALQBuAG8AdAAgACQAdABlAHgAdAApACAAewAgAHIAZQB0AHUAcgBuACAAfQAKACQAcABhAHQAdABlAHIAbgBzACAAPQAgAEAAKAAnACgAPwA8ACEAXABkACkAKABcAGQAKwBcAC4AXABkACsAXAAuAFwAZAArACgAPwA6AC0AWwAwAC0AOQBBAC0AWgBhAC0AegBcAC4ALQBdACsAKQA/ACkAJwAsACcAKAA/ADwAIQBcAGQAKQAoAFwAZAArAFwALgBcAGQAKwAoAD8AOgAtAFsAMAAtADkAQQAtAFoAYQAtAHoAXAAuAC0AXQArACkAPwApACcAKQAKAGYAbwByAGUAYQBjAGgAIAAoACQAcABhAHQAIABpAG4AIAAkAHAAYQB0AHQAZQByAG4AcwApACAAewAKACAAIAAkAG0AIAA9ACAAWwByAGUAZwBlAHgAXQA6ADoATQBhAHQAYwBoACgAJAB0AGUAeAB0ACwAIAAkAHAAYQB0ACkACgAgACAAaQBmACAAKAAkAG0ALgBTAHUAYwBjAGUAcwBzACkAIAB7ACAAVwByAGkAdABlAC0ATwB1AHQAcAB1AHQAIAAkAG0ALgBHAHIAbwB1AHAAcwBbADEAXQAuAFYAYQBsAHUAZQA7ACAAYgByAGUAYQBrACAAfQAKAH0ACgA="
for /f "delims=" %%v in ('%ComSpec% /d /c ""%bin%" %verarg% 2^>^&1" ^| powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand "%SEMVER_B64%"') do (
    if not "%%v"=="" if not defined semver set "semver=%%v"
)
if "%DEBUG%"=="1" if not defined semver (
    call :dbg %YELLOW%[DEBUG]%NC% get_semver_from_command raw output:
    %ComSpec% /d /c ""%bin%" %verarg% 2^>^&1"
)
if defined semver set "%outvar%=%semver%"
if not defined %outvar% call :dbg %YELLOW%[DEBUG]%NC% get_semver_from_command no semver extracted
exit /b 0

REM ###############################################
REM VERSION QUERY FUNCTIONS
REM ###############################################

:get_installed_uv_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
where uv >nul 2>nul
if errorlevel 1 exit /b 0

if "%UV_TOOL_LIST_READY%"=="0" (
    if not defined UV_TOOL_LIST_CACHE set "UV_TOOL_LIST_CACHE=%TEMP%\uv_tool_list_%RANDOM%.tmp"
    uv tool list >"!UV_TOOL_LIST_CACHE!" 2>nul
    set "UV_TOOL_LIST_READY=1"
)

REM Method 1: Exact match with word boundary
for /f "tokens=*" %%v in ('findstr /R /C:"%pkg% " "%UV_TOOL_LIST_CACHE%" 2^>nul') do (
    for /f "tokens=2" %%a in ("%%v") do (
        if not defined %outvar% set "%outvar%=%%a"
    )
)

REM Method 2: Substring match if method 1 failed
if not defined %outvar% (
    for /f "tokens=*" %%v in ('findstr /I "%pkg%" "%UV_TOOL_LIST_CACHE%" 2^>nul') do (
        for /f "tokens=2" %%a in ("%%v") do (
            if not defined %outvar% set "%outvar%=%%a"
        )
    )
)

REM Method 3: Simple grep as last resort
if not defined %outvar% (
    for /f "usebackq tokens=*" %%v in ("%UV_TOOL_LIST_CACHE%") do (
        for /f "tokens=1,2" %%a in ("%%v") do (
            if /I "%%a"=="%pkg%" if not defined %outvar% set "%outvar%=%%b"
        )
    )
)

REM Remove 'v' prefix
if defined %outvar% (
    set "val=!%outvar%!"
    if "!val:~0,1!"=="v" set "%outvar%=!val:~1!"
)
exit /b 0

:get_installed_npm_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
call :resolve_conda_npm
if errorlevel 1 exit /b 0

if "%NPM_LIST_JSON_READY%"=="0" (
    if not defined NPM_LIST_JSON_CACHE set "NPM_LIST_JSON_CACHE=%TEMP%\npm_list_%RANDOM%.json"
    "!CONDA_NPM!" list -g --depth=0 --json >"!NPM_LIST_JSON_CACHE!" 2>nul
    set "NPM_LIST_JSON_READY=1"
)

REM SAFE: Use PowerShell with parameters instead of variable interpolation
REM Also validate JSON file size before processing (max 10MB)
set "MAX_JSON_SIZE=10485760"
for /f "delims=" %%f in ('powershell -NoProfile -Command "if (Test-Path '!NPM_LIST_JSON_CACHE!') { (Get-Item '!NPM_LIST_JSON_CACHE!').Length }" 2^>nul') do set "json_size=%%f"
if defined json_size if !json_size! GTR %MAX_JSON_SIZE% (
    call :dbg %YELLOW%[WARNING]%NC% npm list JSON too large: !json_size! bytes; skipping
    exit /b 0
)

for /f "delims=" %%v in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "param($jsonPath, $pkg); $ErrorActionPreference='SilentlyContinue'; if (Test-Path $jsonPath) { $jsonText = Get-Content -Raw $jsonPath; if ($jsonText) { $json = ConvertFrom-Json -InputObject $jsonText; if ($json -and $json.dependencies) { $dep = $json.dependencies.$pkg; if ($dep -and $dep.version) { Write-Output $dep.version } } } }" -jsonPath "!NPM_LIST_JSON_CACHE!" -pkg "!pkg!" 2^>nul') do (
    if not "%%v"=="" set "%outvar%=%%v"
)
exit /b 0

REM ###############################################
REM ADDON VERSION DETECTION (OpenCode addons)
REM ###############################################

:find_opencode_config
set "OPENCODE_CONFIG="
if exist "%USERPROFILE%\.config\opencode\opencode.json" set "OPENCODE_CONFIG=%USERPROFILE%\.config\opencode\opencode.json"
if not defined OPENCODE_CONFIG if defined APPDATA if exist "%APPDATA%\opencode\opencode.json" set "OPENCODE_CONFIG=%APPDATA%\opencode\opencode.json"
if not defined OPENCODE_CONFIG if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\opencode\opencode.json" set "OPENCODE_CONFIG=%LOCALAPPDATA%\opencode\opencode.json"
exit /b 0

:get_oh_my_opencode_plugin_spec
set "outvar=%~1"
set "%outvar%="
call :find_opencode_config
if not defined OPENCODE_CONFIG exit /b 0

for /f "delims=" %%v in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "param($p); try { $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json; $arr = $j.plugin; if ($arr) { foreach($x in $arr) { if ($x -like 'oh-my-opencode*') { Write-Output $x; break } } } } catch { }" -p "%OPENCODE_CONFIG%" 2^>nul') do (
    if not "%%v"=="" if not defined %outvar% set "%outvar%=%%v"
)
exit /b 0

:get_installed_addon_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="

if /I not "%pkg%"=="oh-my-opencode" exit /b 0

set "PLUGIN_SPEC="
call :get_oh_my_opencode_plugin_spec PLUGIN_SPEC
if not defined PLUGIN_SPEC exit /b 0

REM If the plugin spec includes an explicit version (oh-my-opencode@x.y.z), prefer that.
set "PLUGIN_VER="
for /f "delims=" %%v in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "param($s); if ($s -match '^oh-my-opencode@(.+)$') { $Matches[1] }" -s "%PLUGIN_SPEC%" 2^>nul') do (
    if not "%%v"=="" if not defined PLUGIN_VER set "PLUGIN_VER=%%v"
)
if defined PLUGIN_VER (
    set "%outvar%=%PLUGIN_VER%"
    exit /b 0
)

REM No explicit version in config; fall back to latest from npm.
call :get_latest_npm_version "oh-my-opencode" %outvar%
exit /b 0

:get_latest_pypi_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
set "tmpfile=%TEMP%\pypi_version_%RANDOM%.tmp"
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $uri = 'https://pypi.org/pypi/%pkg%/json?ts=' + $ts; $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 10 -ErrorAction Stop; if ($result -and $result.info -and $result.info.version) { $version = $result.info.version } } catch { } if (-not $version -and $attempt -lt 1) { Start-Sleep -Seconds 1 } $attempt++ } if ($version) { Write-Output $version }" >"%tmpfile%" 2>nul
if exist "%tmpfile%" (
    for /f "usebackq delims=" %%v in ("%tmpfile%") do (
        if not "%%v"=="" set "%outvar%=%%v"
    )
    del "%tmpfile%" >nul 2>nul
)
exit /b 0

:get_latest_npm_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
set "tmpfile=%TEMP%\npm_version_%RANDOM%.tmp"
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $uri = 'https://registry.npmjs.org/%pkg%/latest?ts=' + $ts; $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 10 -ErrorAction Stop; if ($result -and $result.version) { $version = $result.version } } catch { } if (-not $version -and $attempt -lt 1) { Start-Sleep -Seconds 1 } $attempt++ } if ($version) { Write-Output $version }" >"%tmpfile%" 2>nul
if exist "%tmpfile%" (
    for /f "usebackq delims=" %%v in ("%tmpfile%") do (
        if not "%%v"=="" set "%outvar%=%%v"
    )
    del "%tmpfile%" >nul 2>nul
)
exit /b 0

REM Get npm's own installed version
:get_installed_npm_self_version
set "outvar=%~1"
set "%outvar%="
call :resolve_conda_npm
if errorlevel 1 exit /b 0
for /f "delims=" %%v in ('"!CONDA_NPM!" --version 2^>nul') do (
    if not "%%v"=="" set "%outvar%=%%v"
)
exit /b 0

REM Get npm's own latest version
:get_latest_npm_self_version
	set "outvar=%~1"
	set "%outvar%="
	where curl >nul 2>nul
	if errorlevel 1 exit /b 0
	set "tmpfile=%TEMP%\npm_self_version_%RANDOM%.tmp"
	powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $uri = 'https://registry.npmjs.org/npm/latest?ts=' + $ts; $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 10 -ErrorAction Stop; if ($result -and $result.version) { $version = $result.version } } catch { } if (-not $version -and $attempt -lt 1) { Start-Sleep -Seconds 1 } $attempt++ } if ($version) { Write-Output $version }" >"%tmpfile%" 2>nul
	if exist "%tmpfile%" (
	    for /f "usebackq delims=" %%v in ("%tmpfile%") do (
	        if not "%%v"=="" set "%outvar%=%%v"
	    )
	    del "%tmpfile%" >nul 2>nul
	)
	exit /b 0

REM Get latest version for native tools (e.g., Claude Code, MoAI-ADK)
:get_latest_native_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
if /I "%pkg%"=="claude-code" goto get_latest_native_claude
if /I "%pkg%"=="moai-adk" goto get_latest_native_moai
exit /b 0

:get_latest_native_claude
set "tmpfile=%TEMP%\claude_code_version_%RANDOM%.tmp"
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $uri = 'https://api.github.com/repos/anthropics/claude-code/releases/latest?ts=' + $ts; $headers = @{ 'User-Agent'='agentic-cli-installer'; 'Accept'='application/vnd.github+json' }; try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -Headers $headers -TimeoutSec 10 -ErrorAction Stop; if ($result -and $result.tag_name) { Write-Output ($result.tag_name -replace '^v','') } } catch { }" >"%tmpfile%" 2>nul
if exist "%tmpfile%" (
    for /f "usebackq delims=" %%v in ("%tmpfile%") do (
        if not "%%v"=="" set "%outvar%=%%v"
    )
    del "%tmpfile%" >nul 2>nul
)
exit /b 0

:get_latest_native_moai
set "tmpfile=%TEMP%\moai_adk_version_%RANDOM%.tmp"
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); $uri = 'https://api.github.com/repos/modu-ai/moai-adk/releases/latest?ts=' + $ts; $headers = @{ 'User-Agent'='agentic-cli-installer'; 'Accept'='application/vnd.github+json' }; try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -Headers $headers -TimeoutSec 10 -ErrorAction Stop; if ($result -and $result.tag_name) { $tag = $result.tag_name; $tag = $tag -replace '^go-',''; $tag = $tag -replace '^v',''; Write-Output $tag } } catch { }" >"%tmpfile%" 2>nul
if exist "%tmpfile%" (
    for /f "usebackq delims=" %%v in ("%tmpfile%") do (
        if not "%%v"=="" set "%outvar%=%%v"
    )
    del "%tmpfile%" >nul 2>nul
)
exit /b 0

REM Get installed version for native tools (e.g., Claude Code, MoAI-ADK)
:get_installed_native_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
if /I "%pkg%"=="claude-code" (
    where claude >nul 2>nul
    if not errorlevel 1 (
        call :get_semver_from_command "claude" "--version" "%outvar%"
    )
)
if /I "%pkg%"=="moai-adk" (
    where moai >nul 2>nul
    if not errorlevel 1 (
        call :get_semver_from_command "moai" "--version" "%outvar%"
        if not defined %outvar% call :get_semver_from_command "moai" "version" "%outvar%"
    )
)
exit /b 0

REM Check for npm-installed Claude Code (for migration)
:check_npm_claude_code
set "outvar=%~1"
set "%outvar%=0"
call :resolve_conda_npm
if errorlevel 1 exit /b 0
REM Check if @anthropic-ai/claude-code is in npm list
set "NPM_CLAUDE_CHECK="
for /f "delims=" %%v in ('"!CONDA_NPM!" list -g @anthropic-ai/claude-code 2^>nul ^| findstr /C:"@anthropic-ai/claude-code"') do (
    set "NPM_CLAUDE_CHECK=%%v"
)
if defined NPM_CLAUDE_CHECK (
    set "%outvar%=1"
)
exit /b 0

REM Helper function for semantic version comparison
:version_compare_semver
set "installed=%~1"
set "latest=%~2"
set "outvar=%~3"

if "%installed%"=="Not Installed" echo missing& exit /b 0
if "%latest%"=="" echo unknown& exit /b 0

REM Use PowerShell for proper semver comparison
for /f "delims=" %%r in ('powershell -NoProfile -Command "try { $v1 = [version]('%installed%'); $v2 = [version]('%latest%'); if ($v1 -ge $v2) { Write-Output 'current' } else { Write-Output 'update' } } catch { Write-Output 'update' }"') do (
    set "%outvar%=%%r"
)
exit /b 0

REM ###############################################
REM INITIALIZATION
REM ###############################################

:initialize_tools
REM Add npm as update-only tool when a conda environment is active
set "HAS_NPM=0"
if defined CONDA_PREFIX set "HAS_NPM=1"
if defined CONDA_DEFAULT_ENV set "HAS_NPM=1"
if "%HAS_NPM%"=="1" (
    REM Shift all existing tools up by 1
    REM Loop based on current TOOLS_COUNT to avoid hardcoded index drift
    for /L %%i in (%TOOLS_COUNT%,-1,1) do (
        set /a "new_idx=%%i+1"
        call set "NAME_!new_idx!=%%NAME_%%i%%"
        call set "MGR_!new_idx!=%%MGR_%%i%%"
        call set "PKG_!new_idx!=%%PKG_%%i%%"
        call set "DESC_!new_idx!=%%DESC_%%i%%"
        call set "BIN_!new_idx!=%%BIN_%%i%%"
        call set "VERARG_!new_idx!=%%VERARG_%%i%%"
    )
        REM Now increment TOOLS_COUNT after shifting
        set /a TOOLS_COUNT+=1
        REM Add npm as tool 1
        REM Avoid parentheses in tool names; they can break parsing inside parenthesized blocks.
        set "NAME_1=npm - Node Package Manager"
        set "MGR_1=npm-self"
        set "PKG_1=npm"
        set "DESC_1=npm - Node Package Manager"
        set "BIN_1=npm"
        set "VERARG_1=--version"
        set "UPDATE_ONLY_1=1"
    )

call :dbg %BLUE%[STEP]%NC% prefetch_latest_versions
if "%NO_PREFETCH%"=="1" (
    call :dbg %YELLOW%[INFO]%NC% Skipping latest-version prefetch; --no-prefetch is set.
    goto skip_prefetch
)

REM Try to create temp directory - try multiple locations
set "LATEST_CACHE_DIR="
if defined TEMP (
    set "LATEST_CACHE_DIR=%TEMP%\agentic_%RANDOM%"
    md "!LATEST_CACHE_DIR!" >nul 2>nul
)
if not exist "!LATEST_CACHE_DIR!" if defined TMP (
    set "LATEST_CACHE_DIR=%TMP%\agentic_%RANDOM%"
    md "!LATEST_CACHE_DIR!" >nul 2>nul
)
if not exist "!LATEST_CACHE_DIR!" (
    REM Fallback to current directory
    set "LATEST_CACHE_DIR=%CD%\agentic_cache_%RANDOM%"
    md "!LATEST_CACHE_DIR!" >nul 2>nul
)
if not exist "!LATEST_CACHE_DIR!" (
    call :dbg %YELLOW%[WARNING]%NC% Failed to create temp directory; skipping prefetch.
    goto skip_prefetch
)

set "LATEST_LIST_FILE=!LATEST_CACHE_DIR!\tools.txt"
> "!LATEST_LIST_FILE!" (
    for /L %%i in (1,1,%TOOLS_COUNT%) do (
        set "idx=%%i"
        call set "mgr=%%MGR_%%i%%"
        call set "mgr=%%mgr%%"
        call set "pkg=%%PKG_%%i%%"
        call set "pkg=%%pkg%%"
        echo !idx!^|!mgr!^|!pkg!
    )
)

REM Prefetch with individual timeout for each tool
echo Prefetching latest versions...
for /L %%i in (1,1,%TOOLS_COUNT%) do call :prefetch_one_tool_by_index %%i
if exist "!LATEST_LIST_FILE!" del "!LATEST_LIST_FILE!" >nul 2>nul

:skip_prefetch
for /L %%i in (1,1,%TOOLS_COUNT%) do call :init_tool %%i
if defined LATEST_CACHE_DIR (
    rd /s /q "%LATEST_CACHE_DIR%" >nul 2>nul
)
REM Clear the progress line
echo.
exit /b 0

:prefetch_one_tool_by_index
set "idx=%~1"
call set "mgr=%%MGR_%idx%%%"
call set "mgr=%%mgr%%"
call set "pkg=%%PKG_%idx%%%"
call set "pkg=%%pkg%%"
call :prefetch_one_tool "%idx%" "!mgr!" "!pkg!"
exit /b 0

:prefetch_one_tool
	set "p_idx=%~1"
	set "p_mgr=%~2"
	set "p_pkg=%~3"
	set "VERSION="

	REM NOTE: Avoid `for /f ('powershell ...')` here. Parentheses in the PowerShell
	REM snippets can break cmd.exe parsing inside blocks, causing ". was unexpected at this time."
	if /I "!p_mgr!"=="uv" (
	    call :get_latest_pypi_version "!p_pkg!" VERSION
	) else if /I "!p_mgr!"=="npm-self" (
	    call :get_latest_npm_self_version VERSION
	) else if /I "!p_mgr!"=="npm" (
	    call :get_latest_npm_version "!p_pkg!" VERSION
	) else if /I "!p_mgr!"=="addon" (
	    call :get_latest_npm_version "!p_pkg!" VERSION
	) else if /I "!p_mgr!"=="native" (
	    call :get_latest_native_version "!p_pkg!" VERSION
	)
	if defined VERSION if defined LATEST_CACHE_DIR (
	    echo !VERSION!>"!LATEST_CACHE_DIR!\latest_!p_idx!.txt"
	)
	exit /b 0

:init_tool
set "idx=%~1"
call set "mgr=%%MGR_%idx%%%"
call set "mgr=%%mgr%%"
call set "pkg=%%PKG_%idx%%%"
call set "pkg=%%pkg%%"
call set "desc=%%DESC_%idx%%%"
call set "desc=%%desc%%"
call set "bin=%%BIN_%idx%%%"
call set "bin=%%bin%%"
call set "verarg=%%VERARG_%idx%%%"
call set "verarg=%%verarg%%"

REM Show progress
if "%DEBUG%"=="1" (
    echo %BLUE%[INFO]%NC% Checking: %CYAN%!desc!%NC%
) else if "%NO_COLOR%"=="1" (
    echo [INFO] Checking: !desc!
) else (
    echo %BLUE%[INFO]%NC% Checking: %CYAN%!desc!%NC%
)

	    set "ONPATH=0"
	    set "BINPATH="
	    if defined bin (
	        REM Prefer an executable the shell can actually run (where can return extensionless stubs first).
	        set "BEST_SCORE=99"
	        for /f "delims=" %%p in ('where !bin! 2^>nul') do (
	            set "cand=%%p"
	            set "ext=%%~xp"
	            set "score=90"
	            if /I "%%~xp"==".exe" set "score=10"
	            if /I "%%~xp"==".cmd" set "score=20"
	            if /I "%%~xp"==".bat" set "score=30"
	            if /I "%%~xp"==".com" set "score=40"
	            if /I "%%~xp"==".ps1" set "score=50"
	            if "%%~xp"=="" set "score=80"
	            if !score! LSS !BEST_SCORE! (
	                set "BEST_SCORE=!score!"
	                set "BINPATH=%%p"
	            )
	        )
	        if defined BINPATH set "ONPATH=1"
    )
    call :dbg %BLUE%[DEBUG]%NC% tool !idx! bin=!bin! binpath=!BINPATH! onpath=!ONPATH!

    set "INST="
    REM Prefer manager-specific detection; avoids invoking broken shims and finds off-PATH installs
    if /I "!mgr!"=="npm-self" (
        call :get_installed_npm_self_version INST
    ) else if /I "!mgr!"=="npm" (
        call :get_installed_npm_version "!pkg!" INST
    ) else if /I "!mgr!"=="uv" (
        call :get_installed_uv_version "!pkg!" INST
    ) else if /I "!mgr!"=="addon" (
        call :get_installed_addon_version "!pkg!" INST
    ) else if /I "!mgr!"=="native" (
        call :get_installed_native_version "!pkg!" INST
    )

    REM Fall back to the CLI only when manager lookup failed and the tool is on PATH (skip uv shims)
    if not defined INST (
        if /I not "!mgr!"=="uv" if "!ONPATH!"=="1" (
            if defined BINPATH (
                call :get_semver_from_command "!BINPATH!" "!verarg!" INST
            ) else (
                call :get_semver_from_command "!bin!" "!verarg!" INST
            )
        )
    )

set "LATEST="
if defined LATEST_CACHE_DIR (
    set "latest_file=!LATEST_CACHE_DIR!\latest_!idx!.txt"
    if exist "!latest_file!" (
        for /f "usebackq delims=" %%v in ("!latest_file!") do (
            if not "%%v"=="" set "LATEST=%%v"
        )
    )
)

    if not defined INST set "INST=Not Installed"
    if not defined LATEST set "LATEST=Unknown"

	set "INST_%idx%=%INST%"
	set "LAT_%idx%=%LATEST%"
	set "ONPATH_%idx%=%ONPATH%"

REM Set default action based on status
REM Only auto-select tools that need updates, not new installations
if "!INST!"=="Not Installed" (
    set "ACT_%idx%=0"
    set "SEL_%idx%=0"
) else if "!LATEST!"=="Unknown" (
    set "ACT_%idx%=0"
    set "SEL_%idx%=0"
) else (
    REM Use semantic version comparison
    call :version_compare_semver "!INST!" "!LATEST!" VERSION_STATUS
    if "!VERSION_STATUS!"=="update" (
        set "ACT_%idx%=1"
        set "SEL_%idx%=1"
    ) else (
        set "ACT_%idx%=0"
        set "SEL_%idx%=0"
    )
)
exit /b 0

REM ###############################################
REM MENU RENDERING
REM ###############################################

:render_menu
REM Avoid emitting control characters (e.g. form feed) when debugging.
if "%DEBUG%"=="1" (
    echo.
) else (
    cls
)
call :print_banner_sep
echo %CYAN%%BOLD%Agentic Coders CLI Installer%NC% %BOLD%v1.7.19%NC%
echo Toggle: %CYAN%skip%NC% -^> %GREEN%install%NC% -^> %RED%remove%NC%  Input: 1,3,5  Enter/P=proceed  Q=quit
call :print_banner_sep
echo.
echo %BOLD%[MENU]%NC%
call :print_sep
echo   #  Tool                           Installed       Latest     Action  Select
call :print_sep
set "HAS_OFFPATH=0"
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call :print_tool %%i
)
if "%HAS_OFFPATH%"=="1" echo   * installed but command not on PATH
call :print_sep
exit /b 0

:print_tool
set "idx=%~1"
set "num= %idx%"
set "num=!num:~-2!"
call set "name=%%NAME_%idx%%%"
call set "name=%%name%%"
call set "inst=%%INST_%idx%%%"
call set "inst=%%inst%%"
call set "lat=%%LAT_%idx%%%"
call set "lat=%%lat%%"
call set "act=%%ACT_%idx%%%"
call set "act=%%act%%"
call set "mgr=%%MGR_%idx%%%"
call set "mgr=%%mgr%%"
call set "onpath=%%ONPATH_%idx%%%"
call set "onpath=%%onpath%%"

REM Map action to display values (ASCII-only markers to avoid mojibake).
if "!act!"=="0" (
    set "actname=skip"
    set "actcol=%CYAN%"
    set "chk=[ ]"
    set "chkcol=%CYAN%"
) else if "!act!"=="1" (
    set "actname=install"
    set "actcol=%GREEN%"
    set "chk=[X]"
    set "chkcol=%GREEN%"
) else (
    set "actname=remove"
    set "actcol=%RED%"
    set "chk=[R]"
    set "chkcol=%RED%"
)

REM Force ASCII markers to avoid mojibake in different consoles/code pages.
set "chk=[ ]"
if "!act!"=="1" set "chk=[X]"
if "!act!"=="2" set "chk=[R]"

REM Determine installed color
if "!inst!"=="Not Installed" (
    set "instcol=%RED%"
) else if "!inst!"=="!lat!" (
    set "instcol=%GREEN%"
) else (
    set "instcol=%YELLOW%"
)

REM Mark "installed but not on PATH" with a trailing asterisk for npm tools.
if /I "!mgr!"=="npm" (
    if not "!inst!"=="Not Installed" (
        if "!onpath!"=="0" (
            set "inst=!inst!*"
            set "HAS_OFFPATH=1"
        )
    )
)

REM Format and print line with colors (pad first, then apply colors so columns align even with ANSI sequences)
call :pad_right "!name!" 30 NAME_PAD
call :pad_right "!inst!" 13 INST_PAD
call :pad_right "!lat!" 9 LAT_PAD
call :pad_right "!actname!" 7 ACT_PAD

echo  %BOLD%!num!%NC%  !NAME_PAD! !instcol!!INST_PAD!!NC! !LAT_PAD! !actcol!!ACT_PAD!!NC!  !chkcol!!chk!!NC!
exit /b 0

REM ###############################################
REM USER INPUT HANDLING
REM ###############################################

:parse_selection
set "input=%~1"
set "input=%input:,= %"

:parse_loop
for /f "tokens=1*" %%a in ("%input%") do (
    set "token=%%a"
    set "input=%%b"
    call :cycle_selection "!token!"
    if not "!input!"=="" goto parse_loop
)

call :resolve_addon_dependencies
exit /b 0

:resolve_addon_dependencies
set "oh_idx=0"
set "opencode_idx=0"

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "pkg=%%PKG_%%i%%"
    call set "pkg=%%pkg%%"
    if /I "!pkg!"=="oh-my-opencode" set "oh_idx=%%i"
    if /I "!pkg!"=="opencode-ai" set "opencode_idx=%%i"
)

if "%oh_idx%"=="0" exit /b 0
if "%opencode_idx%"=="0" exit /b 0

call set "oh_act=%%ACT_%oh_idx%%%"
call set "oh_act=%%oh_act%%"

REM If oh-my-opencode is selected for install/update, ensure opencode-ai is installed first.
if "%oh_act%"=="1" (
    call set "op_inst=%%INST_%opencode_idx%%%"
    call set "op_inst=%%op_inst%%"
    call set "op_act=%%ACT_%opencode_idx%%%"
    call set "op_act=%%op_act%%"
    if /I "%op_inst%"=="Not Installed" (
        if "%op_act%"=="0" (
            set "ACT_%opencode_idx%=1"
            set "SEL_%opencode_idx%=1"
            echo %BLUE%[INFO]%NC% Auto-selected OpenCode AI CLI (required for oh-my-opencode)
        )
    )
)
exit /b 0

:cycle_selection
set "num=%~1"
if not defined num goto invalid
echo(!num!| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 goto invalid
set "numVal="
set /a "numVal=num" >nul 2>nul
if not defined numVal goto invalid
if !numVal! LSS 1 goto invalid
if !numVal! GTR %TOOLS_COUNT% goto invalid

set "idx=%numVal%"
call set "cur=%%ACT_%idx%%%"
call set "cur=%%cur%%"
call set "inst=%%INST_%idx%%%"
call set "inst=%%inst%%"
call set "lat=%%LAT_%idx%%%"
call set "lat=%%lat%%"
call set "name=%%NAME_%idx%%%"
call set "name=%%name%%"
call set "update_only=%%UPDATE_ONLY_%idx%%%"
call set "update_only=%%update_only%%"

REM Determine tool state and valid transitions
REM For update-only tools (npm):
REM   - Can only update if outdated, otherwise skip
REM   - Never allow remove
REM For regular tools:
REM   State 1: Not Installed - can only install or skip (no remove)
REM   State 2: Up-to-date (installed == latest) - can only remove or skip (no install)
REM   State 3: Outdated (installed != latest) - can install, update, or remove

set "not_installed=0"
set "up_to_date=0"

if "!inst!"=="Not Installed" (
    set "not_installed=1"
) else if "!inst!"=="!lat!" (
    set "up_to_date=1"
)

REM Handle update-only tools specially
if "!update_only!"=="1" (
    if "!cur!"=="0" (
        REM Currently skip
        if "!not_installed!"=="0" (
            if "!up_to_date!"=="0" (
                REM Outdated: skip -> install (update)
                set "ACT_%idx%=1"
                set "SEL_%idx%=1"
                echo %BLUE%[INFO]%NC% Selected for update: !name!
            ) else (
                REM Up-to-date or not installed: skip remains skip (with message)
                echo %BLUE%[INFO]%NC% !name! is !inst! - no action available
            )
        ) else (
            echo %BLUE%[INFO]%NC% !name! is !inst! - no action available
        )
    ) else (
        REM Currently install -> skip
        set "ACT_%idx%=0"
        set "SEL_%idx%=0"
        echo %BLUE%[INFO]%NC% Deselected: !name!
    )
    exit /b 0
)

REM Regular tools cycle logic
if "!cur!"=="0" (
    REM Currently skip
    if "!not_installed!"=="1" (
        REM Not installed: skip -> install
        set "ACT_%idx%=1"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for install: !name!
    ) else if "!up_to_date!"=="1" (
        REM Up-to-date: skip -> remove
        set "ACT_%idx%=2"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for removal: !name!
    ) else (
        REM Outdated: skip -> install
        set "ACT_%idx%=1"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for update: !name!
    )
) else if "!cur!"=="1" (
    REM Currently install
    if "!not_installed!"=="1" (
        REM Not installed: install -> skip (no remove option)
        set "ACT_%idx%=0"
        set "SEL_%idx%=0"
        echo %BLUE%[INFO]%NC% Deselected: !name!
    ) else (
        REM Installed (outdated): install -> remove
        set "ACT_%idx%=2"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for removal: !name!
    )
) else (
    REM Currently remove - always goes to skip
    set "ACT_%idx%=0"
    set "SEL_%idx%=0"
    echo %BLUE%[INFO]%NC% Deselected: !name!
)
exit /b 0

:invalid
echo %RED%[ERROR]%NC% Invalid selection: "%num%" - use numbers 1-%TOOLS_COUNT%
exit /b 1

REM ###############################################
REM ACTION SUMMARY AND CONFIRMATION
REM ###############################################

:display_action_summary
set "install_count=0"
set "remove_count=0"

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    if "!act!"=="1" (
        set /a install_count+=1
    ) else if "!act!"=="2" (
        set /a remove_count+=1
    )
)

echo.
echo %BOLD%[ACTION SUMMARY]%NC%
call :print_sep

if !install_count! GTR 0 (
    echo - Install: !install_count!
    for /L %%i in (1,1,%TOOLS_COUNT%) do (
        call set "act=%%ACT_%%i%%"
        call set "act=%%act%%"
        if "!act!"=="1" (
            call set "pkg=%%PKG_%%i%%"
            call set "pkg=%%pkg%%"
            call set "inst=%%INST_%%i%%"
            call set "inst=%%inst%%"
            call set "lat=%%LAT_%%i%%"
            call set "lat=%%lat%%"
            echo   - !pkg!: !inst! -^> !lat!
        )
    )
)

if !remove_count! GTR 0 (
    echo - Remove: !remove_count!
    for /L %%i in (1,1,%TOOLS_COUNT%) do (
        call set "act=%%ACT_%%i%%"
        call set "act=%%act%%"
        if "!act!"=="2" (
            call set "pkg=%%PKG_%%i%%"
            call set "pkg=%%pkg%%"
            call set "inst=%%INST_%%i%%"
            call set "inst=%%inst%%"
            echo   - !pkg!: !inst!
        )
    )
    echo.
    echo %RED%%BOLD%WARNING:%NC% removals cannot be undone.
)
exit /b 0

:show_selected_tools
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    if not "!act!"=="0" (
        call set "name=%%NAME_%%i%%"
        call set "name=%%name%%"
        if "!act!"=="1" (
            echo   %GREEN%[INSTALL]%NC% !name!
        ) else if "!act!"=="2" (
            echo   %RED%[REMOVE]%NC% !name!
        )
    )
)
exit /b 0

:confirm_removals
set "has_removals=0"
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    if "!act!"=="2" set "has_removals=1"
)

if "!has_removals!"=="1" (
    if "%AUTO_YES%"=="1" (
        echo %YELLOW%[AUTO-YES]%NC% Proceeding with removals in non-interactive mode
        exit /b 0
    )
    set "response="
    REM Avoid parentheses in prompt text; they can break parsing inside parenthesized blocks.
    set /p response="Proceed with removals? [y/N]: "
    if /I "!response!"=="y" exit /b 0
    if /I "!response!"=="yes" exit /b 0
    echo %YELLOW%[WARNING]%NC% Cancelled by user
    exit /b 1
)
exit /b 0

REM ###############################################
REM DEPENDENCY CHECKS
REM ###############################################

:check_dependencies
set "missing_count=0"

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    if not "!act!"=="0" (
        call set "mgr=%%MGR_%%i%%"
        call set "mgr=%%mgr%%"
        call set "name=%%NAME_%%i%%"
        call set "name=%%name%%"
        if "!mgr!"=="uv" (
            where uv >nul 2>nul
            if errorlevel 1 (
                set /a missing_count+=1
                set "missing_!missing_count!=uv (required for !name!^)"
            )
        ) else if "!mgr!"=="npm" (
            call :resolve_conda_npm
            if errorlevel 1 (
                set /a missing_count+=1
                set "missing_!missing_count!=npm (required for !name!^)"
            )
        ) else if "!mgr!"=="addon" (
            call :resolve_conda_npm
            if errorlevel 1 (
                set /a missing_count+=1
                set "missing_!missing_count!=npm (required for !name!^)"
            )
            where bunx >nul 2>nul
            if errorlevel 1 (
                where npx >nul 2>nul
                if errorlevel 1 (
                    set /a missing_count+=1
                    set "missing_!missing_count!=bunx/npx (required for !name!^)"
                )
            )
        ) else if "!mgr!"=="native" (
            REM Native tools use their own installer, just need curl
            where curl >nul 2>nul
            if errorlevel 1 (
                set /a missing_count+=1
                set "missing_!missing_count!=curl (required for !name!^)"
            )
        )
    )
)

if !missing_count! GTR 0 (
    echo %RED%[ERROR]%NC% Missing required dependencies:
    for /L %%j in (1,1,!missing_count!) do (
        call set "m=%%missing_%%j%%"
        echo   - %RED%!m!%NC%
    )
    echo.
    echo Install missing dependencies:
    echo   %CYAN%uv%NC%:   %YELLOW%https://github.com/astral-sh/uv#installing-uv%NC%
    echo   %CYAN%npm%NC%:   %YELLOW%conda install -c conda-forge "nodejs>=%MIN_NODEJS_VERSION%" -y%NC%
    exit /b 1
)
exit /b 0

REM ###############################################
REM INSTALLATION FUNCTIONS
REM ###############################################

:run_installation_steps
set "install_success=0"
set "install_fail=0"
set "remove_success=0"
set "remove_fail=0"
	
	echo.
	echo %BOLD%[INSTALLATION]%NC%
	call :print_sep
	
	for /L %%i in (1,1,%TOOLS_COUNT%) do (
	    call set "act=%%ACT_%%i%%"
	    call set "act=%%act%%"
    if "!act!"=="1" (
        call :install_tool %%i
        if errorlevel 1 (
            set /a install_fail+=1
        ) else (
            set /a install_success+=1
        )
    ) else if "!act!"=="2" (
        call :remove_tool %%i
        if errorlevel 1 (
            set /a remove_fail+=1
        ) else (
            set /a remove_success+=1
        )
	    )
	)

	echo.
	echo %BOLD%[RESULT]%NC%
	call :print_sep
	set /a "fail_total=install_fail+remove_fail"
	echo - Installed: !install_success!
	echo - Removed:   !remove_success!
	echo - Failed:    !fail_total!
	call :print_sep
	if !install_fail! GTR 0 exit /b 1
	if !remove_fail! GTR 0 exit /b 1
	exit /b 0

:install_tool
		set "idx=%~1"
		call set "name=%%NAME_%idx%%%"
		call set "name=%%name%%"
		call set "mgr=%%MGR_%idx%%%"
		call set "mgr=%%mgr%%"
		call set "pkg=%%PKG_%idx%%%"
		call set "pkg=%%pkg%%"
		call set "inst=%%INST_%idx%%%"
		call set "inst=%%inst%%"
		
		echo.
		echo - !pkg!:
		call :dbg   %BLUE%[DEBUG]%NC% mgr=!mgr! pkg=!pkg! installed=!inst!

	REM Avoid nested parenthesized blocks here; unescaped parentheses from tool output or paths
	REM can break cmd.exe parsing and produce "... was unexpected at this time."
	if /I "!mgr!"=="npm-self" goto install_tool_npm_self
	if /I "!mgr!"=="uv" goto install_tool_uv
	if /I "!mgr!"=="addon" goto install_tool_addon
	if /I "!mgr!"=="native" goto install_tool_native
	goto install_tool_npm

:install_tool_npm_self
		REM npm can only be updated, not installed from scratch
		echo   Updating npm via conda npm...
		call :resolve_conda_npm
		if errorlevel 1 exit /b 1
		call :dbg   %BLUE%[DEBUG]%NC% run: "!CONDA_NPM!" install -g npm@latest
		call "!CONDA_NPM!" install -g npm@latest
		exit /b %errorlevel%

:install_tool_uv
	if /I "!inst!"=="Not Installed" goto install_tool_uv_install
	goto install_tool_uv_update

:install_tool_uv_install
		echo   Installing via uv...
		REM For initial install, do not use --force (recommended method)
		call :dbg   %BLUE%[DEBUG]%NC% run: uv tool install "!pkg!"
		call uv tool install "!pkg!"
		exit /b %errorlevel%

:install_tool_uv_update
		echo   Updating via uv...
		REM Use install --force instead of update to get the latest version
		REM uv tool update only updates within original version constraints
		call :dbg   %BLUE%[DEBUG]%NC% run: uv tool install "!pkg!" --force
		call uv tool install "!pkg!" --force
		exit /b %errorlevel%

:install_tool_addon
	if /I "!pkg!"=="oh-my-opencode" goto install_tool_addon_ohmy
	echo   %RED%[ERROR]%NC% Unknown addon: !pkg!
	exit /b 1

:install_tool_addon_ohmy
	where opencode >nul 2>nul
	if errorlevel 1 (
		echo   %RED%[ERROR]%NC% Cannot install oh-my-opencode: opencode-ai must be installed first.
		exit /b 1
	)
	if /I "!inst!"=="Not Installed" (
		echo   Installing addon...
		call :install_oh_my_opencode
		exit /b 0
	)
	echo   Addon is installed. Reinstalling...
	call :remove_oh_my_opencode
	call :install_oh_my_opencode
	exit /b 0

:install_tool_native
	if /I "!pkg!"=="claude-code" goto install_tool_claude
	if /I "!pkg!"=="moai-adk" goto install_tool_moai
	exit /b 0

:install_tool_claude
	set "HAS_NPM_CLAUDE=0"
	call :check_npm_claude_code HAS_NPM_CLAUDE
	if "!HAS_NPM_CLAUDE!"=="1" goto install_tool_claude_migrate
	goto install_tool_claude_post_migrate

:install_tool_claude_migrate
		echo   %YELLOW%Detected npm-installed Claude Code (deprecated method)%NC%
		echo   %YELLOW%The npm installation method is deprecated. Migrating to native installer...%NC%
		echo   Removing npm version...
		call :resolve_conda_npm
		if errorlevel 1 goto install_tool_claude_migrate_warn
		call :dbg   %BLUE%[DEBUG]%NC% run: "!CONDA_NPM!" uninstall -g "@anthropic-ai/claude-code"
		call "!CONDA_NPM!" uninstall -g "@anthropic-ai/claude-code" >nul 2>nul
		if errorlevel 1 goto install_tool_claude_migrate_warn
		echo   %GREEN%npm version removed successfully%NC%
		goto install_tool_claude_migrate_done

:install_tool_claude_migrate_warn
	echo   %YELLOW%Warning: Failed to remove npm version, continuing anyway...%NC%

:install_tool_claude_migrate_done
	set "inst=Not Installed"

:install_tool_claude_post_migrate
	if /I "!inst!"=="Not Installed" goto install_tool_claude_install
	goto install_tool_claude_update

:install_tool_claude_install
	echo   Installing Claude Code ^(native installer^)...
	call :dbg   %BLUE%[DEBUG]%NC% run: download_claude_installer
	if exist "%TEMP%\install.cmd" del "%TEMP%\install.cmd" >nul 2>nul
	call :download_claude_installer "%TEMP%\install.cmd"
	if errorlevel 1 exit /b 1
	call "%TEMP%\install.cmd"
	set "RC=%errorlevel%"
	del "%TEMP%\install.cmd" >nul 2>nul
	if %RC% NEQ 0 exit /b %RC%
	exit /b 0

:install_tool_claude_update
	echo   Updating Claude Code...
	call :dbg   %BLUE%[DEBUG]%NC% run: claude update
	call claude update
	if errorlevel 1 goto install_tool_claude_reinstall
	exit /b 0

:install_tool_claude_reinstall
	echo   Update command failed, trying re-install...
	if exist "%TEMP%\install.cmd" del "%TEMP%\install.cmd" >nul 2>nul
	call :download_claude_installer "%TEMP%\install.cmd"
	if errorlevel 1 exit /b 1
	call "%TEMP%\install.cmd"
	set "RC=%errorlevel%"
	del "%TEMP%\install.cmd" >nul 2>nul
	if %RC% NEQ 0 exit /b %RC%
	exit /b 0

:install_tool_moai
	set "BEFORE_MOAI_VERSION="
	call :get_installed_native_version "moai-adk" BEFORE_MOAI_VERSION
	if /I "!inst!"=="Not Installed" (
		echo   Installing MoAI-ADK (native installer)...
	) else (
		echo   Updating MoAI-ADK (native installer)...
	)
	call :dbg   %BLUE%[DEBUG]%NC% run: moai installer
	call :run_moai_installer
	if errorlevel 1 exit /b 1
	set "AFTER_MOAI_VERSION="
	call :get_installed_native_version "moai-adk" AFTER_MOAI_VERSION
	if not defined AFTER_MOAI_VERSION (
		echo %RED%[ERROR]%NC% MoAI-ADK installer completed but `moai` command is not available.
		exit /b 1
	)
	if /I not "!inst!"=="Not Installed" if defined BEFORE_MOAI_VERSION if /I "!AFTER_MOAI_VERSION!"=="!BEFORE_MOAI_VERSION!" (
		echo %YELLOW%[WARNING]%NC% MoAI-ADK version did not change after update attempt ^(!AFTER_MOAI_VERSION!^)
	)
	call :record_moai_install_path
	if errorlevel 1 (
		echo %YELLOW%[WARNING]%NC% MoAI-ADK installed but ownership marker could not be written.
	)
	exit /b 0

:install_tool_npm
	if /I "!inst!"=="Not Installed" goto install_tool_npm_install
	goto install_tool_npm_update

:install_tool_npm_install
		echo   Installing via npm...
		call :resolve_conda_npm
		if errorlevel 1 exit /b 1
		call :dbg   %BLUE%[DEBUG]%NC% run: "!CONDA_NPM!" install -g "!pkg!"
		call "!CONDA_NPM!" install -g "!pkg!"
		set "RC=%errorlevel%"
		if not "%RC%"=="0" exit /b %RC%
		exit /b 0

:install_tool_npm_update
		echo   Updating via npm...
		call :resolve_conda_npm
		if errorlevel 1 exit /b 1
		call :dbg   %BLUE%[DEBUG]%NC% run: "!CONDA_NPM!" install -g "!pkg!@latest"
		call "!CONDA_NPM!" install -g "!pkg!@latest"
		set "RC=%errorlevel%"
		if not "%RC%"=="0" exit /b %RC%
		exit /b 0

:install_oh_my_opencode
		set "PLUGIN_SPEC="
		call :get_oh_my_opencode_plugin_spec PLUGIN_SPEC
		if defined PLUGIN_SPEC (
			echo   oh-my-opencode already registered in opencode.json, skipping install.
			exit /b 0
		)
		echo   Installing oh-my-opencode plugin...
		set "OHMY_RUNNER="
		where bunx >nul 2>nul
		if not errorlevel 1 set "OHMY_RUNNER=bunx oh-my-opencode install %OHMY_FLAGS%"
		if not defined OHMY_RUNNER (
		    where npx >nul 2>nul
		    if not errorlevel 1 set "OHMY_RUNNER=npx oh-my-opencode install %OHMY_FLAGS%"
		)
		if not defined OHMY_RUNNER (
		    echo   %YELLOW%[WARNING]%NC% Skipping oh-my-opencode: bunx/npx not found
		    exit /b 0
		)
		for /f "tokens=1" %%r in ("%OHMY_RUNNER%") do set "OHMY_EXE=%%r"
		call :dbg   %BLUE%[DEBUG]%NC% run: %OHMY_RUNNER%
		call %OHMY_RUNNER% 2>nul
		if errorlevel 1 (
		    echo   %YELLOW%[WARNING]%NC% oh-my-opencode installer failed ^(command: %OHMY_RUNNER%^)
		) else (
		    echo   %GREEN%[SUCCESS]%NC% Installed oh-my-opencode via %OHMY_EXE%
		)
		exit /b 0
	
:remove_tool
	set "idx=%~1"
	call set "name=%%NAME_%idx%%%"
	call set "name=%%name%%"
call set "mgr=%%MGR_%idx%%%"
call set "mgr=%%mgr%%"
call set "pkg=%%PKG_%idx%%%"
call set "pkg=%%pkg%%"
call set "inst=%%INST_%idx%%%"
call set "inst=%%inst%%"

echo.
echo - !pkg!:
call :dbg   %BLUE%[DEBUG]%NC% mgr=!mgr! pkg=!pkg! installed=!inst!

REM Validate tool is installed
if "!inst!"=="Not Installed" (
    echo %RED%[ERROR]%NC% Cannot remove !name!: Not installed
    exit /b 1
)

if /I "!mgr!"=="npm-self" (
    REM npm cannot be removed
    echo %RED%[ERROR]%NC% Cannot remove !name!: npm is a core tool and cannot be removed
    exit /b 1
) else if /I "!mgr!"=="uv" (
    echo   Uninstalling via uv...
    call :dbg   %BLUE%[DEBUG]%NC% run: uv tool uninstall "!pkg!"
    call uv tool uninstall "!pkg!"
    exit /b %errorlevel%
	) else if /I "!mgr!"=="addon" (
	    echo   Removing addon...
	    if /I "!pkg!"=="oh-my-opencode" (
	        call :remove_oh_my_opencode
	        exit /b 0
	    )
	    echo %RED%[ERROR]%NC% Unknown addon: !pkg!
	    exit /b 1
) else if /I "!mgr!"=="native" (
    if /I "!pkg!"=="claude-code" (
        echo   Uninstalling native...
        call :dbg   %BLUE%[DEBUG]%NC% remove: %USERPROFILE%\.local\bin\claude.exe
        if exist "%USERPROFILE%\.local\bin\claude.exe" (
            del "%USERPROFILE%\.local\bin\claude.exe" >nul 2>nul
        )
        if exist "%USERPROFILE%\.local\share\claude" (
            rmdir /s /q "%USERPROFILE%\.local\share\claude" >nul 2>nul
        )
        REM Check if removal was successful
        if exist "%USERPROFILE%\.local\bin\claude.exe" (
            echo %RED%[ERROR]%NC% Failed to remove Claude Code binary
            exit /b 1
        )
    ) else if /I "!pkg!"=="moai-adk" (
        echo   Uninstalling native...
        if not exist "%MOAI_STATE_FILE%" (
            echo %RED%[ERROR]%NC% Missing MoAI ownership marker at "%MOAI_STATE_FILE%". Refusing unsafe uninstall.
            exit /b 1
        )
        set "MOAI_TARGET="
        set /p MOAI_TARGET=<"%MOAI_STATE_FILE%"
        if not defined MOAI_TARGET (
            echo %RED%[ERROR]%NC% MoAI ownership marker is empty. Refusing uninstall.
            exit /b 1
        )
        set "REMOVED=0"
        set "FAILED=0"
        if exist "!MOAI_TARGET!" (
            del "!MOAI_TARGET!" >nul 2>nul
            if errorlevel 1 set "FAILED=1"
            if exist "!MOAI_TARGET!" set "FAILED=1"
            if not exist "!MOAI_TARGET!" set "REMOVED=1"
        )
        for /f "delims=" %%p in ('where moai 2^>nul') do (
            if /I "%%p"=="!MOAI_TARGET!" set "FAILED=1"
        )
        del "%MOAI_STATE_FILE%" >nul 2>nul
        if errorlevel 1 set "FAILED=1"
        if "!FAILED!"=="1" (
            echo %RED%[ERROR]%NC% Failed to remove managed MoAI-ADK binary
            exit /b 1
        )
        if "!REMOVED!"=="0" (
            echo %RED%[ERROR]%NC% Managed MoAI-ADK binary was not found at "!MOAI_TARGET!"
            exit /b 1
        )
    )
    exit /b 0
) else (
	    echo   Uninstalling via npm...
	    call :resolve_conda_npm
	    if errorlevel 1 exit /b 1
	    call :dbg   %BLUE%[DEBUG]%NC% run: "!CONDA_NPM!" uninstall -g "!pkg!"
	    call "!CONDA_NPM!" uninstall -g "!pkg!"
	    set "RC=%errorlevel%"
	    exit /b %RC%
)

:remove_oh_my_opencode
    echo   Removing oh-my-opencode plugin...
    set "OHMY_RUNNER="
    where bunx >nul 2>nul
    if not errorlevel 1 set "OHMY_RUNNER=bunx oh-my-opencode uninstall --no-tui"
    if not defined OHMY_RUNNER (
        where npx >nul 2>nul
        if not errorlevel 1 set "OHMY_RUNNER=npx oh-my-opencode uninstall --no-tui"
    )
    if not defined OHMY_RUNNER (
        echo   %YELLOW%[WARNING]%NC% Skipping oh-my-opencode removal: bunx/npx not found
        exit /b 0
    )
    for /f "tokens=1" %%r in ("%OHMY_RUNNER%") do set "OHMY_EXE=%%r"
    call :dbg   %BLUE%[DEBUG]%NC% run: %OHMY_RUNNER%
    call %OHMY_RUNNER% 2>nul
    if errorlevel 1 (
        echo   %YELLOW%[WARNING]%NC% oh-my-opencode removal failed ^(command: %OHMY_RUNNER%^)
    ) else (
        echo   %GREEN%[SUCCESS]%NC% Removed oh-my-opencode via %OHMY_EXE%
    )
    exit /b 0

:get_installed_uv_version2
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
where uv >nul 2>nul
if errorlevel 1 exit /b 0

if "%UV_TOOL_LIST_READY%"=="0" (
    if not defined UV_TOOL_LIST_CACHE set "UV_TOOL_LIST_CACHE=%TEMP%\uv_tool_list_%RANDOM%.tmp"
    uv tool list >"!UV_TOOL_LIST_CACHE!" 2>nul
    set "UV_TOOL_LIST_READY=1"
)

for /f "tokens=*" %%v in ('findstr /R "^%pkg% *" "%UV_TOOL_LIST_CACHE%" 2^>nul') do (
    for /f "tokens=2" %%a in ("%%v") do set "%outvar%=%%a"
)
REM Remove 'v' prefix
if defined %outvar% (
    set "val=!%outvar%!"
    if "!val:~0,1!"=="v" set "%outvar%=!val:~1!"
)
exit /b 0

:get_installed_npm_version2
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
call :resolve_conda_npm
if errorlevel 1 exit /b 0

REM Prefer filesystem-based detection to avoid false positives from a stale npm list.
if "%NPM_ROOT_READY%"=="0" (
    for /f "delims=" %%d in ('"!CONDA_NPM!" root -g 2^>nul') do (
        if not "%%d"=="" set "NPM_ROOT_CACHE=%%d"
    )
    set "NPM_ROOT_READY=1"
)
if not defined NPM_ROOT_CACHE exit /b 0

set "pkg_dir="
if "%pkg:~0,1%"=="@" (
    for /f "tokens=1,2 delims=/" %%s in ("%pkg%") do (
        set "pkg_dir=!NPM_ROOT_CACHE!\%%s\%%t"
    )
) else (
    set "pkg_dir=!NPM_ROOT_CACHE!\%pkg%"
)

if not defined pkg_dir exit /b 0
if not exist "!pkg_dir!\package.json" exit /b 0

set "pkg_json=!pkg_dir!\package.json"
for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "$p='%pkg_json%'; try { $j = Get-Content -Raw $p | ConvertFrom-Json; if ($j -and $j.version) { $j.version } } catch { }"`) do (
    if not "%%v"=="" set "%outvar%=%%v"
)
exit /b 0

endlocal
