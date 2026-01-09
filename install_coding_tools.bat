@echo off
setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"

REM ###############################################
REM Agentic Coders Installer v1.1.0
REM Interactive installer for AI coding CLI tools
REM Windows version (run in Anaconda Prompt or CMD)
REM ###############################################

REM Runtime flags (also configurable via env vars):
REM   --debug         Enable verbose tracing and write a log file
REM   --log <path>    Write debug log to a specific file
REM   --color         Force-enable ANSI colors
REM   --no-color      Disable ANSI colors
REM   --no-prefetch   Skip latest-version prefetch (faster, fewer moving parts)
set "DEBUG=0"
REM Default to color; if ANSI detection fails we fall back to no-color automatically.
set "NO_COLOR=0"
set "NO_PREFETCH=0"
set "LOGFILE="

if /I "%AGENTIC_DEBUG%"=="1" set "DEBUG=1"
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
set "MIN_NPM_VERSION=9.0.0"

REM Tool list: name|manager|package|description
set TOOLS_COUNT=7
set "TOOL_1=moai-adk|uv|moai-adk|MoAI Agent Development Kit"
set "TOOL_2=@anthropic-ai/claude-code|npm|@anthropic-ai/claude-code|Claude Code CLI"
set "TOOL_3=@openai/codex|npm|@openai/codex|OpenAI Codex CLI"
set "TOOL_4=@google/gemini-cli|npm|@google/gemini-cli|Google Gemini CLI"
set "TOOL_5=@google/jules|npm|@google/jules|Google Jules CLI"
set "TOOL_6=opencode-ai|npm|opencode-ai|OpenCode AI CLI"
set "TOOL_7=mistral-vibe|uv|mistral-vibe|Mistral Vibe CLI"

REM Action states: 0=skip, 1=install, 2=remove
set ACTION_SKIP=0
set ACTION_INSTALL=1
set ACTION_REMOVE=2

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

REM Load tool definitions
set "NAME_1=MoAI Agent Development Kit"
set "MGR_1=uv"
set "PKG_1=moai-adk"
set "DESC_1=MoAI Agent Development Kit"
set "BIN_1=moai-adk"
set "VERARG_1=--version"

set "NAME_2=Claude Code CLI"
set "MGR_2=npm"
set "PKG_2=@anthropic-ai/claude-code"
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

set "NAME_7=Mistral Vibe CLI"
set "MGR_7=uv"
set "PKG_7=mistral-vibe"
set "DESC_7=Mistral Vibe CLI"
set "BIN_7=vibe"
set "VERARG_7=--version"

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

call :dbg %BLUE%[STEP]%NC% ensure_npm_prerequisite
call :ensure_npm_prerequisite
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    call :die "ensure_npm_prerequisite" "%RC%"
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

:menu_loop
call :render_menu

echo.
echo %CYAN%Enter selection (numbers, Enter to proceed, P if Enter fails, Q to quit):%NC%
REM Robust input handling:
REM - If user presses Enter: input becomes empty and we treat it as "proceed".
REM - If STDIN is closed/EOF (common when piped input runs out): keep a sentinel and exit safely.
set "INPUT_SENTINEL=__EOF__%RANDOM%%RANDOM%"
set "input=!INPUT_SENTINEL!"
set /p input=""
if "!input!"=="!INPUT_SENTINEL!" (
    echo %YELLOW%[WARNING]%NC% This terminal cannot submit an empty line here.
    echo %YELLOW%[WARNING]%NC% Type %CYAN%P%NC% to proceed, or %CYAN%Q%NC% to quit.
    goto menu_loop
)

REM Use the first token so trailing spaces don't break quit detection.
set "first="
for /f "tokens=1" %%a in ("%input%") do set "first=%%a"
if not defined first set "input="

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

REM Check for proceed (empty)
if "%input%"=="" (
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
call :log
call :log %BLUE%[INFO]%NC% Executable resolution (where):
where cmd 1>>"%LOGFILE%" 2>&1
where cmd
where npm 1>>"%LOGFILE%" 2>&1
where npm
where uv 1>>"%LOGFILE%" 2>&1
where uv
where curl 1>>"%LOGFILE%" 2>&1
where curl
where powershell 1>>"%LOGFILE%" 2>&1
where powershell
call :log
exit /b 0

:ensure_npm_prerequisite
call :dbg %BLUE%[DEBUG]%NC% enter ensure_npm_prerequisite
set "has_npm_tool=0"
set "NPM_VERSION="
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "MGR_CHECK=%%MGR_%%i%%"
    if /I "!MGR_CHECK!"=="npm" set "has_npm_tool=1"
)

