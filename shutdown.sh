#!/bin/bash

# 获取 Mihomo 进程 ID
PID=$(ps -ef | grep "[m]ihomo -d" | awk '{print $2}')

# 判断是否有 Mihomo 进程在运行
if [ -n "$PID" ]; then
    echo "正在关闭 Mihomo 服务 (PID: $PID)..."
    kill -9 $PID
    echo "Mihomo 服务已关闭。"
else
    echo "Mihomo 服务未运行。"
fi

echo -e "\n服务关闭成功，请执行以下命令关闭系统代理：source $Server_Dir/proxy.sh && proxy_off\n"
