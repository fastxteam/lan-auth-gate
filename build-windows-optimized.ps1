# LanAuthGate Windows Build Script - Optimized Version
# This script builds the Windows executable with flexible packaging options

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("release", "debug")]
    [string]$BuildType = "release",

    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipArchive = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet("7z", "zip", "none")]
    [string]$ArchiveFormat = "zip",

    [Parameter(Mandatory=$false)]
    [string]$OutputName = ""
)

# Set error handling
$ErrorActionPreference = "Stop"

# Configuration
$ServiceName = "LanAuthGate"
$WorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistDir = Join-Path $WorkingDir "dist"
$WindowsDistDir = Join-Path $DistDir "windows"
$AppDir = Join-Path $WindowsDistDir "app"

# Auto-generate output name if not provided
if ([string]::IsNullOrEmpty($OutputName)) {
    $Version = (Get-Date -Format "yyyyMMdd")
    $Architecture = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "x86" }
    $OutputName = "lan-auth-gate-windows-$Architecture-$Version"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "LanAuthGate Windows Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Type: $BuildType" -ForegroundColor Green
Write-Host "Archive Format: $ArchiveFormat" -ForegroundColor Green
Write-Host "Output Name: $OutputName" -ForegroundColor Green
Write-Host "Working Directory: $WorkingDir" -ForegroundColor Green
Write-Host ""

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow

    # Check Python
    try {
        $pythonVersion = python --version 2>$1
        Write-Host "✅ Python found: $pythonVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ Python not found in PATH" -ForegroundColor Red
        exit 1
    }

    # Check PyInstaller
    try {
        $pyinstallerVersion = pyinstaller --version 2>$1
        Write-Host "✅ PyInstaller found: $pyinstallerVersion" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ PyInstaller not found, installing..." -ForegroundColor Yellow
        pip install pyinstaller==5.13.2
    }

    # Check archive tools based on format
    if ($ArchiveFormat -eq "7z") {
        try {
            $sevenZipVersion = 7z | Select-String -Pattern "7-Zip"
            Write-Host "✅ 7-Zip found: $sevenZipVersion" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ 7-Zip not found, fallback to zip format" -ForegroundColor Yellow
            $ArchiveFormat = "zip"
        }
    }

    if ($ArchiveFormat -eq "zip") {
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            Write-Host "✅ .NET ZIP support available" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ .NET ZIP not available, skipping archive" -ForegroundColor Yellow
            $ArchiveFormat = "none"
        }
    }
}

function Install-Dependencies {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow

    if (Test-Path "requirements.txt") {
        pip install -r requirements.txt
        Write-Host "✅ Dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ requirements.txt not found, installing minimal dependencies" -ForegroundColor Yellow
        pip install fastapi uvicorn jinja2 python-multipart
    }
}

function Build-Executable {
    if ($SkipBuild) {
        Write-Host "⏭️ Skipping build as requested" -ForegroundColor Cyan
        return
    }

    Write-Host "Building executable..." -ForegroundColor Yellow

    # Create logs directory
    if (!(Test-Path "logs")) {
        New-Item -ItemType Directory -Path "logs" | Out-Null
    }

    # Clean previous build
    if (Test-Path "build") {
        Remove-Item -Recurse -Force "build"
    }
    if (Test-Path "dist\main.exe") {
        Remove-Item -Force "dist\main.exe"
    }
    if (Test-Path "$WindowsDistDir") {
        Remove-Item -Recurse -Force "$WindowsDistDir"
    }

    # Build with PyInstaller
    $pyinstallerArgs = @(
        "--onefile",
        "--console",
        "--add-data", "static;static",
        "--add-data", "templates;templates",
        "-F",
        "main.py"
    )

    if ($BuildType -eq "debug") {
        $pyinstallerArgs += "--debug"
    }

    Write-Host "Running PyInstaller..." -ForegroundColor Cyan
    pyinstaller $pyinstallerArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Executable built successfully" -ForegroundColor Green
}

