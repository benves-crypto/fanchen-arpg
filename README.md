# 凡尘修仙录 · 竹林试炼

启动后点击「开始试炼」进入 1-1。后两关通过试炼门直接进入。剑修和远程法师可以随时切换，生命、等级与药品会带入下一关。死亡后可在结算界面从 1-1 重新开始。

- **1-1 竹径初试**　击败两只野狼、两只毒蛛和石环里的熔甲兽，穿过东侧试炼门。熔甲兽掉落的封口丹罐可在北侧祭坛献祭，击败伏击敌人可在最终结算获得「破阵」评价。
- **1-2 竹影围猎**　清理八只野狼和毒蛛，唤醒精英熔甲兽。击败精英后，试炼门通往 1-3。
- **1-3 兽王石环**　迎战熔甲兽王。观察扇形弹幕和震地预警，半血后兽王会加快攻击并扩大弹幕。击败兽王后穿过试炼门结算。

最终得分包含实际伤害、完美闪避或换人及招架、过关进度、通关用时和祭坛奖励。通关成绩按总分排名，同分时用时较短的排在前面。点击顶部奖杯或按 **F2** 查看本机前五名。

## 运行

用 Godot **4.7.2 Standard** 导入根目录的 `project.godot`，打开项目后按 **F5** 或点击「运行项目」。项目使用 GDScript 与 Compatibility 渲染器。

| 操作 | PC | Android |
| --- | --- | --- |
| 移动、转向 | WASD 或方向键 | 左下虚拟摇杆 |
| 普攻 | J 朝当前方向攻击，鼠标左键朝光标攻击；按住蓄力，松手出招 | 右下攻击，支持长按 |
| 技能一 | K | 右下技能一按钮 |
| 闪避 | 空格 | 右下闪避 |
| 技能二 | E | 技能二按钮 |
| 绝招 | R | 绝招按钮 |
| 切换出战角色 | Tab | 切换按钮 |
| 使用血瓶 | Q（5 秒冷却） | 血瓶按钮 |
| 队伍信息 / 人物状态 / 背包 | P / C / I | 对应菜单图标 |
| 设置 / 暂停 | Esc | 设置图标 |
| 继续试炼 | Esc 或 Enter | 「继续试炼」 |
| 重新开始 | 暂停或结算时按 Shift+R | 「重新开始」 |

在 PC 上打开「设置 → 键位设置」，选择要修改的操作并按下新键。修改立即生效。「保存为默认」会在下次启动时加载当前方案，「恢复已保存」可撤销未保存的改动，「出厂键位」可恢复初始方案。

在「设置」中可以分别切换音乐和音效的「8-bit / 标准」风格。两项默认使用 8-bit，修改后自动保存。标准音效含林间鸟鸣。

游戏默认使用修仙皮肤，可在设置中切换。两名角色的普攻均可按住约 0.72 秒蓄满，松手造成 2.2 倍普攻伤害。受击、闪避、施法或切换角色会取消蓄力。血瓶冷却由全队共享。

剑修近身挥剑，蓄满后攻击周围敌人。技能一「御剑术」发出剑气并消耗 MP。

远程法师短按发射灵弹，蓄满后发射飞得更远的强化灵弹。灵弹沿瞄准方向飞行，遇到敌人或障碍物后消散。技能一「破空灵光」消耗 MP，向前发射飞得更快、更远的灵光。技能二「三才灵弹」同时发射三枚扇形弹体，绝招「八方灯阵」向八个方向释放灵焰。

敌人出手前会蓄力，近战会显示攻击范围，毒蛛会预告弹道。如果敌招将在 **0.12 秒**内命中，按闪避或切换角色可触发以下效果：

| 时机 | 反馈 | 无敌时间 | 反击伤害 |
| --- | --- | --- | --- |
| 极限闪避 | 青色残光 | 从闪避开始算 **0.30 秒**（普通闪避 **0.16 秒**） | 攻击力 × **1.8** |
| 精准换人 | 金色灵光 | 换入角色 **0.24 秒**（普通换人不额外提供无敌） | 攻击力 × **2.0** |

成功后 **0.85 秒**内按一次普攻，即可朝威胁来源打出反击；闪避途中可先按，翻滚结束自动出招。反击不消耗 MP，不占用普攻暴击计数，伤害仍扣除目标防御。

项目以 1280×720 横屏为基准，采用 `canvas_items` 和 `expand`。移动端按钮沿安全区域边缘摆放，可同时移动和使用招式。

## 工程与验证

- `scenes/main.tscn` 是试炼入口，`scenes/actors/` 放置角色场景。
- `scripts/actors/` 负责角色控制和敌人行为，`scripts/combat/` 负责生命与弹体，`scripts/world/` 负责地图和任务，`scripts/ui/` 负责 HUD 和触控。
- 地表、竹径、场景地标和掉落药瓶贴图位于 `assets/world/`。战斗 HUD 在 `assets/ui/` 使用本项目提供的青玉金边参考图切片，并保留出战角色头像和竹林地图。药瓶按钮、冷却遮罩和激活光环由内置生图工具生成。法师四个技能按钮使用内置生图工具参考现有修仙 HUD 生成的透明图集 `cultivation_mage_icons.png`。
- CraftPix 地图素材取自 Forest Battle Backgrounds（草地、土路和地表装饰）、Bush Assets Pixel Art Pack（灌木和竹叶）、Fantasy Land Isometric Tileset（岩石、地标铺石）及 Ancient Temple Pixel Game Backgrounds（试炼门柱）。药瓶取自 Cyberpunk Medicine Icons 的无背景药罐（`34.png`）。
- CraftPix HUD 底板和仪表底材取自 Cartoon UI Elements Mini Kit，绝招图标取自 Earthbender Skills 32x32 Pixel Icon Pack（`PNG/Icon47.png`）。
- 背景音乐为 Cleyton Kauffman 的《Forest Whisper》，采用 CC0。 [曲目发布页](https://opengameart.org/content/forest-whisper-theme) · [作者主页](https://soundcloud.com/cleytonkauffman)
- 普攻、闪避、施法、受击、拾取、服药、敌方出招、换人、开门和结算音效取自 artisticdude 的 RPG Sound Pack，采用 CC0。 [音效包发布页](https://opengameart.org/content/rpg-sound-pack)
- 脚步声取自 Delta12 Studio 的草地音效，环境声取自 pauliuw 的林鸟录音并剪成循环。两者采用 CC0。 [脚步来源](https://opengameart.org/content/rpg-sound-effect-pack) · [林鸟录音来源](https://opengameart.org/content/forest-bird-sounds)
- 8-bit 音频取自随附的 `8bit-audio-CC0.zip`。曲目为 Ragnar Random 的《Lost Rune of the Wind Princess》，音效由 Juhani Junkala 制作，两者均采用 CC0。

```sh
python3 scripts/check_paths.py
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 15
```

Android 构建需要匹配版本的 Godot 导出模板、SDK 和 Android 导出预设。跨设备同步和 APK 构建流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。
