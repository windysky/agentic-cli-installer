@echo off
setlocal EnableDelayedExpansion

#############################################
# Agentic Coders Installer v1.0.0
# Interactive installer for AI coding CLI tools
# Windows version (run in Anaconda Prompt or CMD)
#############################################

REM ANSI color codes for Windows 10+
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "RED=%ESC%[31m"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "CYAN=%ESC%[36m"
set "BOLD=%ESC%[1m"
set "NC=%ESC%[0m"

REM Tool list: name|manager|package|description
set TOOLS_COUNT=7
set TOOL_1=moai-adk|uv|moai-adk|MoAI Agent Development Kit
set TOOL_2=@anthropic-ai/claude-code|npm|@anthropic-ai/claude-code|Claude Code CLI
set TOOL_3=@openai/codex|npm|@openai/codex|OpenAI Codex CLI
set TOOL_4=@google/gemini-cli|npm|@google/gemini-cli|Google Gemini CLI
set TOOL_5=@google/jules|npm|@google/jules|Google Jules CLI
set TOOL_6=opencode-ai|npm|opencode-ai|OpenCode AI CLI
set TOOL_7=mistral-vibe|uv|mistral-vibe|Mistral Vibe CLI

REM Action states: 0=skip, 1=install, 2=remove
set ACTION_SKIP=0
set ACTION_INSTALL=1
set ACTION_REMOVE=2

REM Initialize tool data arrays
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    set "SEL_%%i=0"
    set "ACT_%%i=0"
)

REM Cached version data to avoid repeated slow calls
set "UV_TOOL_LIST_READY=0"
set "UV_TOOL_LIST_CACHE="
set "NPM_LIST_JSON_READY=0"
set "NPM_LIST_JSON_CACHE="
set "LATEST_CACHE_DIR="

REM Load tool definitions
set "NAME_1=MoAI Agent Development Kit"
set "MGR_1=uv"
set "PKG_1=moai-adk"
set "DESC_1=MoAI Agent Development Kit"

set "NAME_2=Claude Code CLI"
set "MGR_2=npm"
set "PKG_2=@anthropic-ai/claude-code"
set "DESC_2=Claude Code CLI"

set "NAME_3=OpenAI Codex CLI"
set "MGR_3=npm"
set "PKG_3=@openai/codex"
set "DESC_3=OpenAI Codex CLI"

set "NAME_4=Google Gemini CLI"
set "MGR_4=npm"
set "PKG_4=@google/gemini-cli"
set "DESC_4=Google Gemini CLI"

set "NAME_5=Google Jules CLI"
set "MGR_5=npm"
set "PKG_5=@google/jules"
set "DESC_5=Google Jules CLI"

set "NAME_6=OpenCode AI CLI"
set "MGR_6=npm"
set "PKG_6=opencode-ai"
set "DESC_6=OpenCode AI CLI"

set "NAME_7=Mistral Vibe CLI"
set "MGR_7=uv"
set "PKG_7=mistral-vibe"
set "DESC_7=Mistral Vibe CLI"

#############################################
# MAIN EXECUTION
#############################################

call :check_conda_environment
if errorlevel 1 exit /b 1

call :check_curl
if errorlevel 1 exit /b 1

call :initialize_tools

:menu_loop
call :render_menu

echo.
echo %CYAN%Enter selection (numbers, Q to quit, Enter to proceed):%NC%
set /p input=""

REM Trim spaces
for /f "tokens=* delims= " %%a in ("%input%") do set "input=%%a"

REM Check for quit
if /I "%input%"=="Q" (
    echo %BLUE%[INFO]%NC% Exiting without changes.
    exit /b 0
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

call :check_dependencies
if errorlevel 1 exit /b 1

goto run_installation

:run_installation
call :run_installation
echo.
echo %GREEN%%BOLD%Installation complete!%NC%
echo.
exit /b 0

#############################################
# UTILITY FUNCTIONS
#############################################

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
    set "sel=!ACT_%%i!"
    if "!sel!" neq "0" set /a count+=1
)
if %count%==0 (
    echo %YELLOW%[WARNING]%NC% No tools selected. Please select at least one tool or press Q to quit.
    pause
    exit /b 1
)
echo %GREEN%[SUCCESS]%NC% Starting installation/upgrade of %count% tool^(s^)...
exit /b 0

:print_sep
set "sep="
for /L %%i in (1,1,80) do set "sep=!sep!─"
echo %CYAN%!sep!%NC%
exit /b 0

#############################################
# VERSION QUERY FUNCTIONS
#############################################

:get_installed_uv_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
where uv >nul 2>nul
if errorlevel 1 exit /b 0

