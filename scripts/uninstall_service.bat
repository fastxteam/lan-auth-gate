@echo off
chcp 65001 >nul
set SERVICE_NAME=LanAuthGate

:: 自动检测系统架构并选择对应的nssm
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set NSSM_PATH=%~dp0..\nssm\win64\nssm.exe
) else (
    set NSSM_PATH=%~dp0..\nssm\win32\nssm.exe
)

echo 卸载 %SERVICE_NAME% 服务...

:: 先停止服务
net stop %SERVICE_NAME% >nul 2>&1

:: 卸载服务
"%NSSM_PATH%" remove %SERVICE_NAME% confirm

if %errorlevel% equ 0 (
    echo ✅ 服务卸载成功!
) else (
    echo ❌ 服务卸载失败!
    echo 请尝试以管理员权限运行
)

echo.
pause