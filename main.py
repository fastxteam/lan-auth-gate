import os
import json
import sqlite3
import hashlib
import secrets
import time
from flask import Response, stream_with_context
from flask import Flask, render_template, request, jsonify, send_file, session
from flaskwebgui import FlaskUI
import threading
import time
from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler

app = Flask(__name__)
app.secret_key = 'api-auth-manager-secret-key-2024'
DATABASE = 'api_auth.db'

# 移除固定的 PASSWORD，改为从数据库或文件加载
DEFAULT_PASSWORD = "admin123"  # 初始默认密码

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


# 登录检查装饰器
def login_required(f):
    def decorated_function(*args, **kwargs):
        if not session.get('logged_in'):
            return jsonify({'error': '需要登录'}), 401
        return f(*args, **kwargs)

    decorated_function.__name__ = f.__name__
    return decorated_function


# 在初始化数据库函数中添加密码表
def init_db():
    conn = sqlite3.connect(DATABASE)
    c = conn.cursor()
    c.execute(
        """
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
        """
    )

    # 创建日志表
    c.execute(
        """
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
        """
    )

    # 创建密码表
    c.execute(
        """
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
        """
    )

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

    # 初始化默认密码
    try:
        hashed_password = hash_password(DEFAULT_PASSWORD)
        c.execute('INSERT OR IGNORE INTO app_config (config_key, config_value, description) VALUES (?, ?, ?)',
                  ('admin_password', hashed_password, '管理员密码'))
    except:
        pass

    conn.commit()
    conn.close()

    # 迁移数据库
    migrate_database()


# 密码哈希函数
def hash_password(password):
    """对密码进行哈希处理"""
    return hashlib.sha256(password.encode()).hexdigest()


# 验证密码
def verify_password(input_password, hashed_password):
    """验证密码"""
    return hash_password(input_password) == hashed_password


# 获取当前密码哈希
def get_hashed_password():
    """从数据库获取密码哈希"""
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT config_value FROM app_config WHERE config_key = ?', ('admin_password',))
    result = c.fetchone()
    conn.close()

    if result:
        return result['config_value']
    else:
        # 如果数据库中没有密码，使用默认密码并保存
        hashed_default = hash_password(DEFAULT_PASSWORD)
        set_password(DEFAULT_PASSWORD)
        return hashed_default


# 设置新密码
def set_password(new_password):
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


# 数据库迁移
def migrate_database():
    """自动迁移数据库结构"""
    conn = get_db()
    c = conn.cursor()

    # 检查call_count列是否存在
    try:
        c.execute('SELECT call_count FROM api_auth LIMIT 1')
        print("✅ call_count列已存在")
    except sqlite3.OperationalError:
        # 如果列不存在，添加列
        print("🔄 检测到数据库结构需要更新，正在添加call_count列...")
        c.execute('ALTER TABLE api_auth ADD COLUMN call_count INTEGER DEFAULT 0')

        # 初始化现有数据的call_count为0
        c.execute('UPDATE api_auth SET call_count = 0 WHERE call_count IS NULL')

        conn.commit()
        print("✅ 数据库结构更新完成！call_count列已添加")

    conn.close()


# 数据库连接
def get_db():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn


# API授权检查函数
def check_api_auth(api_path):
    """检查API是否被授权"""
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


# 增加调用次数
def increment_call_count(api_path):
    """增加API调用次数"""
    if not api_path.startswith('/'):
        api_path = '/' + api_path

    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE api_auth SET call_count = call_count + 1 WHERE api_path = ?', (api_path,))
    conn.commit()
    conn.close()


# 日志记录函数 - 只记录授权检查和导入导出
def log_action(action, details, ip_address=None):
    """记录操作日志 - 只记录授权检查和导入导出操作"""
    # 只记录授权检查和导入导出操作，不记录编辑、新增、禁用、删除
    allowed_actions = ['API_CHECK', 'API_CHECK_GET', 'EXPORT_CONFIG', 'IMPORT_CONFIG']
    if action not in allowed_actions:
        return

    if ip_address is None:
        ip_address = request.remote_addr if request else 'unknown'

    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_message = f"{timestamp} - {ip_address} - {action} - {details}"
    logging.info(log_message)

    # 同时记录到数据库
    conn = get_db()
    c = conn.cursor()
    c.execute('INSERT INTO action_logs (timestamp, ip_address, action, details) VALUES (?, ?, ?, ?)',
              (timestamp, ip_address, action, details))
    conn.commit()
    conn.close()