if "%UV_TOOL_LIST_READY%"=="0" (
    if not defined UV_TOOL_LIST_CACHE set "UV_TOOL_LIST_CACHE=%TEMP%\uv_tool_list_%RANDOM%.tmp"
    uv tool list >"%UV_TOOL_LIST_CACHE%" 2>nul
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

:get_installed_npm_version
set "pkg=%~1"
set "outvar=%~2"
set "%outvar%="
where npm >nul 2>nul
if errorlevel 1 exit /b 0

if "%NPM_LIST_JSON_READY%"=="0" (
    if not defined NPM_LIST_JSON_CACHE set "NPM_LIST_JSON_CACHE=%TEMP%\npm_list_%RANDOM%.json"
    npm list -g --depth=0 --json >"%NPM_LIST_JSON_CACHE%" 2>nul
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
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $uri = 'https://pypi.org/pypi/%pkg%/json'; $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 8 -ErrorAction Stop; if ($result -and $result.info -and $result.info.version) { $version = $result.info.version } } catch { } $attempt++ } if ($version) { Write-Output $version }" >"%tmpfile%" 2>nul
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
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $uri = 'https://registry.npmjs.org/%pkg%/latest'; $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 5 -ErrorAction Stop; if ($result -and $result.version) { $version = $result.version } } catch { } $attempt++ } if ($version) { Write-Output $version }" >"%tmpfile%" 2>nul
if exist "%tmpfile%" (
    for /f "usebackq delims=" %%v in ("%tmpfile%") do (
        if not "%%v"=="" set "%outvar%=%%v"
    )
    del "%tmpfile%" >nul 2>nul
)
exit /b 0

#############################################
# INITIALIZATION
#############################################

:initialize_tools
call :prefetch_latest_versions
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call :init_tool %%i
)
if defined LATEST_CACHE_DIR (
    rd /s /q "%LATEST_CACHE_DIR%" >nul 2>nul
)
REM Clear the progress line
echo                                                                                 %NC%
exit /b 0

:init_tool
set "idx=%~1"
set "mgr=!MGR_%idx%!"
set "pkg=!PKG_%idx%!"
set "desc=!DESC_%idx%!"

REM Show progress
<nul set /p "=%BLUE%[INFO]%NC% Checking: %CYAN%!desc!                                                                                  %NC%"

