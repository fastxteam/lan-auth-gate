@echo off
chcp 65001 >nul
set SERVICE_NAME=LanAuthGate

echo 启动 %SERVICE_NAME% 服务...

net start %SERVICE_NAME%

if %errorlevel% equ 0 (
    echo.
    echo ✅ 服务启动成功!
    echo.
    echo 访问地址: http://localhost:5000
    echo 默认密码: admin123
    echo.
    echo 服务日志: ..\logs\service.log
) else (
    echo.
    echo ❌ 服务启动失败!
    echo 请检查:
    echo 1. 是否以管理员权限运行
    echo 2. 查看 ..\logs\service_error.log 获取错误信息
)

echo.
pause