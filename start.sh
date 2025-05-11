#!/bin/bash

#################### 脚本初始化任务 ####################

# 获取脚本工作目录绝对路径
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 加载.env变量文件
source "$Server_Dir/.env"

# 定义必要的目录
Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"
Dashboard_Dir="$Server_Dir/dashboard/public" # 设置为 $Server_Dir/dashboard/public

# 将 CLASH_URL 变量的值赋给 URL 变量，并检查 CLASH_URL 是否为空
URL=${CLASH_URL:?Error: CLASH_URL variable is not set or empty}

# 获取 CLASH_SECRET 值，如果不存在则生成一个随机数
Secret=${CLASH_SECRET:-$(openssl rand -hex 32)}

#################### 函数定义 ####################

# 自定义action函数，实现通用action功能
action() {
	local STRING="$1"
	echo -n "$STRING "
	shift
	if "$@"; then
		echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
		echo ""
		return 0
	else
		local rc=$?
		echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
		echo ""
		return $rc
	fi
}

# 启动 Mihomo 服务并返回 PID
start_mihomo() {
	echo -n "启动Mihomo服务 "
	"$Server_Dir/bin/mihomo" -d "$Conf_Dir" &> "$Log_Dir/mihomo.log" &
	echo $! # 返回后台进程的 PID
}

# 停止 Mihomo 服务
stop_mihomo() {
	local PID="$1"
	if [ -n "$PID" ] && kill -0 "$PID" > /dev/null 2>&1; then
		echo -n "停止Mihomo服务 "
		kill "$PID"
		wait "$PID" 2>/dev/null
		if [ $? -eq 0 ]; then
			echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
			echo ""
			return 0
		else
			echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
			echo ""
			return 1
		fi
	else
		echo "Mihomo服务未运行或PID无效。"
		return 1
	fi
}

# 检测 Mihomo 服务是否运行 (通过检查 PID)
is_mihomo_running() {
	local PID="$1"
	if [ -n "$PID" ] && kill -0 "$PID" > /dev/null 2>&1; then
		return 0 # 运行中
	else
		return 1 # 未运行
	fi
}

# 启动 Mihomo 服务并在出错时输出信息
start_mihomo_with_error_info() {
	local PID=$(start_mihomo)
	echo -e "Mihomo Dashboard 访问地址: http://<ip>:9090/ui"
	echo -e "Secret: ${Secret}"
	if is_mihomo_running "$PID"; then
		echo -e "\nMihomo 服务已启动 (PID: $PID)，请查看日志。\n"
	else
		echo -e "\n错误: Mihomo 服务启动失败，请查看日志文件。\n"
	fi
	echo ""
	echo -e "若要停止 Mihomo 服务，请执行: kill $PID\n"
}

# 检测订阅地址
check_subscription_url() {
	echo -e '\n正在检测订阅地址 (超时 2 秒)...'
	curl -o /dev/null -L -k -sS --retry 0 -m 5 --connect-timeout 2 -w "%{http_code}" "$URL" | grep -Eq '^[23][0-9]{2}$'
}

# 下载 Mihomo 配置文件
download_config_file() {
	echo -e '\n正在下载Mihomo配置文件...'
	curl -L -k -sS --retry 5 -m 10 -o "$Temp_Dir/mihomo.yaml" "$URL"
}

#################### 脚本初始化后检查 ####################

# 创建必要的目录，如果不存在
mkdir -p "$Conf_Dir" "$Temp_Dir" "$Log_Dir" "$Dashboard_Dir"

# 给二进制启动程序、脚本等添加可执行权限
find "$Server_Dir/bin" -type f -exec chmod +x {} \;
find "$Server_Dir/scripts" -type f -exec chmod +x {} \;
chmod +x "$Server_Dir/tools/subconverter/subconverter"

#################### 任务执行 ####################

## 获取CPU架构信息
if ! action "获取CPU架构信息" source "$Server_Dir/scripts/get_cpu_arch.sh"; then
	start_mihomo_with_error_info
	exit 1
fi

# Check if we obtained CPU architecture
if [[ -z "$CpuArch" ]]; then
	echo "Error: Failed to obtain CPU architecture"
	start_mihomo_with_error_info
	exit 1
fi

## 临时取消环境变量
unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY

## Mihomo 订阅地址检测及配置文件下载
if action "检测订阅地址" check_subscription_url; then
	action "下载Mihomo配置文件" download_config_file
else
	echo -e "\n警告: 订阅地址检测失败或超时，将尝试使用本地配置启动。\n"
	start_mihomo_with_error_info
	# 不退出，继续尝试使用本地配置
fi

# 重命名mihomo配置文件
action "重命名配置文件" cp -a "$Temp_Dir/mihomo.yaml" "$Temp_Dir/mihomo_config.yaml"

## Mihomo 配置文件重新格式化及配置
action "提取代理配置" sed -n '/^proxies:/,$p' "$Temp_Dir/mihomo_config.yaml" > "$Temp_Dir/proxy.txt"
action "合并配置文件" sh -c "cat \"$Temp_Dir/templete_config.yaml\" > \"$Temp_Dir/config.yaml\" && cat \"$Temp_Dir/proxy.txt\" >> \"$Temp_Dir/config.yaml\""
action "复制最终配置文件" cp "$Temp_Dir/config.yaml" "$Conf_Dir/"

# Configure Mihomo Dashboard
action "配置Dashboard路径" sed -i "" "/^#\?external-ui: /s#.*#external-ui: $Dashboard_Dir#g" "$Conf_Dir/config.yaml"
action "配置API Secret" sed -i "" "/^secret: /s#\(secret: \).*#\1${Secret}#g" "$Conf_Dir/config.yaml"

## 启动Mihomo服务
Mihomo_PID=$(start_mihomo)

if is_mihomo_running "$Mihomo_PID"; then
	echo -e "\nMihomo 服务已启动 (PID: $Mihomo_PID)，请查看日志。\n"
else
	echo -e "\n错误: Mihomo 服务启动失败，请查看日志文件。\n"
fi

# Output Dashboard access address and Secret
echo ""
echo -e "Mihomo Dashboard 访问地址: http://<ip>:9090/ui"
echo -e "Secret: ${Secret}"
echo ""

#################### 自动设置代理环境变量 ####################
source "$Server_Dir/proxy.sh"
proxy_on
echo -e "\n系统代理已尝试开启。\n"
echo -e "若要临时关闭系统代理，请执行: proxy_off\n"
echo -e "若要停止 Mihomo 服务，请执行: kill $Mihomo_PID\n"