# 路由定义
@app.route('/')
def index():
    if not session.get('logged_in'):
        return render_template('login.html')
    return render_template('index.html')


# 修改登录路由
@app.route('/api/auth/login', methods=['POST'])
def login():
    """用户登录"""
    data = request.get_json()
    password = data.get('password', '')

    # 获取存储的密码哈希
    hashed_password = get_hashed_password()

    if verify_password(password, hashed_password):
        session['logged_in'] = True
        return jsonify({'success': True, 'message': '登录成功'})
    else:
        return jsonify({'success': False, 'message': '密码错误'}), 401


# 添加修改密码路由
@app.route('/api/auth/change-password', methods=['POST'])
@login_required
def change_password():
    """修改密码"""
    data = request.get_json()
    current_password = data.get('current_password', '')
    new_password = data.get('new_password', '')
    confirm_password = data.get('confirm_password', '')

    # 验证输入
    if not current_password or not new_password or not confirm_password:
        return jsonify({'success': False, 'message': '请填写所有字段'}), 400

    if new_password != confirm_password:
        return jsonify({'success': False, 'message': '新密码和确认密码不一致'}), 400

    if len(new_password) < 4:
        return jsonify({'success': False, 'message': '密码长度至少4位'}), 400

    # 验证当前密码
    hashed_password = get_hashed_password()
    if not verify_password(current_password, hashed_password):
        return jsonify({'success': False, 'message': '当前密码错误'}), 401

    # 更新密码
    set_password(new_password)

    # 记录操作日志
    log_action('CHANGE_PASSWORD', '密码已修改')

    return jsonify({'success': True, 'message': '密码修改成功'})


# 添加获取密码提示路由
@app.route('/api/auth/password-hint')
def get_password_hint():
    """获取密码提示（仅在没有设置自定义密码时显示）"""
    # 检查是否还是默认密码
    hashed_password = get_hashed_password()
    if verify_password(DEFAULT_PASSWORD, hashed_password):
        return jsonify({'is_default': True, 'hint': f'初始密码: {DEFAULT_PASSWORD}'})
    else:
        return jsonify({'is_default': False, 'hint': '请输入管理员密码'})


@app.route('/api/auth/logout', methods=['POST'])
def logout():
    """用户退出"""
    session.pop('logged_in', None)
    return jsonify({'success': True, 'message': '已退出登录'})


@app.route('/api/auth/check', methods=['POST'])
def check_auth():
    """检查API授权状态"""
    try:
        data = request.get_json()
        if not data or 'api_path' not in data:
            return jsonify({'error': '缺少api_path参数'}), 400

        api_path = data['api_path']
        is_enabled = check_api_auth(api_path)

        # 记录调用次数
        increment_call_count(api_path)

        # 记录查询日志
        log_action('API_CHECK', f'path={api_path}, authorized={is_enabled}')

        return jsonify({
            'api_path': api_path,
            'authorized': is_enabled,
            'enabled': is_enabled,
            'message': 'API已授权' if is_enabled else 'API未授权',
            'status': 'success'
        })
    except Exception as e:
        log_action('API_CHECK_ERROR', f'error={str(e)}')
        return jsonify({
            'authorized': False,
            'message': f'检查授权时出错: {str(e)}',
            'status': 'error'
        }), 500


@app.route('/api/auth/check/get', methods=['GET'])
def check_auth_get():
    """检查API授权状态 - GET方式"""
    try:
        api_path = request.args.get('path')
        if not api_path:
            return jsonify({'error': '缺少path参数'}), 400

        is_enabled = check_api_auth(api_path)

        # 记录调用次数
        increment_call_count(api_path)

        # 记录查询日志
        log_action('API_CHECK_GET', f'path={api_path}, authorized={is_enabled}')

        return jsonify({
            'api_path': api_path,
            'authorized': is_enabled,
            'enabled': is_enabled,
            'message': 'API已授权' if is_enabled else 'API未授权',
            'status': 'success'
        })
    except Exception as e:
        log_action('API_CHECK_GET_ERROR', f'error={str(e)}')
        return jsonify({
            'authorized': False,
            'message': f'检查授权时出错: {str(e)}',
            'status': 'error'
        }), 500


