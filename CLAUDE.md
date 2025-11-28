# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LanAuthGate is a FastAPI-based API authorization management gateway that provides a web GUI for managing and monitoring API access permissions. It serves as an authorization management component that can be integrated with existing systems.

## Development Commands

### Setup and Run
```bash
# Install dependencies (preferred method)
uv sync

# Alternative: Install with pip
pip install -r requirements.txt

# Run the application
python main.py
# Access at: http://localhost:8000
# Default password: admin123
```

### Build Windows Executable
```bash
# Install PyInstaller
pip install pyinstaller==5.13.2

# Build standalone executable
pyinstaller --onefile --console --add-data "static;static" --add-data "templates;templates" -F main.py

# Or use the spec file
pyinstaller main.spec
```

### Windows Service Management
```batch
# Deploy as Windows service (Chinese interface)
service_manager.bat

# Deploy as Windows service (English interface)
service_deploy.bat

# Manual service control
nssm start LanAuthGate
nssm stop LanAuthGate
nssm restart LanAuthGate
nssm status LanAuthGate
nssm remove LanAuthGate
```

### Linting and Quality Checks
```bash
pip install flake8 pylint
flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
pylint $(find . -name "*.py" | grep -v venv) || true
```

## Architecture Overview

### Core Components
- **main.py**: Single-file FastAPI application (~30KB) containing all backend logic
- **Database**: SQLite3 with three main tables (api_auth, action_logs, app_config)
- **Frontend**: Jinja2 templates with vanilla JavaScript, no build process required
- **Real-time**: Server-Sent Events (SSE) for live log streaming
- **Authentication**: Session-based with SHA-256 password hashing

### Key API Endpoints
- **Authorization Check**: `/api/auth/check` (POST) and `/api/auth/check/get` (GET)
- **API Management**: `/api/auth/list`, `/api/auth/add`, `/api/auth/update/{id}`, `/api/auth/delete/{id}`
- **Configuration**: `/api/auth/export`, `/api/auth/import`
- **Logs**: `/api/auth/logs`, `/api/auth/logs/stream` (SSE)
- **System**: `/api/auth/debug`, `/api/auth/debug-db`, `/api/auth/debug-cookies`

### Database Schema
```sql
-- api_auth table: Stores API authorization rules
CREATE TABLE api_auth (id, api_path, enabled, description, call_count, created_at)

-- action_logs table: Stores operation audit logs
CREATE TABLE action_logs (id, timestamp, ip_address, action, details, created_at)

-- app_config table: Stores application configuration
CREATE TABLE app_config (id, config_key, config_value, description, updated_at)
```

### File Structure
```
main.py              # Main FastAPI application
templates/           # Jinja2 HTML templates
├── index.html       # Main dashboard
└── login.html       # Login page
static/              # Frontend assets (CSS, JS, icons)
logs/                # Application logs (app.log)
api_auth.db         # SQLite database (auto-generated)
nssm/                # Windows service manager binaries
```

### Development Patterns
- **Single File Architecture**: All backend logic in main.py for simplicity
- **No Frontend Build**: Direct HTML/CSS/JS served via static files
- **Database Migrations**: Automatic migration handled in `migrate_database()`
- **Session Management**: In-memory sessions with 1-hour expiry
- **Error Handling**: Comprehensive try-catch blocks with user-friendly messages
- **Logging**: Rotating file handler with 1MB max size, 10 backups

### Security Considerations
- Passwords hashed with SHA-256 (not bcrypt as mentioned in some docs)
- Session cookies use HttpOnly and SameSite attributes
- CORS middleware configured for cross-origin requests
- Input validation on all API endpoints
- Database queries use parameterized statements

### Deployment Options
1. **Development**: Direct Python execution (`python main.py`)
2. **Windows Service**: NSSM-based service deployment
3. **Docker**: Multi-stage build (Dockerfile referenced in CI but not in repo)
4. **Standalone EXE**: PyInstaller packaging for Windows

### Important Notes
- Default admin password is "admin123" - should be changed immediately
- Application runs on port 8000, not 5000 as mentioned in some documentation
- Database file (api_auth.db) is created automatically on first run
- Logs directory must exist or be created for file logging to work
- Windows service deployment requires administrator privileges