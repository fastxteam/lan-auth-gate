# LanAuthGate - API授权管理器

## 项目简介
LanAuthGate是一个基于Flask的API授权管理网关，提供完整的Web GUI界面用于管理和监控API访问权限。系统支持实时日志监控、密码安全管理、配置导入导出等功能，可以作为API网关的授权管理组件集成到现有系统中。

## 功能特性

### 🔐 认证授权
- 密码保护登录系统
- 可修改的管理员密码
- 会话管理和安全退出
- 初始密码提示功能

### 🛡️ API权限管理
- API路径的启用/禁用控制
- 实时授权状态检查
- 调用次数统计和重置
- API描述信息管理

### 📊 实时监控
- 实时日志推送(SSE)
- 操作日志记录和查询
- 调用统计可视化
- 连接状态指示

### 🔧 配置管理
- JSON格式配置导入
- 配置一键导出备份
- 批量操作支持
- 数据持久化存储

### 🎨 用户界面
- 响应式Web设计
- 直观的操作界面
- 实时状态更新
- 快捷键支持

## 技术架构

### 后端技术栈
- **Web框架**: Flask 2.3+
- **数据库**: SQLite3
- **桌面化**: FlaskWebGUI
- **实时通信**: Server-Sent Events (SSE)

### 前端技术栈
- **核心**: 原生HTML5/CSS3/JavaScript
- **图标**: Font Awesome 7
- **样式**: 现代CSS变量和Flexbox布局
- **通信**: Fetch API + EventSource

### 数据模型

```python
# API授权表
api_auth(id, api_path, enabled, description, call_count, created_at)

# 操作日志表  
action_logs(id, timestamp, ip_address, action, details, created_at)

# 系统配置表
app_config(id, config_key, config_value, description, updated_at)
```

## 快速开始

1. 下载项目文件
2. 安装依赖:
    ```bash
     uv sync
    ```
3. 运行应用: 
    ```bash
     python main.py
    ```
4. 访问: http://localhost:5000
5. 使用初始密码: admin123

### 目录结构

```angular2html
LanAuthGate
 ├── api_auth.db(自动生成)
 ├── api_auth_export.json(自动生成)
 ├── logs
 │   └── app.log(自动生成)
 ├── static
 │   ├── css
 │   │   ├── all.min.css
 │   │   └── style.css
 │   ├── icons
 │   │   ├── api-2.svg
 │   │   └── favicon.svg
 │   ├── js
 │   │   └── script.js
 │   └── webfonts
 │       ├── fa-brands-400.woff2
 │       ├── fa-regular-400.woff2
 │       ├── fa-solid-900.woff2
 │       └── fa-v4compatibility.woff2
 ├── templates
 │   ├── index.html
 │   └── login.html
 ├── main.py
 ├── pyproject.toml
 ├── README.md
 └── uv.lock
```


# API 接口文档

## 1. 认证接口（Authentication）

- `POST /api/auth/login` 用户登录。
- `POST /api/auth/logout` 用户退出。
- `POST /api/auth/change-password` 修改管理员密码。
- `GET /api/auth/password-hint` 获取密码提示。

---

## 2. 授权检查接口（Authorization Check）

- `POST /api/auth/check` 检查 API 授权（POST）。
- `GET /api/auth/check/get` 检查 API 授权（GET）。

---

## 3. 管理接口（API Management）

- `GET /api/auth/list` 获取 API 列表。
- `POST /api/auth/add` 添加 API。
- `PUT /api/auth/update/<id>` 更新指定 API 数据。
- `DELETE /api/auth/delete/<id>` 删除 API。

---

## 4. 配置接口（Configuration）

- `GET /api/auth/export` 导出配置。
- `POST /api/auth/import` 导入配置。

---

## 5. 日志接口（Logs）

- `GET /api/auth/logs` 获取日志记录。
- `GET /api/auth/logs/stream` 实时日志流（SSE）。
- `DELETE /api/auth/clear-logs` 清除所有日志。

---

## 6. 统计接口（Statistics）

- `POST /api/auth/reset-call-count/<id>` 重置指定 API 的调用次数。
- `POST /api/auth/reset-all-call-counts` 重置全部 API 调用次数。


# 权限检查集成

## 1. 方式一：POST 请求

```bash
curl -X POST http://localhost:5000/api/auth/check \
  -H "Content-Type: application/json" \
  -d '{"api_path": "/api/your-service/v1"}'
```

---

## 2. 方式二：GET 请求

```bash
curl "http://localhost:5000/api/auth/check/get?path=/api/your-service/v1"
```

---

## 3. 响应格式示例

```json
{
  "api_path": "/api/your-service/v1",
  "authorized": true,
  "enabled": true,
  "message": "API已授权",
  "status": "success"
}
```

---

# 配置说明

## 系统配置

- **默认端口**：5000  
- **界面尺寸**：1200 × 800 像素  
- **会话超时**：浏览器会话期间  
- **日志保留数量**：最近 50 条操作日志


# 版本历史
## v1.0.0 - 初始版本
- 基础API授权管理
- Web图形化管理界面
- 实时日志监控
- 配置导入导出

# 许可证
- 本项目基于MIT许可证开源，允许自由使用、修改和分发。
- 最后更新: 2025/11/27
- 项目维护: FastXTeam/wanqiang.liu
