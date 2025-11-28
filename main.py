import os
import json
import sqlite3
import asyncio
import hashlib
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import asynccontextmanager

import secrets
from fastapi import FastAPI, Depends, HTTPException, Request, Response, WebSocket, WebSocketDisconnect, status, Cookie
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html, get_redoc_html
from pydantic import BaseModel
import logging
from logging.handlers import RotatingFileHandler

# 改进的会话存储
sessions = {}


# 创建FastAPI应用
# lifespan事件处理器
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时执行
    init_db()
    print("LanAuthGate FastAPI startup completed")
    print("Access address: http://localhost:8000")
    print("Default password: admin123")
    yield
    # 关闭时执行
    print("Service shutdown completed")


# 创建FastAPI应用
app = FastAPI(
    title="LanAuthGate",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None,  # 禁用默认的 docs
    redoc_url=None,  # 禁用默认的 redoc
)

# 挂载静态文件
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# 数据库配置
DATABASE = 'api_auth.db'
DEFAULT_PASSWORD = "admin123"

# 配置日志
if not os.path.exists('logs'):
    os.makedirs('logs')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        RotatingFileHandler('logs/app.log', maxBytes=1024000, backupCount=10),
        logging.StreamHandler()
    ]
)

# 内存中的会话存储（生产环境应使用Redis等）
sessions = {}


# Pydantic模型
class LoginRequest(BaseModel):
    password: str


class APIRequest(BaseModel):
    api_path: str


class AddAPIRequest(BaseModel):
    api_path: str
    description: Optional[str] = ""
    enabled: bool = True


class UpdateAPIRequest(BaseModel):
    api_path: Optional[str] = None
    description: Optional[str] = None
    enabled: Optional[bool] = None


# 数据库函数（基本保持不变）
def get_db():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = sqlite3.connect(DATABASE)
    c = conn.cursor()

    # 创建表
    c.execute("""
              CREATE TABLE IF NOT EXISTS api_auth
              (
                  id
                  INTEGER
                  PRIMARY
                  KEY
                  AUTOINCREMENT,
                  api_path
                  TEXT
                  UNIQUE
                  NOT
                  NULL,
                  enabled
                  BOOLEAN
                  NOT
                  NULL
                  DEFAULT
                  TRUE,
                  description
                  TEXT,
                  call_count
                  INTEGER
                  DEFAULT
                  0,
                  created_at
                  TIMESTAMP
                  DEFAULT
                  CURRENT_TIMESTAMP
              )
              """)

    c.execute("""
              CREATE TABLE IF NOT EXISTS action_logs
              (
                  id
                  INTEGER
                  PRIMARY
                  KEY
                  AUTOINCREMENT,
                  timestamp
                  TEXT
                  NOT
                  NULL,
                  ip_address
                  TEXT,
                  action
                  TEXT
                  NOT
                  NULL,
                  details
                  TEXT,
                  created_at
                  TIMESTAMP
                  DEFAULT
                  CURRENT_TIMESTAMP
              )
              """)

    c.execute("""
              CREATE TABLE IF NOT EXISTS app_config
              (
                  id
                  INTEGER
                  PRIMARY
                  KEY
                  AUTOINCREMENT,
                  config_key
                  TEXT
                  UNIQUE
                  NOT
                  NULL,
                  config_value
                  TEXT
                  NOT
                  NULL,
                  description
                  TEXT,
                  updated_at
                  TIMESTAMP
                  DEFAULT
                  CURRENT_TIMESTAMP
              )
              """)

    # 插入示例数据
    default_apis = [
        ("/api/fastdem/v1", True, "Fast Demo API V1", 0),
        ("/api/fastdem/v2", False, "Fast Demo API V2", 0),
        ("/api/fastfault/v1", True, "Fast Fault API V1", 0),
    ]

    for api_path, enabled, description, call_count in default_apis:
        try:
            c.execute('INSERT OR IGNORE INTO api_auth (api_path, enabled, description, call_count) VALUES (?, ?, ?, ?)',
                      (api_path, enabled, description, call_count))
        except:
            pass

    # 初始化密码
    try:
        hashed_password = hash_password(DEFAULT_PASSWORD)
        c.execute('INSERT OR IGNORE INTO app_config (config_key, config_value, description) VALUES (?, ?, ?)',
                  ('admin_password', hashed_password, '管理员密码'))
    except:
        pass

    conn.commit()
    conn.close()

    migrate_database()


