#!/bin/bash

# 自定义action函数
success() {
  echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
  return 0
}

failure() {
  local rc=$?
  echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
  [ -x /bin/plymouth ] && /bin/plymouth --details
  return $rc
}

action() {
  local STRING rc

  STRING=$1
  echo -n "$STRING "
  shift
  "$@" && success $"$STRING" || failure $"$STRING"
  rc=$?
  echo
  return $rc
}

# 函数，判断命令是否正常执行
if_success() {
  local ReturnStatus=$3
  if [ $ReturnStatus -eq 0 ]; then
    success "$1"
  else
    failure "$2"
    exit 1
  fi
}

# 定义路径变量
Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
Conf_Dir="$Server_Dir/conf"
Log_Dir="$Server_Dir/logs"

## 关闭 Mihomo 服务
Text1="服务关闭成功！"
Text2="服务关闭失败！"
# 查询并关闭程序进程
PID=$(ps -ef | grep "[m]ihomo -d" | awk '{print $2}')
if [ -n "$PID" ]; then
	echo "正在关闭 Mihomo 服务 (PID: $PID)..."
	kill -9 $PID
  ReturnStatus=$?
	echo "Mihomo 服务已关闭。"
else
	echo "Mihomo 服务未运行。"
  ReturnStatus=0
fi
if_success "$Text1" "$Text2" "$ReturnStatus"

sleep 3

## 重新启动 Mihomo 服务
echo -e '\n正在启动 Mihomo 服务...'
Text5="服务启动成功！"
Text6="服务启动失败！"

$Server_Dir/bin/mihomo -d $Conf_Dir &> $Log_Dir/mihomo.log &
ReturnStatus=$?
if_success "$Text5" "$Text6" "$ReturnStatus"
