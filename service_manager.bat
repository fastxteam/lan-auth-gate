@echo off
chcp 65001
setlocal enabledelayedexpansion

title LanAuthGate 服务管理器
set SERVICE_NAME=LanAuthGate
set WORKING_DIR=%~dp0
set DIST_DIR=%WORKING_DIR%dist
set WINDOWS_DIR=%DIST_DIR%\windows
set APP_DIR=%WINDOWS_DIR%\app
set EXE_PATH=%APP_DIR%\%SERVICE_NAME%.exe
set NSSM_EXE=%WINDOWS_DIR%\nssm\win64\nssm.exe

:menu
cls
echo.
echo ========================================
echo          🔧 LanAuthGate 服务管理器
echo ========================================
echo.
echo 请选择操作:
echo 1. 打包 EXE 文件
echo 2. 安装服务
echo 3. 启动服务
echo 4. 停止服务
echo 5. 重启服务
echo 6. 查看服务状态
echo 7. VIEW LOG
echo 8. 卸载服务
echo 9. 测试访问
echo 0. 退出
echo.
set /p choice=请输入选择 (0-9):

if "%choice%"=="1" goto build_exe
if "%choice%"=="2" goto install_service
if "%choice%"=="3" goto start_service
if "%choice%"=="4" goto stop_service
if "%choice%"=="5" goto restart_service
if "%choice%"=="6" goto status_service
if "%choice%"=="7" goto view_logs
if "%choice%"=="8" goto uninstall_service
if "%choice%"=="9" goto test_access
if "%choice%"=="0" goto exit

echo ❌ 无效选择！
timeout /t 2 /nobreak >nul
goto menu

:build_exe
cls
chcp 65001
echo 打包服务专用版本...

REM 安装稳定版本的 PyInstaller
pip install pyinstaller==5.13.2
REM 安装项目依赖
pip install -r requirements.txt

REM 清理旧构建
if exist "dist" rmdir /s /q "dist"
if exist "build" rmdir /s /q "build"

echo 📦 正在打包...
pyinstaller --onefile --console ^
  --add-data "static;static" ^
  --add-data "templates;templates" ^
  -F main.py

if %errorlevel% == 0 (
    echo 创建目录结构...
    if not exist "%WINDOWS_DIR%" mkdir "%WINDOWS_DIR%"
    if not exist "%APP_DIR%" mkdir "%APP_DIR%"
    if not exist "%WINDOWS_DIR%\nssm" mkdir "%WINDOWS_DIR%\nssm"

    echo 移动文件到新目录结构...
    move "dist\main.exe" "%EXE_PATH%" >nul

    echo 复制资源文件...
    xcopy static "%APP_DIR%\static" /E /I /Y >nul
    xcopy templates "%APP_DIR%\templates" /E /I /Y >nul
    xcopy nssm "%WINDOWS_DIR%\nssm" /E /I /Y >nul

    echo 复制数据库文件...
    if exist "api_auth.db" copy "api_auth.db" "%APP_DIR%\" >nul

    echo 创建部署脚本...
    if exist "service_deploy.bat" (
        copy "service_deploy.bat" "%WINDOWS_DIR%\deploy.bat" >nul
        echo 部署脚本已创建
    ) else (
        echo 警告: 未找到 service_deploy.bat
    )

    echo 创建日志目录...
    if not exist "%APP_DIR%\logs" mkdir "%APP_DIR%\logs"

    echo 服务专用版打包完成！
) else (
    echo 打包失败！
    pause
    exit /b 1
)

echo 所有文件已准备就绪！
echo 可执行文件: %EXE_PATH%
echo 部署脚本: %WINDOWS_DIR%\deploy.bat
echo 完整目录: %WINDOWS_DIR%

pause
goto menu

:install_service
cls
echo 🔧 安装服务...
echo.

REM 检查管理员权限
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo ❌ 请以管理员身份运行此脚本！
    pause
    goto menu
)

REM 检查 EXE 文件
if not exist "%EXE_PATH%" (
    echo ❌ 找不到 %EXE_PATH%
    echo 💡 请先选择选项 1 打包 EXE 文件
    pause
    goto menu
)

REM 检查 NSSM
if not exist "%NSSM_EXE%" (
    echo ❌ 找不到 nssm.exe
    echo 💡 请确保 nssm 文件夹存在
    pause
    goto menu
)

echo 📝 服务名称: %SERVICE_NAME%
echo 📁 工作目录: %APP_DIR%
echo 🚀 程序路径: %EXE_PATH%

