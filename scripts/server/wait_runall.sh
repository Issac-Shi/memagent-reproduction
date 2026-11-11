#!/bin/bash
# 用法：wait_runall.sh <C|B|done> [最长分钟，默认 60]
# 等 run_all.log 里出现指定阶段的标记，然后打印日志末尾。
#   C    ：C 组服务就绪或放弃（或已经全部完成）
#   B    ：B 组服务就绪或放弃（或已经全部完成），此时 C 组已跑完
#   done ：全部完成
# 退出码：等到了为 0，超时为 1。
# 模式写在脚本里，是为了避开 Windows PowerShell 5.1 经 ssh 传参时吞掉双引号的问题。
LOG=/root/autodl-tmp/logs/run_all.log
case "$1" in
  C|B)  PAT="$1 组服务就绪|$1 组服务起不来|$1 组服务启动失败|$1 组服务 30 分钟|全部完成" ;;
  done) PAT='全部完成' ;;
  *)    echo "用法：$0 <C|B|done> [最长分钟]"; exit 2 ;;
esac
MAX=${2:-60}
for ((i = 0; i < MAX * 3; i++)); do
  grep -qE "$PAT" "$LOG" && break
  sleep 20
done
date
tail -n 12 "$LOG"
if [ "$1" != done ] && [ -f "/root/autodl-tmp/logs/serve_$1.log" ]; then
  echo "-- serve_$1 引擎与显存"
  grep -E 'Initializing a V|chunked|# cuda blocks|Maximum concurrency|max_model_len' "/root/autodl-tmp/logs/serve_$1.log" | head -n 6 | cut -c1-300
fi
grep -qE "$PAT" "$LOG"