call :dbg %BLUE%[DEBUG]%NC% has_npm_tool=!has_npm_tool!
if "!has_npm_tool!"=="0" exit /b 0

call :dbg %BLUE%[DEBUG]%NC% checking `where npm`
where npm >nul 2>nul
if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% npm is not installed but required for npm-managed tools.
    REM Check if we're in a conda environment
    if defined CONDA_DEFAULT_ENV (
        echo Attempting to install Node.js + npm via conda...
        call conda install -y -c conda-forge nodejs
        if errorlevel 1 (
            echo %RED%[ERROR]%NC% Failed to install Node.js via conda.
            echo Install Node.js + npm manually:
            echo   %CYAN%Windows%NC%: %YELLOW%https://nodejs.org/en/download%NC%
            echo   %CYAN%Via winget%NC%: %YELLOW%winget install OpenJS.NodeJS%NC%
            exit /b 1
        )
        REM Refresh PATH to pick up newly installed npm
        call :dbg %BLUE%[DEBUG]%NC% checking `where npm` after conda install
        where npm >nul 2>nul
        if errorlevel 1 (
            echo %RED%[ERROR]%NC% npm installation via conda appeared successful but npm is still not available.
            exit /b 1
        )
        echo %GREEN%[SUCCESS]%NC% npm installed via conda
    ) else (
        echo Install Node.js + npm before continuing:
        echo   %CYAN%Windows%NC%: %YELLOW%https://nodejs.org/en/download%NC%
        echo   %CYAN%Via winget%NC%: %YELLOW%winget install OpenJS.NodeJS%NC%
        exit /b 1
    )
)

call :dbg %BLUE%[DEBUG]%NC% querying `npm --version`
for /f "delims=" %%v in ('npm --version 2^>nul') do (
    if not "%%v"=="" set "NPM_VERSION=%%v"
)