def migrate_database():
    """数据库迁移"""
    conn = get_db()
    c = conn.cursor()

    try:
        c.execute('SELECT call_count FROM api_auth LIMIT 1')
        # print("✅ call_count列已存在")
    except sqlite3.OperationalError:
        print("Database schema upgrade detected, adding call_count column...")
        c.execute('ALTER TABLE api_auth ADD COLUMN call_count INTEGER DEFAULT 0')
        c.execute('UPDATE api_auth SET call_count = 0 WHERE call_count IS NULL')
        conn.commit()
        print("Database schema update completed: call_count column added")

    conn.close()


def hash_password(password: str) -> str:
    """密码哈希"""
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(input_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return hash_password(input_password) == hashed_password


def get_hashed_password() -> str:
    """获取密码哈希"""
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT config_value FROM app_config WHERE config_key = ?', ('admin_password',))
    result = c.fetchone()
    conn.close()

    if result:
        return result['config_value']
    else:
        hashed_default = hash_password(DEFAULT_PASSWORD)
        set_password(DEFAULT_PASSWORD)
        return hashed_default


def set_password(new_password: str):
    """设置新密码"""
    hashed_password = hash_password(new_password)
    conn = get_db()
    c = conn.cursor()
    c.execute('''
        INSERT OR REPLACE INTO app_config (config_key, config_value, description) 
        VALUES (?, ?, ?)
    ''', ('admin_password', hashed_password, '管理员密码'))
    conn.commit()
    conn.close()


def check_api_auth(api_path: str) -> bool:
    """检查API授权"""
    if not api_path.startswith('/'):
        api_path = '/' + api_path

    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT enabled FROM api_auth WHERE api_path = ?', (api_path,))
    result = c.fetchone()
    conn.close()

    if result:
        return bool(result['enabled'])
    return False


def increment_call_count(api_path: str):
    """增加调用次数"""
    if not api_path.startswith('/'):
        api_path = '/' + api_path

    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE api_auth SET call_count = call_count + 1 WHERE api_path = ?', (api_path,))
    conn.commit()
    conn.close()


# 在 main.py 中修改日志记录函数，添加更详细的日志
def log_action(action: str, details: str, ip_address: str = None):
    """记录操作日志"""
    # 扩展允许的操作类型
    allowed_actions = [
        'API_CHECK', 'API_CHECK_GET', 'EXPORT_CONFIG', 'IMPORT_CONFIG',
        'ADD_API', 'UPDATE_API', 'DELETE_API', 'TOGGLE_API',
        'RESET_CALL_COUNT', 'CHANGE_PASSWORD', 'LOGIN', 'LOGOUT'
    ]

    if action not in allowed_actions:
        return

    if ip_address is None:
        ip_address = 'unknown'

    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    logging.info(f"{timestamp} - {ip_address} - {action} - {details}")

    conn = get_db()
    c = conn.cursor()
    c.execute('INSERT INTO action_logs (timestamp, ip_address, action, details) VALUES (?, ?, ?, ?)',
              (timestamp, ip_address, action, details))
    conn.commit()
    conn.close()


# 确保认证依赖正确工作
# 临时注释掉所有调试打印
def get_current_user(session_id: Optional[str] = Cookie(None)):
    """获取当前用户"""
    if not session_id or session_id not in sessions:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")

    # 注释掉调试输出
    # print(f"🔐 认证检查 - Session ID: {session_id}")
    # print(f"🔐 现有会话: {list(sessions.keys())}")
    # print(f"✅ 认证成功: {session_id}")

    return sessions[session_id]

# 修改根路由，避免重定向循环
@app.get("/", response_class=HTMLResponse)
async def index(request: Request, session_id: Optional[str] = Cookie(None)):
    # 检查是否已登录
    if not session_id or session_id not in sessions:
        # 未登录，返回登录页面（不是重定向）
        return templates.TemplateResponse("login.html", {"request": request})

    # 已登录，返回主页面
    return templates.TemplateResponse("index.html", {"request": request})

# 离线文档使用 | 内网无法使用CDN
@app.get("/docs", include_in_schema=False)
async def custom_swagger_ui_html():
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} SwaggerUI API文档",
        swagger_js_url="/static/swagger-ui/swagger-ui-bundle.js",
        swagger_css_url="/static/swagger-ui/swagger-ui.css",
    )

