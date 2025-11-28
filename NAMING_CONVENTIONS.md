# LanAuthGate 命名规范指南

## 文件命名约定

### 可执行文件和压缩包
```
lan-auth-gate-[platform]-[architecture]-[version].[extension]
```

#### 组件说明：
- **lan-auth-gate**: 项目名称 (小写，连字符分隔)
- **platform**: 目标平台
  - `windows` - Windows平台
  - `linux` - Linux平台
  - `macos` - macOS平台
- **architecture**: 系统架构
  - `amd64` - x86_64/64位
  - `x86` - 32位
  - `arm64` - ARM 64位
  - `armv7` - ARM 32位
- **version**: 版本标识
  - 日期版本: `20241128` (推荐用于CI/CD)
  - 语义版本: `v1.2.3`
  - Git短哈希: `abc1234`
- **extension**: 文件扩展名
  - `zip` - ZIP压缩包 (推荐，通用性强)
  - `7z` - 7-Zip压缩包 (压缩率更高)
  - `tar.gz` - Linux压缩包

#### 示例：
```
lan-auth-gate-windows-amd64-20241128.zip
lan-auth-gate-linux-amd64-v1.2.3.tar.gz
lan-auth-gate-macos-arm64-abc1234.zip
```

### 内部文件命名
```
LanAuthGate.exe          # Windows可执行文件 (PascalCase)
lan-auth-gate             # Linux/macOS可执行文件 (小写连字符)
service-deploy.ps1        # PowerShell脚本 (动词-名词)
deploy.bat               # Batch脚本 (动词)
service.cmd             # 服务管理脚本
```

## 目录结构

### 构建输出目录
```
dist/
├── lan-auth-gate-windows-amd64-20241128.zip  # 最终发布包
├── windows/                                   # 构建工作目录
│   ├── app/                                  # 应用程序文件
│   │   ├── LanAuthGate.exe                   # 可执行文件
│   │   ├── static/                           # 静态资源
│   │   ├── templates/                        # 模板文件
│   │   └── logs/                             # 日志目录
│   ├── nssm/                                 # 服务管理工具
│   │   ├── win64/nssm.exe                    # 64位版本
│   │   └── win32/nssm.exe                    # 32位版本
│   ├── deploy.ps1                            # PowerShell部署脚本
│   ├── deploy.bat                            # Batch部署包装器
│   └── service.cmd                           # 服务管理命令
└── linux/                                    # Linux构建(如需要)
```

## GitHub Actions 集成

### 自动命名策略
```yaml
- name: Generate artifact name
  id: artifact
  run: |
    $platform = "windows"
    $arch = if ([Environment]::Is64BitOperatingProcess) { "amd64" } else { "x86" }
    $date = Get-Date -Format "yyyyMMdd"
    $commit = "${{ github.sha }}".Substring(0, 7)

    # 主要发布包
    $releaseName = "lan-auth-gate-$platform-$arch-$date"

    # 调试版本
    $debugName = "lan-auth-gate-$platform-$arch-debug-$commit"

    echo "release-name=$releaseName" >> $env:GITHUB_OUTPUT
    echo "debug-name=$debugName" >> $env:GITHUB_OUTPUT
```

### 发布策略
1. **主分支构建**: 使用日期版本 `lan-auth-gate-windows-amd64-20241128.zip`
2. **标签发布**: 使用语义版本 `lan-auth-gate-windows-amd64-v1.2.3.zip`
3. **PR构建**: 使用提交哈希 `lan-auth-gate-windows-amd64-abc1234.zip`

## 版本管理建议

### 开发版本
- 使用日期: `20241128` (每日构建)
- 使用时间戳: `20241128-143052` (频繁构建)

### 稳定版本
- 语义版本: `v1.2.3`
- 预发布版本: `v1.2.3-beta.1`, `v1.2.3-rc.1`

### 调试版本
- 添加 `-debug` 后缀: `lan-auth-gate-windows-amd64-debug-20241128.zip`
- 包含调试符号和详细日志

## 最佳实践

### ✅ 推荐做法
1. **使用ZIP格式**: GitHub Actions原生支持，用户无需额外软件
2. **清晰的平台标识**: 明确标注平台和架构
3. **自动化命名**: 通过脚本自动生成，避免手动错误
4. **版本一致性**: 压缩包名称与内部版本信息保持一致
5. **包含部署脚本**: 提供一键部署的PowerShell/Batch脚本

### ❌ 避免做法
1. **不要使用通用名称**: 如 `app.zip`, `release.zip`
2. **不要混合架构**: 一个包只包含单一架构的二进制文件
3. **不要省略版本**: 避免文件名重复导致覆盖
4. **不要使用特殊字符**: 避免空格、括号等特殊字符

## 兼容性考虑

### Windows平台
- 优先使用ZIP格式 (系统原生支持)
- 支持长路径名 (260+字符)
- 保留文件属性 (只读、隐藏等)

### 跨平台下载
- 使用小写字母和连字符
- 避免平台特定字符
- 考虑网络传输优化 (分卷压缩等)

这个命名规范确保了文件的一致性、可读性和自动化友好性。通过遵循这些约定，可以建立专业的发布流程并提高用户体验。