call :dbg %BLUE%[DEBUG]%NC% NPM_VERSION=!NPM_VERSION!
if not defined NPM_VERSION (
    echo %RED%[ERROR]%NC% Unable to determine npm version.
    exit /b 1
)

	powershell -NoProfile -Command "try { if ([version]'%NPM_VERSION%' -ge [version]'%MIN_NPM_VERSION%') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
	if errorlevel 1 (
	    echo %RED%[ERROR]%NC% npm version %NPM_VERSION% is below required %MIN_NPM_VERSION%.
	    echo Please update npm and re-run:
	    echo   %CYAN%npm install -g npm@latest%NC%
	    exit /b 1
	) else (
	    echo %BLUE%[INFO]%NC% npm version %NPM_VERSION% detected. Minimum required: %MIN_NPM_VERSION%.
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
echo %GREEN%[SUCCESS]%NC% Starting installation/upgrade of !count! tool^(s^)...
exit /b 0

:print_sep
REM ASCII separator to avoid mojibake in different Windows code pages.
set "sep=--------------------------------------------------------------------------------"
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
REM Use the extract_semver.ps1 script in the same directory as this batch file.
set "SEMVER_EXTRACTOR=%~dp0extract_semver.ps1"
for /f "delims=" %%v in ('%ComSpec% /d /c ""%bin%" %verarg% 2^>^&1" ^| powershell -NoProfile -ExecutionPolicy Bypass -File "%SEMVER_EXTRACTOR%"') do (
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
where npm >nul 2>nul
if errorlevel 1 exit /b 0

if "%NPM_LIST_JSON_READY%"=="0" (
    if not defined NPM_LIST_JSON_CACHE set "NPM_LIST_JSON_CACHE=%TEMP%\npm_list_%RANDOM%.json"
    npm list -g --depth=0 --json >"!NPM_LIST_JSON_CACHE!" 2>nul
    set "NPM_LIST_JSON_READY=1"
)

for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "$path='%NPM_LIST_JSON_CACHE%'; if (Test-Path $path) { $json = Get-Content -Raw $path; if ($json) { $obj = $json | ConvertFrom-Json; $dep = $obj.dependencies.'%pkg%'; if ($dep -and $dep.version) { $dep.version } } }"`) do (
    if not "%%v"=="" set "%outvar%=%%v"
)
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
where npm >nul 2>nul
if errorlevel 1 exit /b 0
for /f "delims=" %%v in ('npm --version 2^>nul') do (
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

REM ###############################################
REM INITIALIZATION
REM ###############################################

:initialize_tools
REM Check if npm exists and add it as update-only tool at the top
set "HAS_NPM=0"
where npm >nul 2>nul
if not errorlevel 1 (
    set "HAS_NPM=1"
    REM Shift all existing tools up by 1
    REM TOOLS_COUNT is still 7 at this point, so we loop from 7 down to 1
    for /L %%i in (7,-1,1) do (
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
    set "NAME_1=npm (Node Package Manager)"
    set "MGR_1=npm-self"
    set "PKG_1=npm"
    set "DESC_1=npm (Node Package Manager)"
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
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    set "idx=%%i"
    call set "mgr=%%MGR_%%i%%"
    call set "mgr=%%mgr%%"
    call set "pkg=%%PKG_%%i%%"
    call set "pkg=%%pkg%%"
    call :prefetch_one_tool "!idx!" "!mgr!" "!pkg!"
)
if exist "!LATEST_LIST_FILE!" del "!LATEST_LIST_FILE!" >nul 2>nul

:skip_prefetch
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call :init_tool %%i
)
if defined LATEST_CACHE_DIR (
    rd /s /q "%LATEST_CACHE_DIR%" >nul 2>nul
)
REM Clear the progress line
echo.
exit /b 0

:prefetch_one_tool
set "p_idx=%~1"
set "p_mgr=%~2"
set "p_pkg=%~3"
set "VERSION="

REM Use PowerShell with built-in timeout (no external process killing)
if /I "!p_mgr!"=="uv" (
    for /f "delims=" %%v in ('powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { $result=Invoke-RestMethod -UseBasicParsing -Uri 'https://pypi.org/pypi/%p_pkg%/json' -TimeoutSec 10; if($result-and$result.info-and$result.info.version){Write-Output $result.info.version} } catch { }" 2^>^&1') do (
        if not "%%v"=="" set "VERSION=%%v"
    )
) else if /I "!p_mgr!"=="npm-self" (
    for /f "delims=" %%v in ('powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { $result=Invoke-RestMethod -UseBasicParsing -Uri 'https://registry.npmjs.org/npm/latest' -TimeoutSec 10; if($result-and$result.version){Write-Output $result.version} } catch { }" 2^>^&1') do (
        if not "%%v"=="" set "VERSION=%%v"
    )
) else (
    for /f "delims=" %%v in ('powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { $result=Invoke-RestMethod -UseBasicParsing -Uri 'https://registry.npmjs.org/%p_pkg%/latest' -TimeoutSec 10; if($result-and$result.version){Write-Output $result.version} } catch { }" 2^>^&1') do (
        if not "%%v"=="" set "VERSION=%%v"
    )
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
) else if "!INST!" neq "!LATEST!" (
    set "ACT_%idx%=1"
    set "SEL_%idx%=1"
) else (
    set "ACT_%idx%=0"
    set "SEL_%idx%=0"
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
echo.
echo %CYAN%%BOLD%Agentic Coders CLI Installer%NC% %BOLD%v1.1.0%NC%
echo.
echo Toggle tools: %CYAN%skip%NC% -^> %GREEN%install%NC% -^> %RED%remove%NC% (press number multiple times^)
echo Numbers are %BOLD%comma-separated%NC% (e.g., %CYAN%1,3,5%NC%^). Press %BOLD%Q%NC% to quit.
echo.
call :print_sep
echo   #  Tool Name                      Installed       Latest     Action  Select
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
exit /b 0

:cycle_selection
set "num=%~1"
if not defined num goto invalid
echo(!num!| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 goto invalid
set /a "numVal=num" >nul 2>nul
if %numVal% LSS 1 goto invalid
if %numVal% GTR %TOOLS_COUNT% goto invalid

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
echo %RED%[ERROR]%NC% Invalid selection: "%num%" (use numbers 1-%TOOLS_COUNT%)
exit /b 1

REM ###############################################
REM ACTION SUMMARY AND CONFIRMATION
REM ###############################################

:display_action_summary
set "install_count=0"
set "remove_count=0"
set "install_tools="
set "remove_tools="

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call set "act=%%ACT_%%i%%"
    call set "act=%%act%%"
    call set "name=%%NAME_%%i%%"
    call set "name=%%name%%"
    if "!act!"=="1" (
        set /a install_count+=1
        if defined install_tools set "install_tools=!install_tools!, "
        set "install_tools=!install_tools!!name!"
    ) else if "!act!"=="2" (
        set /a remove_count+=1
        if defined remove_tools set "remove_tools=!remove_tools!, "
        set "remove_tools=!remove_tools!!name!"
    )
)

call :print_sep
echo.
echo %CYAN%%BOLD%Action Summary%NC%
call :print_sep
set "install_word=tools"
if !install_count! EQU 1 set "install_word=tool"
echo   %GREEN%Install%NC%: !install_count! !install_word!
if !install_count! GTR 0 echo     !install_tools!

if !remove_count! GTR 0 (
    set "remove_word=tools"
    if !remove_count! EQU 1 set "remove_word=tool"
    echo   %RED%Remove%NC%: !remove_count! !remove_word!
    echo     !remove_tools!
    call :print_sep
    echo.
    echo %RED%%BOLD%WARNING: You are about to remove: !remove_tools!%NC%
    echo %RED%%BOLD%This action cannot be undone.%NC%
    echo.
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
            where npm >nul 2>nul
            if errorlevel 1 (
                set /a missing_count+=1
                set "missing_!missing_count!=npm (required for !name!^)"
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
    echo   %CYAN%npm%NC%:   %YELLOW%https://docs.npmjs.com/downloading-and-installing-node-js-and-npm%NC%
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

call :print_sep
echo.
echo %CYAN%%BOLD%Installation Progress%NC%
call :print_sep
echo.

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
call :print_sep
echo.
echo %CYAN%%BOLD%Installation Summary%NC%
call :print_sep
echo   %GREEN%Installed%NC%: !install_success!
if !install_fail! GTR 0 echo   %RED%Install Failed%NC%: !install_fail!
echo   %GREEN%Removed%NC%: !remove_success!
if !remove_fail! GTR 0 echo   %RED%Remove Failed%NC%: !remove_fail!
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
echo %CYAN%Processing: !name!%NC%
call :dbg   %BLUE%[DEBUG]%NC% mgr=!mgr! pkg=!pkg! installed=!inst!

if /I "!mgr!"=="npm-self" (
    REM npm can only be updated, not installed from scratch
    echo   Updating npm to latest version...
    call :dbg   %BLUE%[DEBUG]%NC% run: npm install -g npm@latest
    call npm install -g npm@latest
) else if /I "!mgr!"=="uv" (
    if /I "!inst!"=="Not Installed" (
        echo   Installing !pkg!...
        call :dbg   %BLUE%[DEBUG]%NC% run: uv tool install "!pkg!"
        call uv tool install "!pkg!"
    ) else (
        echo   Updating !pkg!...
        call :dbg   %BLUE%[DEBUG]%NC% run: uv tool update "!pkg!"
        call uv tool update "!pkg!"
    )
) else (
    if /I "!inst!"=="Not Installed" (
        echo   Installing !pkg!...
        call :dbg   %BLUE%[DEBUG]%NC% run: npm install -g "!pkg!"
        call npm install -g "!pkg!"
    ) else (
        echo   Updating !pkg!...
        call :dbg   %BLUE%[DEBUG]%NC% run: npm install -g "!pkg!@latest"
        call npm install -g "!pkg!@latest"
    )
)
exit /b %errorlevel%

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
echo %CYAN%Processing: !name!%NC%
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
    echo   Uninstalling !pkg!...
    call :dbg   %BLUE%[DEBUG]%NC% run: uv tool uninstall "!pkg!"
    call uv tool uninstall "!pkg!"
) else (
    echo   Uninstalling !pkg!...
    call :dbg   %BLUE%[DEBUG]%NC% run: npm uninstall -g "!pkg!"
    call npm uninstall -g "!pkg!"
)
exit /b %errorlevel%

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
where npm >nul 2>nul
if errorlevel 1 exit /b 0

REM Prefer filesystem-based detection to avoid false positives from a stale npm list.
if "%NPM_ROOT_READY%"=="0" (
    for /f "delims=" %%d in ('npm root -g 2^>nul') do (
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
