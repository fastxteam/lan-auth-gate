@echo off
chcp 65001 >nul
set SERVICE_NAME=LanAuthGate

echo 检查 %SERVICE_NAME% 服务状态...
echo.

sc query %SERVICE_NAME%

echo.
pause