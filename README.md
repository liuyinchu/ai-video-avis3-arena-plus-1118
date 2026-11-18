# AVIS3 Arena Plus · 三份隔振答卷

Evaluation-1108 的独立补充片，聚焦新增的 16 号 Claude Fable 5.2、13 号 GPT-6.2 Astra 和 17 号 GPT-6.2 Sol。影片以三人的逐场积分开场，简述隔振任务，最后落在 2026 年 11 月 18 日的完整 17 席榜单。

[成片 MP4](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/releases/download/backup-20261118/AVIS3-Plus-1118.mp4) · [简体中文字幕 SRT](out/AVIS3-Plus-1118.zh-Hans.srt) · [原版发布封面](out/publish/AVIS3-Plus-1118-cover.jpg) · [视频简介](out/publish/AVIS3-Plus-1118-description.txt)

片长 2 分 7.5 秒，1920 × 1080，30 fps。画面采用烧录中文字幕。配乐沿用原片的合成器、鼓组和 128 BPM 节拍，为本片的九个分镜重新编排。两片可连续播放。


## 普通话配音版


[配音成片](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/releases/download/backup-20261118/AVIS3-Plus-1118-Breeze.mp4) · [口播字幕](out/AVIS3-Plus-1118-Breeze.zh-Hans.srt) · [全长独立人声 WAV](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/releases/download/backup-20261118/AVIS3-Plus-1118-Breeze-voice.wav)

中文版使用自部署的 Breeze TTS 2 设计一位普通话女解说员，再用本片生成的参考声逐句合成。全片九个分镜，24 段旁白。字幕保留标准模型名和阿拉伯数字，合成文本把型号、人名和小数转换为自然口播。配乐在人声前平滑降低，在解说停顿后回升。独立人声从成片零点开始对齐，可直接放入剪辑时间线。

**调整旁白**。编辑 [口播稿](voice/script.json) 中的 `caption` 和 `speech`。原始 24 kHz 单声道 WAV、参考声和生成记录保存在 [配音素材目录](voice/takes/)。合成使用同一段任务专用参考声，没有使用真人录音。

**用现有素材导出**。在工程根目录运行以下脚本，分别生成配音版文件和核验报告。配乐、分镜和全部配音素材均随工程提供。

```bash
bash scripts/render-voiced.sh
bash scripts/verify-voiced.sh
```

**重录一句**。按本次给定的 HPC 规范和 Breeze TTS 指南进入已就绪的 Slurm 服务，建立本机回环 SSH 隧道，并配置 `BREEZE_API_BASE` 和 `BREEZE_TOKEN`。执行 `node scripts/breeze-takes.mjs pair-2` 可重新生成改动过的对应句子，随后再次导出。省略句子编号时会依次检查全部素材。生成脚本按文本、参数和参考声指纹复用已有录音。