@app.route('/api/auth/list')
@login_required
def list_apis():
    """获取所有API授权列表"""
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM api_auth ORDER BY created_at DESC')
    apis = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(apis)


@app.route('/api/auth/add', methods=['POST'])
@login_required
def add_api():
    """添加新的API授权 - 不记录日志"""
    data = request.get_json()
    api_path = data.get('api_path')
    description = data.get('description', '')
    enabled = data.get('enabled', True)

    if not api_path:
        return jsonify({'error': 'API路径不能为空'}), 400

    if not api_path.startswith('/'):
        return jsonify({'error': 'API路径必须以斜杠(/)开头'}), 400

    conn = get_db()
    c = conn.cursor()
    try:
        c.execute('INSERT INTO api_auth (api_path, enabled, description, call_count) VALUES (?, ?, ?, 0)',
                  (api_path, enabled, description))
        conn.commit()
        conn.close()

        return jsonify({
            'message': 'API添加成功',
            'api_path': api_path,
            'enabled': enabled
        })
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': 'API路径已存在'}), 400


@app.route('/api/auth/update/<int:api_id>', methods=['PUT'])
@login_required
def update_api(api_id):
    """更新API授权状态 - 不记录日志"""
    data = request.get_json()
    enabled = data.get('enabled')
    api_path = data.get('api_path')
    description = data.get('description')

    conn = get_db()
    c = conn.cursor()

    updates = []
    params = []

    if enabled is not None:
        updates.append('enabled = ?')
        params.append(enabled)

    if api_path:
        if not api_path.startswith('/'):
            conn.close()
            return jsonify({'error': 'API路径必须以斜杠(/)开头'}), 400
        updates.append('api_path = ?')
        params.append(api_path)

    if description is not None:
        updates.append('description = ?')
        params.append(description)

    if updates:
        params.append(api_id)
        query = f'UPDATE api_auth SET {", ".join(updates)} WHERE id = ?'
        c.execute(query, params)

    conn.commit()

    # 获取更新后的数据
    c.execute('SELECT * FROM api_auth WHERE id = ?', (api_id,))
    updated_api = dict(c.fetchone())
    conn.close()

    return jsonify({
        'message': 'API更新成功',
        'api': updated_api
    })


@app.route('/api/auth/delete/<int:api_id>', methods=['DELETE'])
@login_required
def delete_api(api_id):
    """删除API授权 - 不记录日志"""
    conn = get_db()
    c = conn.cursor()

    c.execute('SELECT api_path FROM api_auth WHERE id = ?', (api_id,))
    api = c.fetchone()

    if not api:
        conn.close()
        return jsonify({'error': 'API不存在'}), 404

    c.execute('DELETE FROM api_auth WHERE id = ?', (api_id,))
    conn.commit()
    conn.close()

    return jsonify({
        'message': 'API删除成功',
        'deleted_api': api['api_path']
    })


@app.route('/api/auth/export')
@login_required
def export_auth():
    """导出API授权配置"""
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT api_path, enabled, description FROM api_auth')
    apis = [dict(row) for row in c.fetchall()]
    conn.close()

    # 保存到应用目录
    export_path = os.path.join(os.getcwd(), 'api_auth_export.json')
    with open(export_path, 'w', encoding='utf-8') as f:
        json.dump(apis, f, ensure_ascii=False, indent=2)

    log_action('EXPORT_CONFIG', f'path={export_path}, count={len(apis)}')

    return jsonify({
        'message': f'配置已导出到: {export_path}',
        'export_path': export_path,
        'api_count': len(apis)
    })


