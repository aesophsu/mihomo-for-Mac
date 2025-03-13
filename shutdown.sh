#!/bin/bash

# 关闭mihomo服务
PID_NUM=`ps -ef | grep [m]ihomo-linux-a | wc -l`
PID=`ps -ef | grep [m]ihomo-linux-a | awk '{print $2}'`
if [ $PID_NUM -ne 0 ]; then
	kill -9 $PID
	# ps -ef | grep [m]ihomo-linux-a | awk '{print $2}' | xargs kill -9
fi

# 清除环境变量
> /etc/profile.d/mihomo.sh

echo -e "\n服务关闭成功，请执行以下命令关闭系统代理：proxy_off\n"