# 离线文档使用 | 内网无法使用CDN
@app.get("/redoc", response_class=HTMLResponse)
async def custom_redoc_ui_html():
    return get_redoc_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} ReDoc API文档",
        redoc_js_url="/static/redoc/redoc.standalone.js",
    )

# 修改登录页面路由
@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request, session_id: Optional[str] = Cookie(None)):
    # 如果已登录，重定向到首页
    if session_id and session_id in sessions:
        from fastapi.responses import RedirectResponse
        return RedirectResponse(url="/")

    return templates.TemplateResponse("login.html", {"request": request})


# 改进的登录路由
@app.post("/api/auth/login")
async def login(response: Response, login_data: LoginRequest):
    hashed_password = get_hashed_password()

    if verify_password(login_data.password, hashed_password):
        session_id = secrets.token_hex(16)
        sessions[session_id] = {"logged_in": True, "user": "admin"}

        # 设置cookie
        response.set_cookie(
            key="session_id",
            value=session_id,
            httponly=True,
            max_age=3600,  # 1小时过期
            samesite="lax"
        )

        return {"success": True, "message": "Login successful"}
    else:
        raise HTTPException(status_code=401, detail="Incorrect password")


@app.post("/api/auth/logout")
async def logout(response: Response, user: dict = Depends(get_current_user)):
    session_id = None
    for sid, data in sessions.items():
        if data == user:
            session_id = sid
            break

    if session_id:
        del sessions[session_id]

    response.delete_cookie("session_id")
    return {"success": True, "message": "Logged out successfully"}


@app.post("/api/auth/change-password")
async def change_password(
        data: dict,
        user: dict = Depends(get_current_user),
        request: Request = None
):
    current_password = data.get('current_password', '')
    new_password = data.get('new_password', '')
    confirm_password = data.get('confirm_password', '')

    if not current_password or not new_password or not confirm_password:
        raise HTTPException(status_code=400, detail="All fields are required")

    if new_password != confirm_password:
        raise HTTPException(status_code=400, detail="New password and confirmation do not match")

    if len(new_password) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters")

    hashed_password = get_hashed_password()
    if not verify_password(current_password, hashed_password):
        raise HTTPException(status_code=401, detail="Current password incorrect")

    set_password(new_password)
    log_action('CHANGE_PASSWORD', 'Password changed', request.client.host if request else None)

    return {"success": True, "message": "Password changed successfully"}


@app.get("/api/auth/password-hint")
async def get_password_hint():
    hashed_password = get_hashed_password()
    if verify_password(DEFAULT_PASSWORD, hashed_password):
        return {"is_default": True, "hint": f"Initial password: {DEFAULT_PASSWORD}"}
    else:
        return {"is_default": False, "hint": "Please enter the admin password"}


# API授权检查路由
@app.post("/api/auth/check")
async def check_auth(api_data: APIRequest, request: Request):
    try:
        api_path = api_data.api_path
        is_enabled = check_api_auth(api_path)
        increment_call_count(api_path)

        log_action('API_CHECK', f'path={api_path}, authorized={is_enabled}', request.client.host)

        return {
            "api_path": api_path,
            "authorized": is_enabled,
            "enabled": is_enabled,
            "message": "API authorized" if is_enabled else "API not authorized",
            "status": "success"
        }
    except Exception as e:
        log_action('API_CHECK_ERROR', f'error={str(e)}', request.client.host)
        raise HTTPException(status_code=500, detail=f"Error while checking authorization: {str(e)}")


@app.get("/api/auth/check/get")
async def check_auth_get(path: str, request: Request):
    try:
        if not path:
            raise HTTPException(status_code=400, detail="Missing path parameter")

        is_enabled = check_api_auth(path)
        increment_call_count(path)

        log_action('API_CHECK_GET', f'path={path}, authorized={is_enabled}', request.client.host)

        return {
            "api_path": path,
            "authorized": is_enabled,
            "enabled": is_enabled,
            "message": "API authorized" if is_enabled else "API not authorized",
            "status": "success"
        }
    except Exception as e:
        log_action('API_CHECK_GET_ERROR', f'error={str(e)}', request.client.host)
        raise HTTPException(status_code=500, detail=f"Error while checking authorization: {str(e)}")


