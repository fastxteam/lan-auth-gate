@echo off
chcp 65001
setlocal enabledelayedexpansion

title LanAuthGate Service Manager
set SERVICE_NAME=LanAuthGate
set WORKING_DIR=%~dp0
set APP_DIR=%WORKING_DIR%app
set EXE_PATH=%APP_DIR%\LanAuthGate.exe
set NSSM_EXE=%WORKING_DIR%\nssm\win64\nssm.exe

:menu
cls
echo.
echo ========================================
echo        LanAuthGate Service Manager
echo ========================================
echo Working Directory: %WORKING_DIR%
echo App Directory: %APP_DIR%
echo Program Path: %EXE_PATH%
echo.
echo Please select an option:
echo 1. Install and Start Service
echo 2. Start Service
echo 3. Stop Service
echo 4. Restart Service
echo 5. Check Service Status
echo 6. View Service Logs
echo 7. Uninstall Service
echo 8. Test Service Access
echo 9. System Diagnostics
echo 0. Exit
echo.
set /p choice=Enter your choice (0-9):

if "%choice%"=="1" goto install_service
if "%choice%"=="2" goto start_service
if "%choice%"=="3" goto stop_service
if "%choice%"=="4" goto restart_service
if "%choice%"=="5" goto status_service
if "%choice%"=="6" goto view_logs
if "%choice%"=="7" goto uninstall_service
if "%choice%"=="8" goto test_access
if "%choice%"=="9" goto diagnose
if "%choice%"=="0" goto exit

echo Invalid choice!
timeout /t 2 /nobreak >nul
goto menu

:install_service
cls
echo Installing and starting service...
echo.

REM Check administrator privileges
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo Please run this script as Administrator!
    pause
    goto menu
)

REM Check EXE file
if not exist "%EXE_PATH%" (
    echo Cannot find %EXE_PATH%
    echo Please ensure LanAuthGate.exe exists
    pause
    goto menu
)

REM Check NSSM
if not exist "%NSSM_EXE%" (
    echo Cannot find nssm.exe
    echo Please ensure nssm folder exists
    pause
    goto menu
)

echo Service Name: %SERVICE_NAME%
echo Working Directory: %WORKING_DIR%
echo App Directory: %APP_DIR%
echo Program Path: %EXE_PATH%

REM Check if service already exists
sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel! == 0 (
    echo Service already exists, removing old service...
    "%NSSM_EXE%" stop %SERVICE_NAME% confirm
    timeout /t 3 /nobreak >nul
    "%NSSM_EXE%" remove %SERVICE_NAME% confirm
    timeout /t 2 /nobreak >nul
)

echo Installing service...
"%NSSM_EXE%" install %SERVICE_NAME% "%EXE_PATH%"

if !errorlevel! neq 0 (
    echo Service installation failed!
    pause
    goto menu
)

echo Configuring service parameters...
"%NSSM_EXE%" set %SERVICE_NAME% DisplayName "LanAuthGate API Manager"
"%NSSM_EXE%" set %SERVICE_NAME% Description "API Authorization Manager and Monitoring System"
"%NSSM_EXE%" set %SERVICE_NAME% Start SERVICE_AUTO_START
"%NSSM_EXE%" set %SERVICE_NAME% AppDirectory "%APP_DIR%"
"%NSSM_EXE%" set %SERVICE_NAME% AppStdout "%APP_DIR%\service.log"
"%NSSM_EXE%" set %SERVICE_NAME% AppStderr "%APP_DIR%\service_error.log"
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateFiles 1
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateOnline 1
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateSeconds 86400
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateBytes 10485760

echo Starting service...
"%NSSM_EXE%" start %SERVICE_NAME%

timeout /t 5 /nobreak >nul

echo Checking service status...
call :check_service_status

pause
goto menu

:start_service
cls
echo Starting service...
"%NSSM_EXE%" start %SERVICE_NAME%
timeout /t 2 /nobreak >nul
goto status_service

:stop_service
cls
echo Stopping service...
"%NSSM_EXE%" stop %SERVICE_NAME%
timeout /t 2 /nobreak >nul
goto status_service

:restart_service
cls
echo Restarting service...
"%NSSM_EXE%" restart %SERVICE_NAME%
timeout /t 3 /nobreak >nul
goto status_service

