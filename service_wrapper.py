# service_wrapper.py - Final Stable Version
import os
import sys
import time


def main():

    # ============================================
    # 关键修复：兼容 PyInstaller + Windows 服务 (NSSM)
    # ============================================
    if getattr(sys, 'frozen', False):
        # PyInstaller 模式
        # _MEIPASS 是实际包含 static/templates 的目录
        application_path = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    else:
        # 普通 Python 运行模式
        application_path = os.path.dirname(os.path.abspath(__file__))

    # 切换工作目录
    os.chdir(application_path)
    sys.path.insert(0, application_path)

    print(f"🚀 启动 LanAuthGate 服务")
    print(f"📁 工作目录: {application_path}")
    print(f"📁 静态文件: {os.path.join(application_path, 'static')}")
    print(f"📁 模板文件: {os.path.join(application_path, 'templates')}")
    print(f"🌐 绑定地址: 0.0.0.0:8000")
    print("=" * 50)

    # 检查资源文件
    static_dir = os.path.join(application_path, 'static')
    templates_dir = os.path.join(application_path, 'templates')

    print(f"⚙ 正在检查打包资源...")
    print(f"   static    -> {'OK' if os.path.exists(static_dir) else 'MISSING'}")
    print(f"   templates -> {'OK' if os.path.exists(templates_dir) else 'MISSING'}")

    try:
        # main.py 可自行读取此环境变量（可选）
        os.environ['BASE_PATH'] = application_path

        # 先导入 main，再导入 uvicorn（避免路径污染）
        from main import app
        import uvicorn

        # 启动 uvicorn
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8000,
            log_level="info",
            access_log=True
        )

    except Exception as e:
        print(f"❌ 启动失败: {e}")
        import traceback
        traceback.print_exc()
        time.sleep(10)


if __name__ == "__main__":
    main()
