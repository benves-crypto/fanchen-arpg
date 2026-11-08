# 凡尘修仙录 · 竹林试炼

Demo V0.1 是一个 2D 俯视角即时战斗关卡。你扮演剑修，沿竹径向东，清理两只野狼和两只毒蛛。击败敌人获得经验，走近掉落的药品补充 HP 和 MP。清完小怪后，东侧石环的狼妖会苏醒。击败它并穿过亮起的试炼门，即可结算。死亡后可在结算界面重新开始。

## 运行

用 Godot **4.7.2 Standard** 导入根目录的 `project.godot`，打开项目后按 **F5** 或点击「运行项目」。项目使用 GDScript 与 Compatibility 渲染器。

| 操作 | macOS | Android |
| --- | --- | --- |
| 移动、转向 | WASD 或方向键 | 左下虚拟摇杆 |
| 普攻 | J 朝当前方向攻击，鼠标左键朝光标攻击 | 右下攻击 |
| 御剑术 | K | 右下御剑 |
| 闪避 | 空格 | 右下闪避 |
| 暂停 | Esc 或点「暂停」 | 点「暂停」 |

御剑术朝当前朝向发出剑气，消耗 MP。敌人出手前会蓄力，近战会显示攻击范围，闪避期间可避开伤害。项目以 1280×720 横屏为基准，采用 `canvas_items` 和 `expand`。移动端按钮沿安全区域边缘摆放，可同时移动和使用招式。

## 工程与验证

- `scenes/main.tscn` 是试炼入口，`scenes/actors/` 放置角色场景。
- `scripts/actors/` 负责角色控制和敌人行为，`scripts/combat/` 负责生命与弹体，`scripts/world/` 负责地图和任务，`scripts/ui/` 负责 HUD 和触控。
- 原创临时像素图形由脚本绘制。换正式角色图时可替换 `Visual` 子树，保持受击动画和 `pose()`、`pulse()` 接口，角色碰撞与战斗数值无需跟着重写。

```sh
python3 scripts/check_paths.py
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 15
```

Android 构建需要匹配版本的 Godot 导出模板、SDK 和 Android 导出预设。跨设备同步和 APK 构建流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。