# 添加调试信息到API列表路由
@app.get("/api/auth/list")
async def list_apis(user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM api_auth ORDER BY created_at DESC')
    apis = [dict(row) for row in c.fetchall()]
    conn.close()

    # 注释掉调试输出
    # print(f"📋 获取API列表 - 用户: {user}")
    # print(f"📋 返回API数量: {len(apis)}")
    # for api in apis:
    #     print(f"  - {api['api_path']} (启用: {api['enabled']}, 调用: {api['call_count']})")

    return apis


# 在相关的API路由中添加日志记录
@app.post("/api/auth/add")
async def add_api(api_data: AddAPIRequest, request: Request, user: dict = Depends(get_current_user)):
    if not api_data.api_path:
        raise HTTPException(status_code=400, detail="API path cannot be empty")

    if not api_data.api_path.startswith('/'):
        raise HTTPException(status_code=400, detail="API path must start with a slash (/)")

    conn = get_db()
    c = conn.cursor()
    try:
        c.execute('INSERT INTO api_auth (api_path, enabled, description, call_count) VALUES (?, ?, ?, 0)',
                  (api_data.api_path, api_data.enabled, api_data.description))
        conn.commit()
        conn.close()

        # 记录添加API操作
        log_action('ADD_API', f'path={api_data.api_path}, enabled={api_data.enabled}', request.client.host)

        return {
            "message": "API added successfully",
            "api_path": api_data.api_path,
            "enabled": api_data.enabled
        }
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail="API path already exists")


