---
name: weekly-report
description: 生成周报。抓 oneos-multi-* 仓库本人周一~周五的 git 提交(含 stat 改动,不只看 log),按中文编号列表风格转写成草稿,和你确认补充后输出最终版。当用户说"写周报""生成周报""这周干了什么""weekly report""汇总本周工作"时使用,即使用户没提 git。
---

# 周报生成

抓本人周一~周五在 `oneos-multi-*` 仓库的 git 提交,看每个提交改了什么(subject + stat),按你的风格转写成中文编号列表草稿,确认补充后输出最终版。性能/评估/沟通等非代码工作 git 抓不到,在确认环节问用户补。

## 风格

中文编号列表,每条一句话讲清"做了什么 + 为什么 + 关键技术点"。例:
`修复 mnt_ns 中 fs_rec 悬空指针崩溃:释放后置空外层指针并在取 fd 前加 NULL 守卫。`
技术细节到模块和机制(sticky event / irqsave / poll_notify 持锁 post),不泛化成"优化性能"。代码、测试、评估、文档、沟通混在同一个编号列表,不强求分段。

**长度硬约束(重要)**:每条控制在 50 字以内,个别复杂的可到 95 字封顶。历史周报条目大多 25~50 字,最长 95 字(fs_rec 那条)。看 diff 是为了判断该写什么、避免编造,不是把 diff 细节铺进周报——"为什么 irqsave 能 cover=关调度而非仅关中断"这种推理过程不进周报,只留结论"poll_lock 改用 irqsave 阻止 post 持锁期间触发调度"。写完每条自查字数,超了就砍掉铺垫只留"动作+对象+根因/目的"。

## 流程

### 1. 抓取

```bash
bash <skill-path>/scripts/gather_commits.sh           # 本周一~周五
bash <skill-path>/scripts/gather_commits.sh 2026-09-14 2026-09-18   # 指定范围
```

脚本输出每个提交的 subject + stat(改了哪些文件、增删行数)。退出码:0=有内容,1=空,2=配置缺失。首次配置缺失(exit 2)时问用户 git 用户名 + 仓库根目录,写入 `references/git-author.conf` 再跑。**用户名不入 SKILL.md/脚本**,只存这个被 .gitignore 排除的本地配置。

脚本已处理两个坑:`--author` 过滤掉同事合并进来的提交(os 仓库常驻个人分支,裸 git log 会把别人的也算进来);`--no-merges` 排除 Merge 提交。不要自己手写 git log。

### 2. 转写草稿

看每个提交的 subject **和 stat**。subject 常太粗(如 `fix: xx`),stat 能看出改了哪个模块、增删多少、是不是删了整个接口——以此写"做了什么 + 为什么"。subject+stat 够写清的就**不必**去看 diff。只有 subject+stat 都判断不出改动意图时,才 `git show <hash>` 看 diff 真实内容来确认该写什么。**diff 用于判断,不进周报**——推理过程(为什么这么改能修好)留在脑子里,周报只留结论。例:
- subject `refactor(mnt_ns): drop os_semaphore_post_no_sched` + stat `os_sem.c 87 ---` → `移除 os_semaphore_post_no_sched 接口,irqsave 方案已覆盖该死锁场景。`
- subject `fix(mnt_ns): use os_spin_lock_irqsave for devfs poll_lock` + stat `pty.c/pipe_common.c/eventfd_dev.c` → `devfs poll_lock 改用 irqsave,阻止 post 在持锁期间触发调度。`

转写规则:
- 英文 subject → 中文,主谓宾完整。`fix`→修复XX:根因/做法,`feat`→新增,`refactor`→重构XX:目的,`test`→新增测试,`chore` 一般不进周报。
- 同模块同主题的小提交合并成一条,讲整体意图,不列碎片。
- subject + stat 都不够时**不要编**技术细节,在确认环节问用户。
- 每条 ≤50 字(复杂 ≤95 字),见上方"长度硬约束"。

草稿里每条标 commit 短日期(如 ` — 9.11`),方便用户对照历史周报查重。

### 3. 确认

贴草稿(不写文件),问用户:
1. 代码条目要合并/拆分/补细节吗?有重复报过的剔掉。
2. 这周有哪些非代码工作(性能/测试/文档/评估/code review)?逐条说,我来写。
3. 有本周做了但还没提交的?未提交改动具体在做什么,给我一句话。

### 4. 输出最终版

用户确认后,输出干净周报正文(去掉草稿标记、日期标注、确认问题),纯文本编号列表直接能贴。要存文件就问用户存哪,不假设路径。

## 已知坑

- **别人合并提交混进来**:os 仓库常驻个人特性分支,裸 git log 会带出同事提交。脚本 `--author` 过滤——这是用脚本而非手跑 git log 的原因。
- **非代码工作 git 抓不到**:性能数值、评估、沟通不在仓库里。不编造,确认环节问。
- **多仓库混合汇总**:bsp/cmake/os/user 的提交按时间混合成一条时间线,不按仓库分组。
