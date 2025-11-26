@echo off
chcp 65001 >nul
set SERVICE_NAME=LanAuthGate

echo 停止 %SERVICE_NAME% 服务...

net stop %SERVICE_NAME%

if %errorlevel% equ 0 (
    echo ✅ 服务停止成功!
) else (
    echo ❌ 服务停止失败!
    echo 可能是服务未运行或无权限
)

echo.
pause