**声音与检查**。配音由 BreezeBlue 的 Breeze TTS 2 生成，本次合成作业为 41256。模型及自部署输出的使用条款见模型随附的 BreezeBlue Research and Non-Commercial License Agreement v1.1。最终 MP4 的解码、响度与逐句音轨对齐结果保存在 `build/voiced/review/verification.json`，实际字幕时点、语速与混音增益见 `build/voiced/placement.json`。[Breeze TTS 2 模型说明](https://huggingface.co/BreezeBlue/Breeze-TTS-2)

## 分镜

| 起点（分:秒） | 内容 |
| --- | --- |
| 0:00.0 | 三位新选手的 20 场积分，共用纵轴 |
| 0:07.5 | 隔振闭环、共同场景与积分排名方式 |
| 0:18.8 | 16 号 Fable 的启动标定、实际动作反馈和增益修正 |
| 0:33.8 | 13 号 Astra 的三音探测、辨识、预测和限幅分配 |
| 0:48.8 | Astra 与 Fable 的 20 个配对差值 |
| 1:03.8 | 17 号 Sol 的观测创新、并行预演和三档反馈 |
| 1:18.8 | Sol 的 20 个逐场积分、极值和阈值计数 |
| 1:33.8 | 共同第 1 场的 y₁ 位移等效 ASD，与同场无控制基线比较 |
| 1:48.8 | 更新后的 17 席正式榜单、完成轮数和数据出处 |

## 修改与导出

- [时间轴与字幕](src/edit.json) 按小节定位画面和配乐，字幕的 `at` 使用当前分镜内的秒数。`sections` 控制配乐段落。
- [选手画面](src/Profiles.swift) 包含三位选手的策略图。[比较图](src/Charts.swift) 绘制配对差值、逐场积分和频谱。[首尾及赛制](src/Bookends.swift) 包含标题、控制回路、全榜和字幕排版。
- [字体、配色与绘图](src/Canvas.swift) 统一画面样式。[配乐源文件](scripts/score.mjs) 可以重新合成随工程保存的立体声 WAV。
- [公开成绩](data/results.json) 保留三位选手的完整精度逐轮积分及 17 席排名。[频谱绘图数据](data/spectrum.json) 保留本片所用的公开真值、无控制基线和对应频率。

在工程根目录执行以下命令。导出使用 macOS 的 Swift、Core Graphics、AVFoundation，以及 Node.js 和 FFmpeg。远端制作机已具备这些工具。

```bash
bash scripts/render.sh
bash scripts/verify.sh
```

输出位于 `out/`，渲染中间文件和技术核验结果位于 `build/`。在其他 Mac 上可以使用 PATH 中的 `ffmpeg` 和 `ffprobe`，或者将两者所在的目录传给 `AVTOOLS_DIR`。制作机默认也能调用相邻原片工程内的 Remotion 编码工具。图表和配乐直接使用工程中的数据与素材。

渲染后可以按秒查看某个分镜的原尺寸帧。例如下面的命令导出逐场对照图。

```bash
build/film still 57 build/pair.jpg
```

## 正式成绩与图表

| 编号 | 选手 / 平台 | 17 席排名 | 20 轮均分 ± 样本标准差（s） | 最低–最高（s） |
| --- | --- | ---: | ---: | ---: |
| 13 | GPT-6.2 Astra / Codex | 3 | 834.161103 ± 18.830826 | 779.547006–851.504347 |
| 16 | Claude Fable 5.2 / Claude Code | 4 | 833.334862 ± 21.102081 | 773.430018–852.429029 |
| 17 | GPT-6.2 Sol / Codex | 9 | 404.116973 ± 328.872214 | 1.894154–755.542149 |

三位选手各完成原批次的 20 个共同场景，规则失败数均为零。总榜按原始积分算术平均排序，单位为秒。样本标准差的分母为 19。字幕中的“自述”来自选手正式提交的报告，画面中的探测波形、滤波器和信号连线为策略示意。

配对差按同一场景的 13 号积分减去 16 号积分计算。两位选手各领先 10 场，平均差为 +0.826241 s。17 号低于 100 s 和高于 700 s 的场数分别为 8 和 6，中间区间另有 6 场。

频谱取共同第 1 场的第 1 路输出，横轴为 0.01–100 Hz，纵轴为位移等效 ASD（m/√Hz）。曲线在对数频带内取 ASD 的均方根以便显示。侧栏 0.8–1.2 Hz 的数值直接使用原频率网格的 41 个点，先求各自的均方根，再除以同场、同通道无控制基线的均方根。频谱图描述这一场这一通道，正式排名汇总三路真实速度的 20 轮积分。

## 来源与复核

正式扩展记录来自开发仓库 `avis3-arena` 的 `evaluations/Evaluation-1108/extensions/`。

- `a64741a` 的 `official-016-20261117/` 提供 16 号的正式得分、身份和自述。
- `1e359f2` 的 `official-013-017-20261118/` 提供 13、17 号的正式得分、身份和自述。其 `leaderboard-17.json` 决定片中所有名次。
- 同一提交的 `evaluations/Evaluation-1108/website/spectra/baseline-round-01.json` 提供共同第 1 场基线。三位选手的对应归档仅导出 `truth.frequency_hz` 与 `truth.displacement_asd`。
- 原片工程 `ai-video-1108-opus/video/` 提供配乐合成源和视听参照。本片保留了两片一致的画幅、帧率、电子音色和来源标签。

随片数据足够重渲染。若需从归档重新取数，使用 `node scripts/import-results.mjs` 复算积分、标准差和排名，使用 `node scripts/import-spectrum.mjs` 提取频谱。`ARENA_REPO` 可指定竞技场 Git 仓库。频谱提取读取 `ARENA_ARCHIVE_HOST` 和 `ARENA_ARCHIVE_EXTENSIONS`，分别指定归档机 SSH 目标和 Evaluation-1108 的扩展根目录。`ARENA_ARCHIVE_KEY` 可指定已有 SSH 身份文件。

交付前已完整解码 3,825 个视频帧，核对 24 条字幕、音视频时长及九段左右声道与配乐母带的同步。成片综合响度 −17.95 LUFS，真峰值 −2.58 dBTP。逐项核验数值保存在 `build/review/delivery.json`。