function Create-Distribution {
    Write-Host "Creating distribution package..." -ForegroundColor Yellow

    # Create directory structure
    New-Item -ItemType Directory -Path "$AppDir\static" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AppDir\templates" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AppDir\logs" -Force | Out-Null
    New-Item -ItemType Directory -Path "$WindowsDistDir\nssm\win64" -Force | Out-Null
    New-Item -ItemType Directory -Path "$WindowsDistDir\nssm\win32" -Force | Out-Null

    # Copy executable with proper name
    if (Test-Path "dist\main.exe") {
        Copy-Item "dist\main.exe" "$AppDir\LanAuthGate.exe"
        Write-Host "✅ Executable copied as LanAuthGate.exe" -ForegroundColor Green
    } else {
        Write-Host "❌ Executable not found!" -ForegroundColor Red
        exit 1
    }

    # Copy static files and templates
    if (Test-Path "static") {
        Copy-Item -Recurse -Force "static\*" "$AppDir\static"
        Write-Host "✅ Static files copied" -ForegroundColor Green
    }

    if (Test-Path "templates") {
        Copy-Item -Recurse -Force "templates\*" "$AppDir\templates"
        Write-Host "✅ Templates copied" -ForegroundColor Green
    }

    # Copy NSSM binaries if they exist
    if (Test-Path "nssm\win64\nssm.exe") {
        Copy-Item "nssm\win64\nssm.exe" "$WindowsDistDir\nssm\win64\nssm.exe"
        Write-Host "✅ NSSM 64-bit copied" -ForegroundColor Green
    } else {
        Write-Host "⚠️ NSSM 64-bit not found" -ForegroundColor Yellow
    }

    if (Test-Path "nssm\win32\nssm.exe") {
        Copy-Item "nssm\win32\nssm.exe" "$WindowsDistDir\nssm\win32\nssm.exe"
        Write-Host "✅ NSSM 32-bit copied" -ForegroundColor Green
    } else {
        Write-Host "⚠️ NSSM 32-bit not found" -ForegroundColor Yellow
    }

    # Create deployment scripts
    Create-DeploymentScripts

    Write-Host "✅ Distribution package created" -ForegroundColor Green
}

