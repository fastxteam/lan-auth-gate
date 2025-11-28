# 🐳 Docker部署指南

## GitHub Container Registry (GHCR) 和 Windows 构建

## 自动构建触发条件

### Docker镜像构建
这个流水线会在以下情况下自动触发：

1. **推送到main/master分支** → 构建并推送 `latest` tag
2. **创建tag (v*.*.*)** → 构建并发布Release
3. **创建Pull Request** → 运行代码检查和安全扫描
4. **手动触发** → 通过GitHub界面手动运行

### Windows可执行文件构建
1. **推送到main/master分支** → 构建Windows可执行文件
2. **创建tag (v*.*.*)** → 创建带Windows版本的Release
3. **手动触发** → 通过GitHub界面手动运行Windows构建

## 镜像标签策略

- `latest`: main分支的最新版本
- `v1.2.3`: 特定版本
- `v1.2`: 主要版本
- `v1`: 主版本
- `commit-sha`: 特定提交的构建

这样配置后，每次推送代码都会自动构建、测试并推送Docker镜像到GitHub Container Registry。

### CI/CD状态

https://github.com/fastxteam/lanauthgate/workflows/Build%2520and%2520Push%2520to%2520GHCR/badge.svg

### 拉取镜像
```bash
# 拉取最新版本
docker pull ghcr.io/fastxteam/lanauthgate:latest

# 拉取特定版本
docker pull ghcr.io/fastxteam/lanauthgate:v1.0.0

# 查看可用标签
curl -H "Authorization: Bearer $(echo $GITHUB_TOKEN)" https://ghcr.io/v2/fastxteam/lanauthgate/tags/list
```

### 运行容器
```bash
# 基本运行
docker run -d \
  --name lanauthgate \
  -p 8000:8000 \
  ghcr.io/fastxteam/lanauthgate:latest

# 带数据持久化
docker run -d \
  --name lanauthgate \
  -p 8000:8000 \
  -v lanauthgate_data:/app \
  --restart unless-stopped \
  ghcr.io/fastxteam/lanauthgate:latest

# 自定义端口
docker run -d \
  --name lanauthgate \
  -p 8080:8000 \
  -v lanauthgate_data:/app \
  --restart unless-stopped \
  ghcr.io/fastxteam/lanauthgate:latest
```

### 使用Docker Compose
```bash
version: '3.8'

services:
  lanauthgate:
    image: ghcr.io/fastxteam/lanauthgate:latest
    container_name: lanauthgate
    ports:
      - "8000:8000"
    environment:
      - FASTAPI_ENV=production
    volumes:
      - lanauthgate_data:/app
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/auth/password-hint"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  lanauthgate_data:
```

### 运行
```bash
docker-compose up -d
```

## 🔧 环境配置

### 环境变量

| 变量名                 | 默认值       | 说明               |
|-----------------------|--------------|--------------------|
| `FASTAPI_ENV`         | production   | 运行环境           |
| `PYTHONUNBUFFERED`    | 1            | Python 输出不缓冲  |
| `PYTHONDONTWRITEBYTECODE` | 1        | 不生成 `.pyc` 文件 |


### 数据持久化
容器中的数据保存在以下位置：
- 数据库: /app/api_auth.db
- 日志文件: /app/logs/
- 导出文件: /app/api_auth_export.json

建议挂载volume持久化数据：
```bash
docker run -d \
  -v /host/path/data:/app \
  ghcr.io/your-username/lanauthgate:latest
```

### 📊 监控和日志
```angular2html
# 查看实时日志
docker logs -f lanauthgate

# 查看最近100行日志
docker logs --tail 100 lanauthgate

# 查看特定时间段的日志
docker logs --since 1h lanauthgate
```

## 🪟 Windows 部署

### 下载预编译版本
1. 访问 [GitHub Releases](https://github.com/fastxteam/lanauthgate/releases)
2. 下载 `lan-auth-gate-windows-amd64.7z`
3. 解压到目标目录

### 快速部署
```batch
# 解压后运行
nssm\win64\nssm.exe install LanAuthGate "app\LanAuthGate.exe"
nssm\win64\nssm.exe start LanAuthGate

# 或者直接运行（无需服务）
cd app
LanAuthGate.exe
```

### 使用服务管理脚本
```batch
# 运行服务管理器
service_manager.bat

# 或者直接使用命令
service_deploy.bat
```

### PowerShell 构建脚本
```powershell
# 使用 PowerShell 构建脚本
.\build-windows.ps1 -BuildType release

# 跳过构建（仅打包）
.\build-windows.ps1 -SkipBuild

# 调试构建
.\build-windows.ps1 -BuildType debug
```

### Windows 服务管理
```batch
# 安装服务（需要管理员权限）
nssm install LanAuthGate "C:\path\to\LanAuthGate.exe"

# 启动服务
nssm start LanAuthGate

# 停止服务
nssm stop LanAuthGate

# 查看状态
nssm status LanAuthGate

# 卸载服务
nssm remove LanAuthGate
```