:status_service
cls
echo Service Status:
"%NSSM_EXE%" status %SERVICE_NAME%
echo.
echo Process Information:
tasklist /fi "imagename eq LanAuthGate.exe" /fo table
echo.
echo Port Listening:
netstat -an | findstr ":8000"
pause
goto menu

:view_logs
cls
echo Service Logs:
if exist "%APP_DIR%service.log" (
    echo === service.log (last 20 lines) ===
    powershell "Get-Content '%APP_DIR%service.log' | Select-Object -Last 20"
) else (
    echo service.log not found
)

echo.
echo Error Logs:
if exist "%APP_DIR%service_error.log" (
    echo === service_error.log (last 20 lines) ===
    powershell "Get-Content '%APP_DIR%service_error.log' | Select-Object -Last 20"
) else (
    echo service_error.log not found
)
pause
goto menu

:uninstall_service
cls
echo Uninstalling service...
echo.

REM Check administrator privileges
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo Please run this script as Administrator!
    pause
    goto menu
)

REM Check if service exists
sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel! neq 0 (
    echo Service %SERVICE_NAME% does not exist
    pause
    goto menu
)

echo Stopping and removing service...
"%NSSM_EXE%" stop %SERVICE_NAME% confirm
timeout /t 3 /nobreak >nul
"%NSSM_EXE%" remove %SERVICE_NAME% confirm

echo Service uninstalled successfully!
pause
goto menu

:test_access
cls
echo Testing service access...
echo.
echo Testing http://localhost:8000 ...

REM Use PowerShell for testing
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8000' -TimeoutSec 3; Write-Host 'Service is accessible! Status code:' $response.StatusCode } catch { Write-Host 'Service is not accessible: ' $_.Exception.Message }"

echo.
echo Checking port status:
netstat -an | findstr ":8000"
pause
goto menu

:diagnose
cls
echo System Diagnostics...
echo.
echo 1. Service Status:
sc query %SERVICE_NAME%
echo.

echo 2. Process Check:
tasklist /fi "imagename eq LanAuthGate.exe"
echo.

echo 3. Port Check:
netstat -an | findstr ":8000"
echo.

echo 4. File Check:
if exist "%EXE_PATH%" (echo LanAuthGate.exe exists) else (echo LanAuthGate.exe missing)
if exist "%NSSM_EXE%" (echo nssm.exe exists) else (echo nssm.exe missing)
if exist "%APP_DIR%static" (echo static directory exists) else (echo static directory missing)
if exist "%APP_DIR%templates" (echo templates directory exists) else (echo templates directory missing)
echo.

echo 5. Log Files:
if exist "%APP_DIR%service.log" (
    echo service.log exists, last 5 lines:
    powershell "Get-Content '%APP_DIR%service.log' | Select-Object -Last 5"
) else (
    echo service.log does not exist
)
echo.
if exist "%APP_DIR%service_error.log" (
    echo service_error.log exists, last 5 lines:
    powershell "Get-Content '%APP_DIR%service_error.log' | Select-Object -Last 5"
) else (
    echo service_error.log does not exist
)

pause
goto menu

:check_service_status
REM Subroutine to check service status
sc query %SERVICE_NAME% | find "RUNNING" >nul
if !errorlevel! == 0 (
    echo Service is running normally!
    echo Access URL: http://localhost:8000
    echo Default password: admin123
    echo Log file: %APP_DIR%service.log
) else (
    echo Service is installed but may not be running properly
    echo Please check %APP_DIR%service_error.log for details
    echo.
    echo Common troubleshooting steps:
    echo 1. Check %APP_DIR%service_error.log content
    echo 2. Ensure all dependency files exist
    echo 3. Try running LanAuthGate.exe manually to test
)
goto :eof

:exit
cls
echo Goodbye!
echo Common command reference:
echo   Start service: nssm start %SERVICE_NAME%
echo   Stop service: nssm stop %SERVICE_NAME%
echo   Restart service: nssm restart %SERVICE_NAME%
echo   Service status: nssm status %SERVICE_NAME%
echo   Uninstall service: nssm remove %SERVICE_NAME%
echo.
pause
exit /b 0