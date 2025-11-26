
## 第一步：初始化项目
运行 setup_project.bat 创建目录结构

下载NSSM并放入对应目录：

64位系统：将 nssm.exe 放入 nssm/win64/

32位系统：将 nssm.exe 放入 nssm/win32/


## 第二步：安装服务
以管理员身份运行 scripts/install_service.bat

脚本会自动检测系统架构并使用正确的nssm版本

## 第三步：管理服务
使用 scripts/service_manager.bat 进行综合管理

或使用单独的脚本文件：

start_service.bat - 启动服务

stop_service.bat - 停止服务

check_service.bat - 检查状态

```angular2html
LanAuthGate/
├── main.py                    # 主程序
├── nssm/                      # NSSM工具目录
│   ├── win32/
│   │   └── nssm.exe          # 32位版本
│   └── win64/
│       └── nssm.exe          # 64位版本
├── scripts/                   # 脚本目录
│   ├── install_service.bat   # 服务安装
│   ├── start_service.bat     # 启动服务
│   ├── stop_service.bat      # 停止服务
│   ├── uninstall_service.bat # 卸载服务
│   ├── check_service.bat     # 状态检查
│   └── service_manager.bat   # 综合管理
├── logs/                      # 日志目录
│   ├── service.log           # 服务日志(自动生成)
│   └── service_error.log     # 错误日志(自动生成)
└── api_auth.db               # 数据库(自动生成)
```

## 常见问题解决
问题1: "访问被拒绝"错误
- 解决: 确保以管理员身份运行所有bat文件

问题2: 服务启动失败
- 解决: 检查 service_error.log 文件查看具体错误

问题3: Python找不到
- 解决: 确保Python已安装并在系统PATH中

问题4: 端口5000被占用
- 解决: 服务会自动使用5000端口，确保该端口未被其他程序占用

## 服务管理命令（命令行方式）
```angular2html
:: 启动服务
net start LanAuthGate

:: 停止服务  
net stop LanAuthGate

:: 重启服务
net stop LanAuthGate
net start LanAuthGate

:: 查看服务状态
sc query LanAuthGate

:: 删除服务
nssm remove LanAuthGate confirm
```

这样安装后，LanAuthGate就会作为Windows服务运行，具备：

✅ 开机自动启动

✅ 崩溃自动重启

✅ 系统后台运行

✅ 完整的日志记录

✅ 标准的服务管理界面