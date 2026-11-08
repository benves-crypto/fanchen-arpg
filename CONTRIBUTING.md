# 跨设备开发

所有设备使用同一个 GitHub 仓库 `benves-crypto/fanchen-arpg`。使用 Godot 4.7.2 **Standard** 和 GDScript；Mac Apple Silicon 使用 macOS 版本，公司电脑使用对应 Windows 或 macOS 版本，Cloud 和 CI 使用 Linux x86_64 版本。不要把 Linux 可执行文件当作其他系统的编辑器使用。

## 同步和合并

1. 首次在电脑上克隆仓库，用 Godot 打开根目录的 `project.godot`（项目文件加入后）。
2. 开始工作前切换到 `main`，执行 `git pull --ff-only`，再创建 `git switch -c feature/功能名`。
3. 保存场景、脚本、资源和生成在源码旁的 `.uid`、`.import` 元数据；不要提交 `.godot/` 缓存、APK、密钥或签名信息。大型素材先商议 Git LFS 策略。
4. `git status` 和 `git diff` 检查后提交并推送功能分支，在 GitHub 创建 PR；检查通过、审阅后合并。换设备时先同步 `main`，或检出并拉取同一功能分支。
5. 手机端登录同一 ChatGPT 账号，选择已发布的 Cloud 环境，继续同一云端任务；改动须提交推送到功能分支，其他设备才能拉取。云端任务各有独立工作区，不是实时共享文件夹。

发生冲突时先保留双方工作：`git status` 查看冲突文件，逐个处理冲突标记，在 Godot 中重新打开场景确认引用，运行检查后 `git add` 并完成合并。二进制素材不要直接拼接，沟通后选定版本或重新制作；不要强推覆盖他人的工作。

## 本地检查

- `python3 scripts/check_paths.py`（Windows 可用 `py -3 scripts/check_paths.py`）检查大小写冲突和 Windows 不支持的路径。资源引用的大小写也必须与实际路径一致；此脚本不能证明所有引用正确。
- 安装对应平台的 Godot 4.7.2 Standard 和同版本导出模板。项目存在后运行 `godot --headless --editor --path . --import`，在 Windows 使用 Godot 可执行文件的实际路径。
- 约定自动化测试入口为 `tests/run_tests.gd`；存在时运行 `godot --headless --path . --script res://tests/run_tests.gd`，测试失败时以非零状态退出。
- 在 Godot 创建名为 `Android` 的导出预设并提交 `export_presets.cfg`，不要在其中保存密码。按 Godot Android 文档配置 OpenJDK 17、Android SDK 和本机 debug keystore，使用 `godot --headless --path . --export-debug Android 输出路径.apk`。

GitHub Actions 在 Linux 检查路径、安装 Standard 编辑器及模板、导入项目、执行约定的测试并尝试生成 Android Debug APK。项目、测试或导出预设尚未加入时，工作流显示警告并跳过对应步骤；绿色状态不代表这些步骤已验证。APK 仅作为 Actions 构建产物保存，debug 密钥在每次运行时临时生成，不用于发布。

`.gitattributes` 将文本规范为 LF；Windows 执行 `git config core.autocrlf false` 可避免自动转换。文件和资源引用大小写保持一致，避免在 macOS/Windows 可用但 Linux 失败。不要提交 `.env`、私钥、令牌、keystore 或密码；忽略规则不是秘密扫描器，提交前仍需检查。
