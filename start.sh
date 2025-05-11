#!/bin/bash

#################### 脚本初始化任务 ####################

# 获取脚本工作目录绝对路径
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 加载.env变量文件
source $Server_Dir/.env

# 给二进制启动程序、脚本等添加可执行权限
chmod +x $Server_Dir/bin/*
chmod +x $Server_Dir/scripts/*
chmod +x $Server_Dir/tools/subconverter/subconverter



#################### 变量设置 ####################

Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"

# 将 CLASH_URL 变量的值赋给 URL 变量，并检查 CLASH_URL 是否为空
URL=${CLASH_URL:?Error: CLASH_URL variable is not set or empty}

# 获取 CLASH_SECRET 值，如果不存在则生成一个随机数
Secret=${CLASH_SECRET:-$(openssl rand -hex 32)}



#################### 函数定义 ####################

# 自定义action函数，实现通用action功能
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

# 判断命令是否正常执行 函数
if_success() {
	local ReturnStatus=$3
	if [ $ReturnStatus -eq 0 ]; then
		success "$1"
	else
		failure "$2"
		exit 1
	fi
}


#################### 任务执行 ####################

## 获取CPU架构信息
# Source the script to get CPU architecture
source $Server_Dir/scripts/get_cpu_arch.sh

# Check if we obtained CPU architecture
if [[ -z "$CpuArch" ]]; then
	echo "Failed to obtain CPU architecture"
	exit 1
fi


## 临时取消环境变量
unset http_proxy
unset https_proxy
unset no_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset NO_PROXY


## Mihomo 订阅地址检测及配置文件下载
# 检查url是否有效
echo -e '\n正在检测订阅地址...'
Text1="Mihomo订阅地址可访问！"
Text2="Mihomo订阅地址不可访问！"
#curl -o /dev/null -s -m 10 --connect-timeout 10 -w %{http_code} $URL | grep '[23][0-9][0-9]' &>/dev/null
curl -o /dev/null -L -k -sS --retry 5 -m 10 --connect-timeout 10 -w "%{http_code}" $URL | grep -E '^[23][0-9]{2}$' &>/dev/null
ReturnStatus=$?
if_success $Text1 $Text2 $ReturnStatus

# 拉取更新config.yml文件
echo -e '\n正在下载Mihomo配置文件...'
Text3="配置文件config.yaml下载成功！"
Text4="配置文件config.yaml下载失败，退出启动！"

# 尝试使用curl进行下载
curl -L -k -sS --retry 5 -m 10 -o $Temp_Dir/mihomo.yaml $URL
ReturnStatus=$?
if [ $ReturnStatus -ne 0 ]; then
	# 如果使用curl下载失败，尝试使用wget进行下载
	for i in {1..10}
	do
		wget -q --no-check-certificate -O $Temp_Dir/mihomo.yaml $URL
		ReturnStatus=$?
		if [ $ReturnStatus -eq 0 ]; then
			break
		else
			continue
		fi
	done
fi
if_success $Text3 $Text4 $ReturnStatus

# 重命名mihomo配置文件
\cp -a $Temp_Dir/mihomo.yaml $Temp_Dir/mihomo_config.yaml


## 判断订阅内容是否符合mihomo配置文件标准，尝试转换（当前不支持对 x86_64 以外的CPU架构服务器进行mihomo配置文件检测和转换，此功能将在后续添加）
# if [[ $CpuArch =~ "x86_64" || $CpuArch =~ "amd64"  ]]; then
# 	echo -e '\n判断订阅内容是否符合mihomo配置文件标准:'
# 	bash $Server_Dir/scripts/mihomo_profile_conversion.sh
# 	sleep 3
# fi


## Mihomo 配置文件重新格式化及配置
# 取出代理相关配置 
#sed -n '/^proxies:/,$p' $Temp_Dir/mihomo.yaml > $Temp_Dir/proxy.txt
sed -n '/^proxies:/,$p' $Temp_Dir/mihomo_config.yaml > $Temp_Dir/proxy.txt

# 合并形成新的config.yaml
cat $Temp_Dir/templete_config.yaml > $Temp_Dir/config.yaml
cat $Temp_Dir/proxy.txt >> $Temp_Dir/config.yaml
\cp $Temp_Dir/config.yaml $Conf_Dir/

# Configure Mihomo Dashboard
Work_Dir=$(cd $(dirname $0); pwd)
Dashboard_Dir="${Work_Dir}/dashboard/public"
sed -i "" "/^#\?external-ui: /s#.*#external-ui: dashboard/public#g" $Conf_Dir/config.yaml
sed -i "" "/^secret: /s#\(secret: \).*#\1${Secret}#g" $Conf_Dir/config.yaml
## 启动Mihomo服务
echo -e '\n正在启动Mihomo服务...'
Text5="服务启动成功！"
Text6="服务启动失败！"

# 直接使用 $Server_Dir/bin/mihomo，不再区分 CPU 架构，假设 'mihomo' 是适用于 macOS 的
$Server_Dir/bin/mihomo -d $Conf_Dir &> $Log_Dir/mihomo.log &
ReturnStatus=$?
if_success "$Text5" "$Text6" "$ReturnStatus"

# Output Dashboard access address and Secret
echo ''
echo -e "Mihomo Dashboard 访问地址: http://<ip>:9090/ui"
echo -e "Secret: ${Secret}"
echo ''

# 添加环境变量(root权限)
## macOS 设置全局环境变量的方式与 Linux 不同。
echo -e "\n请执行以下命令加载代理控制函数: source $Server_Dir/proxy.sh\n"
echo -e "请执行以下命令开启系统代理: proxy_on\n"
echo -e "若要临时关闭系统代理，请执行: proxy_off\n"
