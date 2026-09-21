#!/usr/bin/env bash
# gather_commits.sh — 抓 oneos-multi-* 仓库中本人 本周一~周五 的提交。
#
# 用法:
#   ./gather_commits.sh [repo_root]      # 默认本周一~周五
#   ./gather_commits.sh 2026-09-01 2026-09-05 [repo_root]   # 指定起止
#
# 日期默认本周一~周五:工作周期固定,不搞 fallback。周五还没到就抓到当天为止。
#
# 配置(避免硬编码个人身份进 public skill):
#   读 skill 目录下 references/git-author.conf 两行:
#     author=<git 用户名或 email>
#     repo_root=<oneos-multi-* 仓库根目录>
#   该文件含个人信息,.gitignore 排除,不入仓库。缺失时打印提示 exit 2,模型据此问用户。
#
# 输出:每个提交附 stat 摘要(改了哪些文件、增删行数),不只是 subject——
# 周报要看代码改了什么,subject 常太粗(如 "fix: xx")。
set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
conf="$skill_dir/references/git-author.conf"

author=""
default_root=""
if [ -f "$conf" ]; then
    author=$(grep -E '^author=' "$conf" | cut -d= -f2- | head -1 || true)
    default_root=$(grep -E '^repo_root=' "$conf" | cut -d= -f2- | head -1 || true)
fi
if [ -z "$author" ]; then
    echo ">>> 配置缺失: references/git-author.conf 未定义 author。"
    echo ">>> 问用户: git 提交用户名/email? oneos-multi-* 仓库根目录? 写入 $conf (author=xxx / repo_root=/path) 后重跑。"
    exit 2
fi

# 解析参数: 0 个=默认;2+ 个=start end [repo_root];1 个若像日期=start,否则=repo_root
start=""; end=""; repo_root="$default_root"
if [ $# -ge 2 ]; then
    start="$1"; end="$2"; [ $# -ge 3 ] && repo_root="$3"
elif [ $# -eq 1 ]; then
    case "$1" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) start="$1" ;;
        *) repo_root="$1" ;;
    esac
fi

if [ -z "$repo_root" ]; then
    echo ">>> 配置缺失: repo_root 未定义。问用户: oneos-multi-* 仓库根目录在哪? 写入 $conf 后重跑。"
    exit 2
fi

# 默认本周一~周五。date +%u: 周一=1...周日=7。
if [ -z "$start" ] || [ -z "$end" ]; then
    dow=$(date +%u)
    start=$(date -d "$((dow-1)) days ago" +%Y-%m-%d)
    # 周五 = 周一 + 4 天。若今天不到周五(周一~周四写周报),end 取今天,不抓到未来。
    friday=$(date -d "$((dow-1)) days ago +4 days" +%Y-%m-%d)
    today=$(date +%Y-%m-%d)
    if [[ "$friday" > "$today" ]]; then end="$today"; else end="$friday"; fi
fi

echo "=== 周报抓取: $start ~ $end (author: $author) ==="
echo ""

found=0
for repo_dir in "$repo_root"/oneos-multi-*/; do
    [ -d "$repo_dir/.git" ] || continue
    name=$(basename "$repo_dir")

    # 每个提交: 日期+subject + stat 摘要(文件名+增删行数)。--no-merges 排除 merge。
    log=$(git -C "$repo_dir" --no-pager log \
        --author="$author" --no-merges \
        --since="$start" --until="$end" --date=short \
        --pretty=format:"COMMIT %ad %s" --stat --stat-width=120 2>/dev/null || true)

    dirty=$(git -C "$repo_dir" status --short 2>/dev/null || true)
    [ -z "$log" ] && [ -z "$dirty" ] && continue

    found=1
    echo "### $name"
    [ -n "$log" ] && echo "$log" || echo "  (本周无已提交改动)"
    [ -n "$dirty" ] && { echo "[未提交改动]:"; echo "$dirty"; }
    echo ""
done

if [ "$found" -eq 0 ]; then
    echo ">>> $start ~ $end 无本人提交或未提交改动。"
    echo ">>> 若不是周五,可能本周还没提交。可手动指定范围: ./gather_commits.sh 上周一 下周五"
    exit 1
fi
