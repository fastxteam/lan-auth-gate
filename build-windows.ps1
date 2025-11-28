# LanAuthGate Windows Build Script
# This script builds the Windows executable and creates distribution package

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("release", "debug")]
    [string]$BuildType = "release",

    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipArchive = $false
)

# Set error handling
$ErrorActionPreference = "Stop"

# Configuration
$ServiceName = "LanAuthGate"
$WorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistDir = Join-Path $WorkingDir "dist"
$WindowsDistDir = Join-Path $DistDir "windows"
$AppDir = Join-Path $WindowsDistDir "app"
$ArchiveName = "lan-auth-gate-windows-amd64.7z"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "LanAuthGate Windows Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Type: $BuildType" -ForegroundColor Green
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

    # Check 7z
    try {
        $sevenZipVersion = 7z | Select-String -Pattern "7-Zip"
        Write-Host "✅ 7-Zip found: $sevenZipVersion" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ 7-Zip not found, please install it for archive creation" -ForegroundColor Yellow
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

    # Copy executable
    if (Test-Path "dist\main.exe") {
        Copy-Item "dist\main.exe" "$AppDir\LanAuthGate.exe"
        Write-Host "✅ Executable copied" -ForegroundColor Green
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

    # Copy service scripts
    if (Test-Path "service_deploy.bat") {
        Copy-Item "service_deploy.bat" "$WindowsDistDir\service_deploy.bat"
        Write-Host "✅ Service deploy script copied" -ForegroundColor Green
    }

    if (Test-Path "service_manager.bat") {
        Copy-Item "service_manager.bat" "$WindowsDistDir\service_manager.bat"
        Write-Host "✅ Service manager script copied" -ForegroundColor Green
    }

    Write-Host "✅ Distribution package created" -ForegroundColor Green
}

function Create-Archive {
    if ($SkipArchive) {
        Write-Host "⏭️ Skipping archive creation as requested" -ForegroundColor Cyan
        return
    }

    Write-Host "Creating archive..." -ForegroundColor Yellow

    # Create archive
    try {
        Push-Location $WindowsDistDir
        7z a -t7z "..\..\$ArchiveName" .
        Pop-Location

        Write-Host "✅ Archive created: $ArchiveName" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Archive creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Distribution files are available in: $WindowsDistDir" -ForegroundColor Cyan
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
    if (Test-Path "$WorkingDir\$ArchiveName") {
        Write-Host "Archive location: $WorkingDir\$ArchiveName" -ForegroundColor Yellow
    }
    Write-Host "========================================" -ForegroundColor Cyan

} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Build failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}