@app.put("/api/auth/update/{api_id}")
async def update_api(api_id: int, api_data: UpdateAPIRequest, user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()

    updates = []
    params = []

    if api_data.enabled is not None:
        updates.append('enabled = ?')
        params.append(api_data.enabled)

    if api_data.api_path:
        if not api_data.api_path.startswith('/'):
            conn.close()
            raise HTTPException(status_code=400, detail="API path must start with a slash (/)")
        updates.append('api_path = ?')
        params.append(api_data.api_path)

    if api_data.description is not None:
        updates.append('description = ?')
        params.append(api_data.description)

    if updates:
        params.append(api_id)
        query = f'UPDATE api_auth SET {", ".join(updates)} WHERE id = ?'
        c.execute(query, params)

    conn.commit()

    c.execute('SELECT * FROM api_auth WHERE id = ?', (api_id,))
    updated_api = dict(c.fetchone())
    conn.close()

    return {
        "message": "API updated successfully",
        "api": updated_api
    }


@app.delete("/api/auth/delete/{api_id}")
async def delete_api(api_id: int, user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()

    c.execute('SELECT api_path FROM api_auth WHERE id = ?', (api_id,))
    api = c.fetchone()

    if not api:
        conn.close()
        raise HTTPException(status_code=404, detail="API not found")

    c.execute('DELETE FROM api_auth WHERE id = ?', (api_id,))
    conn.commit()
    conn.close()

    return {
        "message": "API deleted successfully",
        "deleted_api": api['api_path']
    }


# 配置管理路由
@app.get("/api/auth/export")
async def export_auth(user: dict = Depends(get_current_user), request: Request = None):
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT api_path, enabled, description FROM api_auth')
    apis = [dict(row) for row in c.fetchall()]
    conn.close()

    export_path = os.path.join(os.getcwd(), 'api_auth_export.json')
    with open(export_path, 'w', encoding='utf-8') as f:
        json.dump(apis, f, ensure_ascii=False, indent=2)

    log_action('EXPORT_CONFIG', f'path={export_path}, count={len(apis)}', request.client.host if request else None)

    return {
        "message": f"Configuration exported to: {export_path}",
        "export_path": export_path,
        "api_count": len(apis)
    }


@app.post("/api/auth/import")
async def import_auth(request: Request, user: dict = Depends(get_current_user)):
    """导入配置 - 详细调试版本"""
    try:
        # 获取原始请求体进行调试
        body = await request.body()
        print(f"Received raw request body, length: {len(body)}")
        print(f"Request headers: {dict(request.headers)}")

        # 解析JSON
        try:
            data = json.loads(body.decode('utf-8'))
        except json.JSONDecodeError as e:
            print(f"JSON parse failed: {e}")
            print(f"Raw data preview: {body[:500]}...")  # 打印前500字符
            raise HTTPException(status_code=400, detail=f"JSON parse failed: {str(e)}")

        print(f"Parsed data type: {type(data)}")
        print(f"Data length: {len(data) if isinstance(data, list) else 'not a list'}")

        if not isinstance(data, list):
            print(f"Data is not a list: {type(data)}")
            raise HTTPException(status_code=400, detail="Configuration file format error: expected an array")

        conn = get_db()
        c = conn.cursor()

        success_count = 0
        error_count = 0
        errors = []

        print(f"Start processing {len(data)} items...")

        for index, item in enumerate(data):
            try:
                print(f"Processing item {index + 1}: {item}")

                if not isinstance(item, dict):
                    error_msg = f"Item {index + 1}: not an object"
                    errors.append(error_msg)
                    error_count += 1
                    print(f"{error_msg}")
                    continue

                if 'api_path' not in item:
                    error_msg = f"Item {index + 1}: missing api_path field"
                    errors.append(error_msg)
                    error_count += 1
                    print(f"{error_msg}")
                    continue

                api_path = item['api_path']
                enabled = item.get('enabled', True)
                if isinstance(enabled, int):
                    enabled = bool(enabled)
                description = item.get('description', '')

                print(f"Handling API path: {api_path}, enabled: {enabled}, description: {description}")

                if not api_path.startswith('/'):
                    error_msg = f"Item {index + 1}: API path must start with '/': {api_path}"
                    errors.append(error_msg)
                    error_count += 1
                    print(f"{error_msg}")
                    continue

                # 使用 INSERT OR REPLACE
                try:
                    c.execute(
                        'INSERT OR REPLACE INTO api_auth (api_path, enabled, description, call_count) VALUES (?, ?, ?, 0)',
                        (api_path, enabled, description)
                    )
                    success_count += 1
                    print(f"Imported successfully: {api_path}")

                except sqlite3.Error as db_error:
                    error_msg = f"Item {index + 1}: database error - {str(db_error)}"
                    errors.append(error_msg)
                    error_count += 1
                    print(f"{error_msg}")

            except Exception as e:
                error_msg = f"Item {index + 1}: processing failed - {str(e)}"
                errors.append(error_msg)
                error_count += 1
                print(f"{error_msg}")

        conn.commit()

        # 验证导入结果
        c.execute('SELECT COUNT(*) as count FROM api_auth')
        total_count = c.fetchone()['count']
        conn.close()

        print(f"Import finished: success {success_count}, failed {error_count}, total in DB: {total_count}")

        result_message = f"API import completed: success {success_count}, failed {error_count}"
        if errors:
            result_message += f"\nFirst 5 errors: {', '.join(errors[:5])}"

        log_action('IMPORT_CONFIG', f'success={success_count}, errors={error_count}, total_in_db={total_count}',
                   request.client.host)

        return {
            "message": result_message,
            "imported_count": success_count,
            "error_count": error_count,
            "total_in_database": total_count,
            "errors": errors[:10]
        }

    except Exception as e:
        print(f"Import process exception: {e}")
        import traceback
        traceback.print_exc()
        log_action('IMPORT_CONFIG_ERROR', f'error={str(e)}', request.client.host)
        raise HTTPException(status_code=400, detail=f"Import failed: {str(e)}")


@app.get("/api/auth/debug-db")
async def debug_database():
    """调试数据库状态"""
    try:
        conn = get_db()
        c = conn.cursor()

        # 检查表结构
        c.execute("PRAGMA table_info(api_auth)")
        columns = [dict(row) for row in c.fetchall()]

        # 检查当前数据
        c.execute("SELECT COUNT(*) as count FROM api_auth")
        count = c.fetchone()['count']

        c.execute("SELECT * FROM api_auth LIMIT 5")
        sample_data = [dict(row) for row in c.fetchall()]

        conn.close()

        return {
            "table_columns": columns,
            "total_records": count,
            "sample_data": sample_data,
            "database_file": DATABASE
        }
    except Exception as e:
        return {"error": str(e)}

# 日志管理路由
@app.get("/api/auth/logs")
async def get_logs(user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM action_logs ORDER BY created_at DESC LIMIT 50')
    logs = [dict(row) for row in c.fetchall()]
    conn.close()
    return logs


@app.delete("/api/auth/clear-logs")
async def clear_logs(user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()
    c.execute('DELETE FROM action_logs')
    conn.commit()
    conn.close()
    return {"message": "Logs cleared"}


# 统计管理路由
@app.post("/api/auth/reset-call-count/{api_id}")
async def reset_call_count(api_id: int, user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE api_auth SET call_count = 0 WHERE id = ?', (api_id,))
    conn.commit()

    c.execute('SELECT * FROM api_auth WHERE id = ?', (api_id,))
    updated_api = dict(c.fetchone())
    conn.close()

    return {
        "message": "Call count reset",
        "api": updated_api
    }


@app.post("/api/auth/reset-all-call-counts")
async def reset_all_call_counts(user: dict = Depends(get_current_user)):
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE api_auth SET call_count = 0')
    conn.commit()
    conn.close()
    return {"message": "All API call counts reset"}


# 修改SSE日志流路由,修改日志流端点，确保不重复发送日志
# 在 main.py 中优化日志流端点
@app.get("/api/auth/logs/stream")
async def stream_logs(request: Request, user: dict = Depends(get_current_user)):
    """SSE实时日志流 - 优化版本"""

    async def event_generator():
        last_id = 0
        client_id = id(request)  # 使用请求对象ID作为客户端标识

        print(f"Client {client_id} connected to logs stream, last_id: {last_id}")

        try:
            while True:
                if await request.is_disconnected():
                    print(f"Client {client_id} disconnected")
                    break

                # 检查新日志
                conn = get_db()
                c = conn.cursor()
                c.execute('SELECT * FROM action_logs WHERE id > ? ORDER BY id ASC LIMIT 10', (last_id,))
                new_logs = [dict(row) for row in c.fetchall()]
                conn.close()

                if new_logs:
                    for log in new_logs:
                        log_id = log['id']
                        last_id = max(last_id, log_id)

                        # 立即发送新日志
                        yield f"data: {json.dumps(log, ensure_ascii=False)}\n\n"
                        print(f"Sent log ID {log_id} to client {client_id}")

                    # 立即刷新输出缓冲区
                    await asyncio.sleep(0.1)
                else:
                    # 没有新日志时发送心跳包
                    heartbeat_data = {
                        'type': 'heartbeat',
                        'timestamp': datetime.now().isoformat(),
                        'last_id': last_id
                    }
                    yield f"data: {json.dumps(heartbeat_data, ensure_ascii=False)}\n\n"

                # 缩短等待时间，提高实时性
                await asyncio.sleep(0.5)  # from 1s to 0.5s

        except Exception as e:
            print(f"SSE stream exception for client {client_id}: {e}")

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Credentials": "true",
            "X-Accel-Buffering": "no"
        }
    )

# 改进的会话检查端点
@app.get("/api/auth/check-session")
async def check_session(session_id: Optional[str] = Cookie(None)):
    """检查会话状态"""
    if session_id and session_id in sessions:
        return {
            "logged_in": True,
            "session_id": session_id[:8] + "...",  # 只显示部分session_id
            "user": sessions[session_id].get("user", "admin")
        }
    else:
        return {
            "logged_in": False,
            "message": "Not logged in"
        }


@app.get("/api/auth/debug-cookies")
async def debug_cookies(request: Request):
    """调试cookies"""
    return {
        "cookies": request.cookies,
        "headers": dict(request.headers)
    }


# 调试路由
@app.get("/api/auth/debug")
async def debug_apis():
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM api_auth ORDER BY id')
    apis = [dict(row) for row in c.fetchall()]
    conn.close()

    debug_info = []
    for api in apis:
        check_result = check_api_auth(api['api_path'])
        debug_info.append({
            'db_data': api,
            'check_result': check_result,
            'match_status': '匹配' if check_result == api['enabled'] else '不匹配'
        })

    return {"all_apis": debug_info}

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        reload=False,  # 生产环境关闭热重载
        log_level="info",
        access_log=True
    )