REM 检查服务是否已存在
sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel! == 0 (
    echo ⚠️  服务已存在，正在卸载旧服务...
    "%NSSM_EXE%" stop %SERVICE_NAME% confirm
    timeout /t 3 /nobreak >nul
    "%NSSM_EXE%" remove %SERVICE_NAME% confirm
    timeout /t 2 /nobreak >nul
)

echo 🛠️  正在安装服务...
"%NSSM_EXE%" install %SERVICE_NAME% "%EXE_PATH%"

if !errorlevel! neq 0 (
    echo ❌ 服务安装失败！
    pause
    goto menu
)

echo ⚙️  配置服务参数...
"%NSSM_EXE%" set %SERVICE_NAME% DisplayName "LanAuthGate API授权管理器"
"%NSSM_EXE%" set %SERVICE_NAME% Description "API授权管理器和监控系统"
"%NSSM_EXE%" set %SERVICE_NAME% Start SERVICE_AUTO_START
"%NSSM_EXE%" set %SERVICE_NAME% AppDirectory "%APP_DIR%"
"%NSSM_EXE%" set %SERVICE_NAME% AppStdout "%APP_DIR%\service.log"
"%NSSM_EXE%" set %SERVICE_NAME% AppStderr "%APP_DIR%\service_error.log"
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateFiles 1
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateOnline 1
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateSeconds 86400
"%NSSM_EXE%" set %SERVICE_NAME% AppRotateBytes 10485760

echo 🚀 启动服务...
"%NSSM_EXE%" start %SERVICE_NAME%

timeout /t 5 /nobreak >nul

REM 检查服务状态
sc query %SERVICE_NAME% | find "RUNNING" >nul
if !errorlevel! == 0 (
    echo ✅ 服务安装并启动成功！
    echo 🌐 访问地址: http://localhost:8000
    echo 🔑 默认密码: admin123
) else (
    echo ⚠️  服务已安装但可能未正常运行
    echo 💡 请检查 %APP_DIR%\service_error.log 文件
)

pause
goto menu

:start_service
cls
echo 🚀 启动服务...
"%NSSM_EXE%" start %SERVICE_NAME%
timeout /t 2 /nobreak >nul
goto status_service

:stop_service
cls
echo ⏹️  停止服务...
"%NSSM_EXE%" stop %SERVICE_NAME%
timeout /t 2 /nobreak >nul
goto status_service

:restart_service
cls
echo 🔄 重启服务...
"%NSSM_EXE%" restart %SERVICE_NAME%
timeout /t 3 /nobreak >nul
goto status_service

:status_service
cls
echo 📊 服务状态:
"%NSSM_EXE%" status %SERVICE_NAME%
echo.
echo 🔍 进程信息:
tasklist /fi "imagename eq %SERVICE_NAME%.exe" /fo table
echo.
echo 🌐 端口监听:
netstat -an | findstr ":8000"
pause
goto menu

:view_logs
cls
echo 📋 服务日志:
if exist "%APP_DIR%\service.log" (
    echo === service.log (最后20行) ===
    powershell "Get-Content '%APP_DIR%\service.log' | Select-Object -Last 20"
) else (
    echo ❌ 未找到 service.log
)

echo.
echo 📋 错误日志:
if exist "%APP_DIR%\service_error.log" (
    echo === service_error.log (最后20行) ===
    powershell "Get-Content '%APP_DIR%\service_error.log' | Select-Object -Last 20"
) else (
    echo ❌ 未找到 service_error.log
)
pause
goto menu

:uninstall_service
cls
echo 🗑️  卸载服务...
echo.

REM 检查管理员权限
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo ❌ 请以管理员身份运行此脚本！
    pause
    goto menu
)

REM 检查服务是否存在
sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel! neq 0 (
    echo ⚠️  服务 %SERVICE_NAME% 不存在
    pause
    goto menu
)

echo ⚠️  正在停止并卸载服务...
"%NSSM_EXE%" stop %SERVICE_NAME% confirm
timeout /t 3 /nobreak >nul
"%NSSM_EXE%" remove %SERVICE_NAME% confirm

echo ✅ 服务已卸载完成！
pause
goto menu

:test_access
cls
echo 🌐 测试服务访问...
echo.
echo 正在测试 http://localhost:8000 ...

REM 使用 PowerShell 进行更可靠的测试
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8000' -TimeoutSec 3; Write-Host '✅ 服务可以正常访问！状态码:' $response.StatusCode } catch { Write-Host '❌ 服务无法访问: ' $_.Exception.Message }"

echo.
echo 🔍 检查端口状态：
netstat -an | findstr ":8000"
pause
goto menu

:exit
cls
echo 👋 再见！
echo.
pause
exit /b 0