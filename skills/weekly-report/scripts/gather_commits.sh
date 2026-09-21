#!/usr/bin/env bash
# gather_commits.sh — 抓取 oneos-multi-* 仓库中本人在指定时间段的提交。
#
# 用法:
#   ./gather_commits.sh [start_date] [end_date] [repo_root]
#   日期格式: YYYY-MM-DD。不传则默认 本周一 至 今天。
#   repo_root 不传则从配置文件读,配置也没有则报错让模型问用户。
#
# 配置(避免把个人身份/路径硬编码进 public skill):
#   脚本读 skill 目录下的 references/git-author.conf,内容两行:
#     author=<你的 git 用户名,如 luoshunyuan>
#     repo_root=<你的工作仓库根目录,如 /home/me/pd-cmiot>
#   该文件含个人信息,已 .gitignore,不入仓库。首次不存在时本脚本打印
#   配置缺失提示,模型据此问用户、写入配置,后续直接读。
#
# 设计要点(为什么这么写):
# - --author 只抓本人提交。os 仓库常驻个人特性分支,裸 git log 会把
#   别人合并进来的提交也带出来,污染周报。author 取自配置而非硬编码。
# - --no-merges 排除 Merge pull request 提交,只留实质改动。
# - 遍历 oneos-multi-* 目录而非硬编码 4 个仓库,新增仓库自动覆盖。
# - 输出按日期升序、每行标注仓库名,便于后续按时间混合汇总成周报。
set -euo pipefail

# 定位 skill 目录: 脚本在 <skill>/scripts/ 下,往上一层即 skill 根
skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
conf="$skill_dir/references/git-author.conf"

# 读配置: 文件不存在或字段缺失时,打印结构化提示让上层模型去问用户。
# 不在这里交互式 read — 脚本要保持非交互、可被子 agent 调用。
author=""
default_root=""
if [ -f "$conf" ]; then
    # shellcheck disable=SC1090
    author=$(grep -E '^author=' "$conf" | cut -d= -f2- | head -1 || true)
    default_root=$(grep -E '^repo_root=' "$conf" | cut -d= -f2- | head -1 || true)
fi

if [ -z "$author" ]; then
    echo ">>> 配置缺失: skill 目录下 references/git-author.conf 未定义 author。"
    echo ">>> 请问用户: 你在这些仓库里提交用的 git 用户名/email 是什么? 以及工作仓库根目录?"
    echo ">>> 拿到后写入 $conf (两行: author=xxx / repo_root=/path/to/repos),再重跑本脚本。"
    exit 2
fi

start="${1:-}"
end="${2:-}"
repo_root="${3:-$default_root}"

if [ -z "$repo_root" ]; then
    echo ">>> 配置缺失: references/git-author.conf 未定义 repo_root,也没通过命令行第3参数传。"
    echo ">>> 请问用户: 你的 oneos-multi-* 仓库根目录在哪?"
    exit 2
fi

# 默认: 本周一 到 今天。Git log 的 --since/--until 接受 ISO 日期。
if [ -z "$start" ]; then
    # 计算本周一: 当前日期减去 (周几-1) 天。date +%u 周一=1...周日=7
    dow=$(date +%u)
    start=$(date -d "$((dow-1)) days ago" +%Y-%m-%d)
fi
if [ -z "$end" ]; then
    end=$(date +%Y-%m-%d)
fi

echo "=== 周报抓取范围: $start ~ $end (author: $author) ==="
echo ""

found_any=0

for repo_dir in "$repo_root"/oneos-multi-*/; do
    [ -d "$repo_dir/.git" ] || continue
    repo_name=$(basename "$repo_dir")

    # --author 模糊匹配 name 或 email;--no-merges 去掉 Merge 提交
    commits=$(git -C "$repo_dir" --no-pager log \
        --author="$author" \
        --no-merges \
        --since="$start" \
        --until="$end" \
        --date=short \
        --pretty=format:"%ad | %s" 2>/dev/null || true)

    # 未提交的工作区改动(status),这一块也属于"这周干了什么"
    dirty=$(git -C "$repo_dir" status --short 2>/dev/null || true)

    if [ -z "$commits" ] && [ -z "$dirty" ]; then
        continue
    fi

    found_any=1
    echo "### $repo_name"
    if [ -n "$commits" ]; then
        echo "$commits" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "  (本周无已提交改动)"
    fi
    if [ -n "$dirty" ]; then
        echo "  [未提交改动]:"
        echo "$dirty" | while IFS= read -r line; do
            echo "    $line"
        done
    fi
    echo ""
done

if [ "$found_any" -eq 0 ]; then
    echo ">>> 注意: 该时间段内未抓到本人提交或未提交改动。"
    echo ">>> 可能原因: (1) 本周刚开始还没有提交 (2) start/end 日期需调整"
    echo ">>> 建议: 用更大范围重试, 如 ./gather_commits.sh 2026-09-01 $end"
    exit 1
fi
