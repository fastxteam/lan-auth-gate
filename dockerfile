# 使用多阶段构建
FROM python:3.9-slim as builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --user --no-cache-dir -r requirements.txt

# 运行时镜像
FROM python:3.9-slim as runtime

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    curl \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 创建非root用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# 从构建阶段复制已安装的包
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .

# 设置Python路径
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONPATH=/home/appuser/.local/lib/python3.9/site-packages

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_ENV=production

# 创建必要的目录并设置权限
RUN mkdir -p logs \
    && chown -R appuser:appuser /app

# 切换到非root用户
USER appuser

# 初始化数据库
RUN python -c "from main import init_db; init_db()"

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/api/auth/password-hint || exit 1

# 启动应用
CMD ["python", "main.py"]