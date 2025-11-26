@echo off
chcp 65001 >nul

echo ===============================================
echo      LanAuthGate 项目初始化脚本
echo ===============================================
echo.

:: 创建目录结构
echo 创建目录结构...
if not exist "nssm\win32" mkdir "nssm\win32"
if not exist "nssm\win64" mkdir "nssm\win64"
if not exist "scripts" mkdir "scripts"
if not exist "logs" mkdir "logs"

echo ✅ 目录结构创建完成
echo.
echo 请将nssm.exe文件放入对应目录:
echo   - 32位: nssm\win32\nssm.exe
echo   - 64位: nssm\win64\nssm.exe
echo.
echo 然后运行 scripts\install_service.bat 安装服务
echo.
pause