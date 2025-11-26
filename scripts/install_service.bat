@echo off
chcp 65001 >nul
set SERVICE_NAME=LanAuthGate
set APP_PATH=%~dp0..\main.py
set SCRIPT_DIR=%~dp0

echo ===============================================
echo      LanAuthGate Windows服务安装程序
echo ===============================================
echo.

:: 自动检测系统架构并选择对应的nssm
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set NSSM_PATH=%~dp0..\nssm\win64\nssm.exe
) else (
    set NSSM_PATH=%~dp0..\nssm\win32\nssm.exe
)

:: 检查nssm是否存在
if not exist "%NSSM_PATH%" (
    echo 错误: 未找到NSSM工具
    echo 请确保nssm.exe存在于:
    echo   %~dp0..\nssm\win64\nssm.exe (64位)
    echo   或
    echo   %~dp0..\nssm\win32\nssm.exe (32位)
    pause
    exit /b 1
)

:: 检查Python是否安装
where python.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 未找到Python，请先安装Python 3.8+
    pause
    exit /b 1
)

:: 检查主程序文件是否存在
if not exist "%APP_PATH%" (
    echo 错误: 未找到主程序文件 %APP_PATH%
    pause
    exit /b 1
)

echo 系统架构: %PROCESSOR_ARCHITECTURE%
echo 使用NSSM: %NSSM_PATH%
echo 安装服务: %SERVICE_NAME%
echo.

:: 使用nssm安装服务
"%NSSM_PATH%" install %SERVICE_NAME% python.exe "%APP_PATH%"
if %errorlevel% neq 0 (
    echo 错误: 服务安装失败
    pause
    exit /b 1
)

:: 设置服务显示名称
"%NSSM_PATH%" set %SERVICE_NAME% DisplayName "LanAuthGate API授权管理器"

:: 设置服务描述
"%NSSM_PATH%" set %SERVICE_NAME% Description "API授权管理网关服务，提供Web界面管理API访问权限"

:: 设置启动类型为自动
"%NSSM_PATH%" set %SERVICE_NAME% Start SERVICE_AUTO_START

:: 设置工作目录
"%NSSM_PATH%" set %SERVICE_NAME% AppDirectory "%~dp0..\"

:: 设置标准输出和错误输出
"%NSSM_PATH%" set %SERVICE_NAME% AppStdout "%~dp0..\logs\service.log"
"%NSSM_PATH%" set %SERVICE_NAME% AppStderr "%~dp0..\logs\service_error.log"

:: 设置环境变量
"%NSSM_PATH%" set %SERVICE_NAME% AppEnvironmentExtra "PYTHONIOENCODING=utf-8"

:: 设置失败时自动重启
"%NSSM_PATH%" set %SERVICE_NAME% AppRestartDelay 5000
"%NSSM_PATH%" set %SERVICE_NAME% AppThrottle 15000
"%NSSM_PATH%" set %SERVICE_NAME% AppExit Default Restart

:: 创建日志目录
if not exist "%~dp0..\logs" mkdir "%~dp0..\logs"

echo.
echo ===============================================
echo           服务安装完成!
echo ===============================================
echo 服务名称: %SERVICE_NAME%
echo 显示名称: LanAuthGate API授权管理器
echo 启动类型: 自动
echo 日志目录: %~dp0..\logs\
echo.
echo 下一步操作:
echo 1. 运行 scripts\start_service.bat 启动服务
echo 2. 访问 http://localhost:5000
echo 3. 使用密码: admin123
echo.
pause