@app.route('/api/auth/import', methods=['POST'])
@login_required
def import_auth():
    """导入API授权配置"""
    if 'file' not in request.files:
        return jsonify({'error': '没有文件'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': '没有选择文件'}), 400

    try:
        data = json.load(file)
        conn = get_db()
        c = conn.cursor()

        if not isinstance(data, list):
            conn.close()
            return jsonify({'error': '配置文件格式错误：应为数组'}), 400

        # 清空现有数据
        c.execute('DELETE FROM api_auth')

        success_count = 0
        for item in data:
            if not isinstance(item, dict) or 'api_path' not in item:
                continue

            api_path = item['api_path']
            enabled = item.get('enabled', True)
            description = item.get('description', '')

            if not api_path.startswith('/'):
                continue

            try:
                c.execute('INSERT INTO api_auth (api_path, enabled, description, call_count) VALUES (?, ?, ?, 0)',
                          (api_path, enabled, description))
                success_count += 1
            except sqlite3.IntegrityError:
                continue

        conn.commit()
        conn.close()

        log_action('IMPORT_CONFIG', f'count={success_count}')

        return jsonify({
            'message': f'API配置导入成功，共导入 {success_count} 个API',
            'imported_count': success_count
        })
    except json.JSONDecodeError:
        return jsonify({'error': '配置文件不是有效的JSON格式'}), 400
    except Exception as e:
        log_action('IMPORT_CONFIG_ERROR', f'error={str(e)}')
        return jsonify({'error': f'导入失败: {str(e)}'}), 400


# 添加SSE路由
@app.route('/api/auth/logs/stream')
@login_required
def stream_logs():
    """实时日志流"""

    def event_stream():
        last_id = 0
        while True:
            conn = get_db()
            c = conn.cursor()
            # 获取最新的日志（比上次获取的ID大的日志）
            c.execute('SELECT * FROM action_logs WHERE id > ? ORDER BY id DESC LIMIT 10', (last_id,))
            new_logs = [dict(row) for row in c.fetchall()]
            conn.close()

            if new_logs:
                # 更新最后ID
                last_id = max(log['id'] for log in new_logs)
                # 发送新日志
                for log in reversed(new_logs):  # 按时间顺序发送
                    yield f"data: {json.dumps(log)}\n\n"

            time.sleep(1)  # 每秒检查一次新日志

    return Response(stream_with_context(event_stream()),
                    mimetype="text/event-stream",
                    headers={
                        'Cache-Control': 'no-cache',
                        'Connection': 'keep-alive',
                        'X-Accel-Buffering': 'no'
                    })

# 修改现有的日志路由，添加分页支持
@app.route('/api/auth/logs')
@login_required
def get_logs():
    """获取操作日志（支持分页）"""
    limit = request.args.get('limit', 50, type=int)
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM action_logs ORDER BY id DESC LIMIT ?', (limit,))
    logs = [dict(row) for row in c.fetchall()]
    conn.close()
    return jsonify(logs)


@app.route('/api/auth/clear-logs', methods=['DELETE'])
@login_required
def clear_logs():
    """清除所有日志"""
    conn = get_db()
    c = conn.cursor()
    c.execute('DELETE FROM action_logs')
    conn.commit()
    conn.close()

    return jsonify({'message': '日志已清除'})


@app.route('/api/auth/reset-call-count/<int:api_id>', methods=['POST'])
@login_required
def reset_call_count(api_id):
    """重置API调用次数"""
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE api_auth SET call_count = 0 WHERE id = ?', (api_id,))
    conn.commit()

    # 获取更新后的数据
    c.execute('SELECT * FROM api_auth WHERE id = ?', (api_id,))
    updated_api = dict(c.fetchone())
    conn.close()

    return jsonify({
        'message': '调用次数已重置',
        'api': updated_api
    })


@app.route('/api/auth/reset-all-call-counts', methods=['POST'])
@login_required
def reset_all_call_counts():
    """重置所有API调用次数"""
    conn = get_db()
    c = conn.cursor()
    c.execute('UPDATE api_auth SET call_count = 0')
    conn.commit()
    conn.close()

    return jsonify({'message': '所有API调用次数已重置'})


@app.route('/api/auth/debug')
def debug_apis():
    """调试端点"""
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

    return jsonify({
        'all_apis': debug_info
    })


# 启动时初始化数据库
init_db()

# 创建FlaskWebGUI实例
ui = FlaskUI(server='flask', app=app, width=1200, height=800, port=5000)

if __name__ == "__main__":
    print("启动API授权管理器...")
    print("访问地址: http://localhost:5000")
    print("默认密码: admin123")
    ui.run()
