@echo off
chcp 65001 >nul
set SERVICE_NAME=LanAuthGate
set SCRIPT_DIR=%~dp0

:menu
cls
echo ===============================================
echo        LanAuthGate Windows服务管理器
echo ===============================================
echo 脚本目录: %SCRIPT_DIR%
echo.
echo 当前服务状态:
sc query %SERVICE_NAME% | find "STATE" >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 服务已安装
) else (
    echo ❌ 服务未安装
)
echo.
echo 请选择操作:
echo 1. 安装服务
echo 2. 启动服务
echo 3. 停止服务
echo 4. 重启服务
echo 5. 查看服务状态
echo 6. 卸载服务
echo 7. 查看服务日志
echo 8. 打开日志目录
echo 9. 退出
echo.
set /p choice=请输入选择 [1-9]:

if "%choice%"=="1" goto install
if "%choice%"=="2" goto start
if "%choice%"=="3" goto stop
if "%choice%"=="4" goto restart
if "%choice%"=="5" goto status
if "%choice%"=="6" goto remove
if "%choice%"=="7" goto logs
if "%choice%"=="8" goto logdir
if "%choice%"=="9" goto exit

echo 无效选择，请重新输入
timeout /t 2 >nul
goto menu

:install
call "%SCRIPT_DIR%install_service.bat"
goto menu

:start
call "%SCRIPT_DIR%start_service.bat"
goto menu

:stop
call "%SCRIPT_DIR%stop_service.bat"
goto menu

:restart
echo 重启服务...
call "%SCRIPT_DIR%stop_service.bat"
timeout /t 3 >nul
call "%SCRIPT_DIR%start_service.bat"
goto menu

:status
call "%SCRIPT_DIR%check_service.bat"
goto menu

:remove
call "%SCRIPT_DIR%uninstall_service.bat"
goto menu

:logs
echo 最近的服务日志:
echo ==================================
if exist "..\logs\service.log" (
    type "..\logs\service.log" | more
) else (
    echo 日志文件不存在
)
echo ==================================
pause
goto menu

:logdir
echo 打开日志目录...
if exist "..\logs" (
    start "" "..\logs"
) else (
    echo 日志目录不存在
)
pause
goto menu

:exit
echo 退出服务管理器