function Create-DeploymentScripts {
    Write-Host "Creating deployment scripts..." -ForegroundColor Yellow

    # Create PowerShell deployment script
    $psDeployScript = @"
# LanAuthGate PowerShell Deployment Script
param(
    [switch]`$Uninstall = `$false,
    [string]`$ServiceName = "LanAuthGate",
    [string]`$InstallPath = "`$PSScriptRoot\app"
)

`$ErrorActionPreference = "Stop"

function Test-Administrator {
    `$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$principal = New-Object Security.Principal.WindowsPrincipal(`$currentUser)
    return `$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Deploy-Service {
    if (!(Test-Administrator)) {
        Write-Host "❌ Please run this script as Administrator!" -ForegroundColor Red
        exit 1
    }

    `$exePath = Join-Path `$InstallPath "LanAuthGate.exe"
    `$nssmPath = Join-Path `$PSScriptRoot "nssm\win64\nssm.exe"

    if (!(Test-Path `$exePath)) {
        Write-Host "❌ Executable not found: `$exePath" -ForegroundColor Red
        exit 1
    }

    if (!(Test-Path `$nssmPath)) {
        Write-Host "❌ NSSM not found: `$nssmPath" -ForegroundColor Red
        exit 1
    }

    # Remove existing service
    sc.exe query `$ServiceName >`$null 2>&1
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "⚠️ Service already exists, removing..." -ForegroundColor Yellow
        & `$nssmPath stop `$ServiceName confirm
        Start-Sleep -Seconds 3
        & `$nssmPath remove `$ServiceName confirm
        Start-Sleep -Seconds 2
    }

    # Install service
    Write-Host "🛠️ Installing service..." -ForegroundColor Yellow
    & `$nssmPath install `$ServiceName `$exePath

    if (`$LASTEXITCODE -ne 0) {
        Write-Host "❌ Service installation failed!" -ForegroundColor Red
        exit 1
    }

    # Configure service
    Write-Host "⚙️ Configuring service..." -ForegroundColor Yellow
    & `$nssmPath set `$ServiceName DisplayName "LanAuthGate API Manager"
    & `$nssmPath set `$ServiceName Description "API Authorization Manager and Monitoring System"
    & `$nssmPath set `$ServiceName Start SERVICE_AUTO_START
    & `$nssmPath set `$ServiceName AppDirectory `$InstallPath
    & `$nssmPath set `$ServiceName AppStdout (Join-Path `$InstallPath "service.log")
    & `$nssmPath set `$ServiceName AppStderr (Join-Path `$InstallPath "service_error.log")
    & `$nssmPath set `$ServiceName AppRotateFiles 1
    & `$nssmPath set `$ServiceName AppRotateOnline 1
    & `$nssmPath set `$ServiceName AppRotateSeconds 86400
    & `$nssmPath set `$ServiceName AppRotateBytes 10485760

    # Start service
    Write-Host "🚀 Starting service..." -ForegroundColor Yellow
    & `$nssmPath start `$ServiceName

    Start-Sleep -Seconds 5

    # Check status
    sc.exe query `$ServiceName | findstr "RUNNING" >`$null
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "✅ Service installed and started successfully!" -ForegroundColor Green
        Write-Host "🌐 Access URL: http://localhost:8000" -ForegroundColor Cyan
        Write-Host "🔑 Default password: admin123" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Service installed but may not be running properly" -ForegroundColor Yellow
        Write-Host "💡 Check service_error.log for details" -ForegroundColor Yellow
    }
}

function Uninstall-Service {
    if (!(Test-Administrator)) {
        Write-Host "❌ Please run this script as Administrator!" -ForegroundColor Red
        exit 1
    }

    `$nssmPath = Join-Path `$PSScriptRoot "nssm\win64\nssm.exe"

    sc.exe query `$ServiceName >`$null 2>&1
    if (`$LASTEXITCODE -ne 0) {
        Write-Host "⚠️ Service `$ServiceName does not exist" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "🗑️ Uninstalling service..." -ForegroundColor Yellow
    & `$nssmPath stop `$ServiceName confirm
    Start-Sleep -Seconds 3
    & `$nssmPath remove `$ServiceName confirm

    Write-Host "✅ Service uninstalled successfully!" -ForegroundColor Green
}

if (`$Uninstall) {
    Uninstall-Service
} else {
    Deploy-Service
}

Write-Host ""
Write-Host "Common commands:" -ForegroundColor Cyan
Write-Host "  Start service: nssm start `$ServiceName" -ForegroundColor Gray
Write-Host "  Stop service: nssm stop `$ServiceName" -ForegroundColor Gray
Write-Host "  Service status: nssm status `$ServiceName" -ForegroundColor Gray
"@

    # Save PowerShell script
    $psDeployPath = Join-Path $WindowsDistDir "deploy.ps1"
    $psDeployScript | Out-File -FilePath $psDeployPath -Encoding UTF8
    Write-Host "✅ PowerShell deployment script created" -ForegroundColor Green

    # Create batch deployment script
    $batchDeployScript = @"
@echo off
:: LanAuthGate Batch Deployment Script
:: This script provides a simple wrapper for the PowerShell deployment

set SERVICE_NAME=LanAuthGate
set SCRIPT_DIR=%~dp0

:: Check for administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Please run this script as Administrator!
    echo 💡 Right-click and select "Run as administrator"
    pause
    exit /b 1
)

:: Check if PowerShell script exists
if not exist "%SCRIPT_DIR%deploy.ps1" (
    echo ❌ deploy.ps1 not found in script directory
    pause
    exit /b 1
)

:: Run PowerShell script
echo 🚀 Starting deployment...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%deploy.ps1" %*

if %errorlevel% equ 0 (
    echo ✅ Deployment completed successfully!
) else (
    echo ❌ Deployment failed!
)

pause
"@

    $batchDeployPath = Join-Path $WindowsDistDir "deploy.bat"
    $batchDeployScript | Out-File -FilePath $batchDeployPath -Encoding ASCII
    Write-Host "✅ Batch deployment script created" -ForegroundColor Green

    # Create simplified service manager
    $simpleManager = @"
@echo off
:: LanAuthGate Simple Service Manager
:: Quick commands for service management

set SERVICE_NAME=LanAuthGate
set NSSM_EXE=%~dp0nssm\win64\nssm.exe

if "%1"=="" goto :usage
if "%1"=="start" goto :start
if "%1"=="stop" goto :stop
if "%1"=="restart" goto :restart
if "%1"=="status" goto :status
if "%1"=="remove" goto :remove
if "%1"=="install" goto :install

:usage
echo.
echo 🔧 LanAuthGate Service Manager
echo ============================
echo Usage: service.cmd [command]
echo.
echo Commands:
echo   install  - Install the service (run deploy.ps1 first)
echo   start    - Start the service
echo   stop     - Stop the service
echo   restart  - Restart the service
echo   status   - Show service status
echo   remove   - Remove the service
echo.
echo Example: service.cmd start
echo.
goto :end

:start
"%NSSM_EXE%" start %SERVICE_NAME%
goto :end

:stop
"%NSSM_EXE%" stop %SERVICE_NAME%
goto :end

:restart
"%NSSM_EXE%" restart %SERVICE_NAME%
goto :end

:status
"%NSSM_EXE%" status %SERVICE_NAME%
goto :end

:remove
"%NSSM_EXE%" stop %SERVICE_NAME% confirm
timeout /t 3 /nobreak >nul
"%NSSM_EXE%" remove %SERVICE_NAME% confirm
goto :end

:install
echo 💡 Please run deploy.ps1 first to install the service
echo    PowerShell -ExecutionPolicy Bypass -File deploy.ps1
goto :end

:end
"@

    $serviceManagerPath = Join-Path $WindowsDistDir "service.cmd"
    $simpleManager | Out-File -FilePath $serviceManagerPath -Encoding ASCII
    Write-Host "✅ Simple service manager created" -ForegroundColor Green
}

function Create-Archive {
    if ($SkipArchive -or $ArchiveFormat -eq "none") {
        Write-Host "⏭️ Skipping archive creation" -ForegroundColor Cyan
        return
    }

    Write-Host "Creating archive..." -ForegroundColor Yellow

    $archivePath = Join-Path $WorkingDir "$OutputName.$ArchiveFormat"

    try {
        if ($ArchiveFormat -eq "7z") {
            # Use 7-Zip if available
            Push-Location $WindowsDistDir
            7z a -t7z "..\..\$OutputName.7z" .
            Pop-Location
        } elseif ($ArchiveFormat -eq "zip") {
            # Use .NET compression
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            if (Test-Path $archivePath) {
                Remove-Item $archivePath
            }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($WindowsDistDir, $archivePath)
        }

        Write-Host "✅ Archive created: $archivePath" -ForegroundColor Green
        Write-Host "📦 Archive size: $([math]::Round((Get-Item $archivePath).Length / 1MB, 2)) MB" -ForegroundColor Cyan
    } catch {
        Write-Host "⚠️ Archive creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "💡 Distribution files are available in: $WindowsDistDir" -ForegroundColor Cyan
    }
}

function Test-Build {
    Write-Host "Testing build..." -ForegroundColor Yellow

    # Test executable
    if (!(Test-Path "$AppDir\LanAuthGate.exe")) {
        Write-Host "❌ Executable not found in app directory!" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Executable found" -ForegroundColor Green

    # Test critical files
    $criticalFiles = @(
        "$AppDir\static\css\style.css",
        "$AppDir\templates\index.html",
        "$AppDir\templates\login.html"
    )

    foreach ($file in $criticalFiles) {
        if (Test-Path $file) {
            Write-Host "✅ Found: $(Split-Path $file -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "❌ Missing: $(Split-Path $file -Leaf)" -ForegroundColor Red
        }
    }

    # Test deployment scripts
    $deployScripts = @(
        "$WindowsDistDir\deploy.ps1",
        "$WindowsDistDir\deploy.bat",
        "$WindowsDistDir\service.cmd"
    )

    foreach ($script in $deployScripts) {
        if (Test-Path $script) {
            Write-Host "✅ Found: $(Split-Path $script -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "❌ Missing: $(Split-Path $script -Leaf)" -ForegroundColor Red
        }
    }
}

# Main execution
try {
    Test-Prerequisites
    Install-Dependencies
    Build-Executable
    Create-Distribution
    Create-Archive
    Test-Build

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Distribution location: $WindowsDistDir" -ForegroundColor Yellow

    $archivePath = Join-Path $WorkingDir "$OutputName.$ArchiveFormat"
    if (Test-Path $archivePath) {
        Write-Host "Archive location: $archivePath" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "🚀 Quick Start:" -ForegroundColor Cyan
    Write-Host "  1. Copy the distribution folder to your target machine" -ForegroundColor Gray
    Write-Host "  2. Run: PowerShell -ExecutionPolicy Bypass -File deploy.ps1" -ForegroundColor Gray
    Write-Host "  3. Access: http://localhost:8000" -ForegroundColor Gray
    Write-Host "  4. Default password: admin123" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan

} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Build failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}