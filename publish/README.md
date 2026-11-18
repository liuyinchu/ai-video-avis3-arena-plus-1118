# 三份隔振答卷 · 发布素材

这组素材对应[电子配乐原版](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/releases/download/backup-20261118/AVIS3-Plus-1118.mp4)。[视频简介](../out/publish/AVIS3-Plus-1118-description.txt)可直接复制；[封面 PNG](../out/publish/AVIS3-Plus-1118-cover.png) 与[封面 JPG](../out/publish/AVIS3-Plus-1118-cover.jpg)均为 1920 × 1080。

隔振装置是用内置 ImageGen 生成的概念插画。[生成提示词](imagegen-prompt.txt)和[未加字主视觉](isolator.png)都保存在本目录。标题、排名和色块由 [Cover.swift](Cover.swift) 排版，沿用影片的字体和选手配色。20 个色块按正式场景顺序绘制，蓝色为 13 号 Astra 领先，橙色为 16 号 Fable 领先。均分差以正式积分的秒为单位，封面四舍五入到两位小数。

在工程根目录重新导出封面：

```sh
mkdir -p build/cover out/publish
swiftc -O -module-cache-path build/swift-cache src/Canvas.swift src/FilmData.swift publish/Cover.swift -o build/cover/render-cover
build/cover/render-cover
```
