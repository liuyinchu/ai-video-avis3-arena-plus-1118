# 完整工程备份

[2026-11-18 Release](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/releases/tag/backup-20261118) 提供完整压缩包、成片和常用交付文件。完整包保存当时远端的整个 `ai-video-1118-astra/`，包括两版影片、全部音轨、封面、构建缓存、逐帧检查材料和中间文件。原版为 2 分 7.5 秒的电子配乐版，中文配音版单独保留。

- [完整归档](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/releases/download/backup-20261118/ai-video-1118-astra-full-20261118.tar.zst)覆盖 544 个普通文件和 29 个目录，原文件合计 504,330,370 字节。
- [逐文件清单](project-files.json)记录相对路径、类型、权限、修改时间，及每个普通文件的字节数与 SHA-256。[发布附件校验表](SHA256SUMS.txt)可以核对下载内容。
- [数据分支](https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118/tree/snapshot-data/20261118)留存 19 个有独立 SHA-256 的分块。[parts-commit](parts-commit)固定了完整分块的 Git 提交。

## 从 Release 恢复

将完整归档下载至单独的恢复目录。其 SHA-256 为 `24b33c539c6b361e7408f1aa933becb253bb199ab3b530c7f9ed1b591a26fddf`。在该目录执行以下命令，可还原原始项目树。

```sh
zstd -dc ai-video-1118-astra-full-20261118.tar.zst | tar -xpf -
```

## 从 Git 分块恢复

在主分支运行以下命令。脚本使用 Git、Bash、Ruby、tar 和 zstd，逐块验证 SHA-256，重组后核对归档哈希，再对解压出的文件树做完整比对。目标里会同时得到完整归档和工程目录。

```sh
bash backup/restore.sh ../avis3-restored
```