if "!mgr!"=="uv" (
    call :get_installed_uv_version "!pkg!" INST
) else (
    call :get_installed_npm_version "!pkg!" INST
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

REM Set default action based on status
if "!INST!"=="Not Installed" (
    set "ACT_%idx%=1"
    set "SEL_%idx%=1"
) else if "!INST!" neq "!LATEST!" (
    set "ACT_%idx%=1"
    set "SEL_%idx%=1"
) else (
    set "ACT_%idx%=0"
    set "SEL_%idx%=0"
)
exit /b 0

:prefetch_latest_versions
set "LATEST_CACHE_DIR=%TEMP%\agentic_latest_%RANDOM%"
md "%LATEST_CACHE_DIR%" >nul 2>nul
set "LATEST_LIST_FILE=%LATEST_CACHE_DIR%\tools.txt"
> "%LATEST_LIST_FILE%" (
    for /L %%i in (1,1,%TOOLS_COUNT%) do (
        echo %%i^|!MGR_%%i!^|!PKG_%%i!
    )
)

powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $tools = Get-Content -Path '%LATEST_LIST_FILE%'; $jobs = @(); foreach ($line in $tools) { if (-not $line) { continue } $parts = $line -split '\|', 3; $idx = $parts[0]; $mgr = $parts[1]; $pkg = $parts[2]; if ($mgr -eq 'uv') { $uri = \"https://pypi.org/pypi/$pkg/json\"; $jobs += Start-Job -ArgumentList $uri, '%LATEST_CACHE_DIR%', $idx -ScriptBlock { param($uri, $dir, $idx) $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 8 -ErrorAction Stop; if ($result -and $result.info -and $result.info.version) { $version = $result.info.version } } catch { } $attempt++ } if ($version) { Set-Content -Path (Join-Path $dir (\"latest_\" + $idx + \".txt\")) -Value $version } } } else { $uri = \"https://registry.npmjs.org/$pkg/latest\"; $jobs += Start-Job -ArgumentList $uri, '%LATEST_CACHE_DIR%', $idx -ScriptBlock { param($uri, $dir, $idx) $attempt = 0; $version = $null; while ($attempt -lt 2 -and -not $version) { try { $result = Invoke-RestMethod -UseBasicParsing -Uri $uri -TimeoutSec 5 -ErrorAction Stop; if ($result -and $result.version) { $version = $result.version } } catch { } $attempt++ } if ($version) { Set-Content -Path (Join-Path $dir (\"latest_\" + $idx + \".txt\")) -Value $version } } } } Wait-Job $jobs | Out-Null; Receive-Job $jobs | Out-Null; Remove-Job $jobs | Out-Null;" >nul 2>nul

if exist "%LATEST_LIST_FILE%" del "%LATEST_LIST_FILE%" >nul 2>nul
exit /b 0

#############################################
# MENU RENDERING
#############################################

:render_menu
cls
echo.
echo %CYAN%%BOLD%Agentic Coders CLI Installer%NC% %BOLD%v1.0.0%NC%
echo.
echo Toggle tools: %CYAN%skip%NC% -^> %GREEN%install%NC% -^> %RED%remove%NC% (press number multiple times^)
echo Numbers are %BOLD%comma-separated%NC% (e.g., %CYAN%1,3,5%NC%^). Press %BOLD%Enter%NC% to proceed, %BOLD%Q%NC% to quit.
echo.
call :print_sep

echo   #  %-30s     %14s %10s  %10s  Select
echo                               Installed       Latest     Action
call :print_sep

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    call :print_tool %%i
)
call :print_sep
exit /b 0

:print_tool
set "idx=%~1"
set "num=%idx%"
set "name=!NAME_%idx%!"
set "inst=!INST_%idx%!"
set "lat=!LAT_%idx%!"
set "act=!ACT_%idx%!"

REM Map action to display values
if "!act!"=="0" (
    set "actname=skip"
    set "actcol=%CYAN%"
    set "chk=[ ]"
    set "chkcol=%CYAN%"
) else if "!act!"=="1" (
    set "actname=install"
    set "actcol=%GREEN%"
    set "chk=[✓]"
    set "chkcol=%GREEN%"
) else (
    set "actname=remove"
    set "actcol=%RED%"
    set "chk=[✗]"
    set "chkcol=%RED%"
)

REM Determine installed color
if "!inst!"=="Not Installed" (
    set "instcol=%RED%"
) else if "!inst!"=="!lat!" (
    set "instcol=%GREEN%"
) else (
    set "instcol=%YELLOW%"
)

REM Format and print line with colors
set "sp1=                   "
set "sp2=              "
set "sp3=          "

echo  %BOLD%!num!%NC%  !name!!sp1:~0,-30!!instcol!!inst!!NC!!sp2:~0,-14!!lat!!sp3:~0,-10!!actcol!!actname!!NC!  !chkcol!!chk!%NC%
exit /b 0

#############################################
# USER INPUT HANDLING
#############################################

:parse_selection
set "input=%~1"
set "input=%input:,= "

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
set /a "numVal=%num%" 2>nul
if %numVal% LSS 1 goto invalid
if %numVal% GTR %TOOLS_COUNT% goto invalid

set "idx=%numVal%"
set "cur=!ACT_%idx%!"
set "inst=!INST_%idx%!"
set "lat=!LAT_%idx%!"

REM Determine tool state and valid transitions
REM State 1: Not Installed - can only install or skip (no remove)
REM State 2: Up-to-date (installed == latest) - can only remove or skip (no install)
REM State 3: Outdated (installed != latest) - can install, update, or remove

set "not_installed=0"
set "up_to_date=0"

if "!inst!"=="Not Installed" (
    set "not_installed=1"
) else if "!inst!"=="!lat!" (
    set "up_to_date=1"
)

REM Cycle based on current action and tool state
if "!cur!"=="0" (
    REM Currently skip
    if "!not_installed!"=="1" (
        REM Not installed: skip -> install
        set "ACT_%idx%=1"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for install: !NAME_%idx%!
    ) else if "!up_to_date!"=="1" (
        REM Up-to-date: skip -> remove
        set "ACT_%idx%=2"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for removal: !NAME_%idx%!
    ) else (
        REM Outdated: skip -> install
        set "ACT_%idx%=1"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for update: !NAME_%idx%!
    )
) else if "!cur!"=="1" (
    REM Currently install
    if "!not_installed!"=="1" (
        REM Not installed: install -> skip (no remove option)
        set "ACT_%idx%=0"
        set "SEL_%idx%=0"
        echo %BLUE%[INFO]%NC% Deselected: !NAME_%idx%!
    ) else (
        REM Installed (outdated): install -> remove
        set "ACT_%idx%=2"
        set "SEL_%idx%=1"
        echo %BLUE%[INFO]%NC% Selected for removal: !NAME_%idx%!
    )
) else (
    REM Currently remove - always goes to skip
    set "ACT_%idx%=0"
    set "SEL_%idx%=0"
    echo %BLUE%[INFO]%NC% Deselected: !NAME_%idx%!
)
exit /b 0

:invalid
echo %RED%[ERROR]%NC% Invalid selection: %num%
exit /b 1

#############################################
# ACTION SUMMARY AND CONFIRMATION
#############################################

:display_action_summary
set "install_count=0"
set "remove_count=0"
set "install_tools="
set "remove_tools="

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    set "act=!ACT_%%i!"
    if "!act!"=="1" (
        set /a install_count+=1
        if defined install_tools set "install_tools=!install_tools!, "
        set "install_tools=!install_tools!!NAME_%%i!"
    ) else if "!act!"=="2" (
        set /a remove_count+=1
        if defined remove_tools set "remove_tools=!remove_tools!, "
        set "remove_tools=!remove_tools!!NAME_%%i!"
    )
)

call :print_sep
echo.
echo %CYAN%%BOLD%Action Summary%NC%
call :print_sep
echo   %GREEN%Install%NC%: %install_count% tools
if !install_count! GTR 0 echo     (!install_tools!^)

if !remove_count! GTR 0 (
    echo   %RED%Remove%NC%: %remove_count% tools
    echo     (!remove_tools!^)
    call :print_sep
    echo.
    echo %RED%%BOLD%WARNING: You are about to remove '%remove_tools%'%NC%
    echo %RED%%BOLD%This action cannot be undone.%NC%
    echo.
)
exit /b 0

:confirm_removals
set "has_removals=0"
for /L %%i in (1,1,%TOOLS_COUNT%) do (
    if "!ACT_%%i!"=="2" set "has_removals=1"
)

if "!has_removals!"=="1" (
    echo Proceed? (y/N):
    set /p response=""
    if /I not "%response%"=="y" (
        if /I not "%response%"=="yes" (
            echo %YELLOW%[WARNING]%NC% Cancelled by user
            exit /b 1
        )
    )
)
exit /b 0

#############################################
# DEPENDENCY CHECKS
#############################################

:check_dependencies
set "missing="

for /L %%i in (1,1,%TOOLS_COUNT%) do (
    set "act=!ACT_%%i!"
    if "!act!"=="1" (
        set "mgr=!MGR_%%i!"
        if "!mgr!"=="uv" (
            where uv >nul 2>nul
            if errorlevel 1 set "missing=!missing! uv (required for !NAME_%%i!^)"
        ) else if "!mgr!"=="npm" (
            where npm >nul 2>nul
            if errorlevel 1 set "missing=!missing! npm (required for !NAME_%%i!^)"
        )
    )
)

if defined missing (
    echo %RED%[ERROR]%NC% Missing required dependencies:
    for %%d in (!missing!) do echo   - %RED%%%d%NC%
    echo.
    echo Install missing dependencies:
    echo   %CYAN%uv%NC%:   %YELLOW%https://github.com/astral-sh/uv#installing-uv%NC%
    echo   %CYAN%npm%NC%:   %YELLOW%https://docs.npmjs.com/downloading-and-installing-node-js-and-npm%NC%
    exit /b 1
)
exit /b 0

#############################################
# INSTALLATION FUNCTIONS
#############################################

:run_installation
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
    set "act=!ACT_%%i!"
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
echo   %GREEN%Installed%NC%: %install_success%
if %install_fail% GTR 0 echo   %RED%Install Failed%NC%: %install_fail%
echo   %GREEN%Removed%NC%: %remove_success%
if %remove_fail% GTR 0 echo   %RED%Remove Failed%NC%: %remove_fail%
call :print_sep
exit /b 0

:install_tool
set "idx=%~1"
set "name=!NAME_%idx%!"
set "mgr=!MGR_%idx%!"
set "pkg=!PKG_%idx%!"
set "inst=!INST_%idx%!"

echo.
echo %CYAN%Processing: !name!%NC%

if "!mgr!"=="uv" (
    if "!inst!"=="Not Installed" (
        echo   Installing !pkg!...
        call uv tool install "!pkg!"
    ) else (
        echo   Updating !pkg!...
        call uv tool update "!pkg!"
    )
) else (
    if "!inst!"=="Not Installed" (
        echo   Installing !pkg!...
        call npm install -g "!pkg!"
    ) else (
        echo   Updating !pkg!...
        call npm install -g "!pkg!@latest"
    )
)
exit /b %errorlevel%

:remove_tool
set "idx=%~1"
set "name=!NAME_%idx%!"
set "mgr=!MGR_%idx%!"
set "pkg=!PKG_%idx%!"
set "inst=!INST_%idx%!"

echo.
echo %CYAN%Processing: !name!%NC%

REM Validate tool is installed
if "!inst!"=="Not Installed" (
    echo %RED%[ERROR]%NC% Cannot remove !name!: Not installed
    exit /b 1
)

if "!mgr!"=="uv" (
    echo   Uninstalling !pkg!...
    call uv tool uninstall "!pkg!"
) else (
    echo   Uninstalling !pkg!...
    call npm uninstall -g "!pkg!"
)
exit /b %errorlevel%

endlocal
