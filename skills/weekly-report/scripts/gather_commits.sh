#!/usr/bin/env bash
# gather_commits.sh — 抓取 oneos-multi-* 仓库中本人(luoshunyuan)在指定时间段的提交。
#
# 用法:
#   ./gather_commits.sh [start_date] [end_date] [repo_root]
#   日期格式: YYYY-MM-DD。不传则默认 本周一 至 今天。
#   repo_root 默认 /home/me/pd-cmiot
#
# 设计要点(为什么这么写):
# - --author=luoshunyuan 只抓本人提交。当前 os 仓库在 mnt_ns 分支,裸 git log 会把
#   别人(jiangqiping/tangjin/penghe/houyunbin)合并进来的提交也带出来,污染周报。
# - --no-merges 排除 Merge pull request 提交,只留实质改动。
# - 遍历 oneos-multi-* 目录而非硬编码 4 个仓库,新增仓库自动覆盖。
# - 输出按日期升序、每行标注 [仓库名],便于后续按时间混合汇总成周报。
set -euo pipefail

start="${1:-}"
end="${2:-}"
repo_root="${3:-/home/me/pd-cmiot}"

# 默认: 本周一 到 今天。Git log 的 --since/--until 接受 ISO 日期。
if [ -z "$start" ]; then
    # 计算本周一: 当前日期减去 (周几-1) 天。date +%u 周一=1...周日=7
    dow=$(date +%u)
    start=$(date -d "$((dow-1)) days ago" +%Y-%m-%d)
fi
if [ -z "$end" ]; then
    end=$(date +%Y-%m-%d)
fi

author="luoshunyuan"

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
fi
