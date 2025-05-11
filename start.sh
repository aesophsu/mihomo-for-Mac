#!/bin/bash

#################### 脚本初始化任务 ####################

# 获取脚本工作目录绝对路径
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 定义必要的目录
Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"
Dashboard_Dir="$Server_Dir/dashboard/public" # 设置为 $Server_Dir/dashboard/public

# 加载 .env 变量文件 (如果存在)
if [ -f "$Server_Dir/.env" ]; then
    source "$Server_Dir/.env"
fi

# 获取 CLASH_URL 变量的值，如果未设置则提示
if [ -z "${CLASH_URL}" ]; then
    read -p "请输入 CLASH 订阅 URL: " CLASH_URL
fi
export URL="${CLASH_URL}"

# 获取 CLASH_SECRET 值，如果不存在则生成一个随机数
Secret=${CLASH_SECRET:-$(openssl rand -hex 32)}
export Secret

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

# 获取CPU架构信息
get_cpu_arch() {
    action "获取CPU架构信息" source "$Server_Dir/scripts/get_cpu_arch.sh"
    if [[ -z "$CpuArch" ]]; then
        echo "警告: 未能获取 CPU 架构。"
        return 1
    else
        echo "CPU architecture: $CpuArch"
        return 0
    fi
}

# 更新订阅文件
update_subscription() {
    echo -e '\n--- 更新订阅文件 ---'
    if action "检测订阅地址" curl -o /dev/null -L -k -sS --retry 0 -m 5 --connect-timeout 2 -w "%{http_code}" "$URL" | grep -Eq '^[23][0-9]{2}$'; then
        if action "下载 Mihomo 配置文件" curl -L -k -sS --retry 5 -m 10 -o "$Temp_Dir/mihomo.yaml" "$URL"; then
            action "重命名配置文件" cp -a "$Temp_Dir/mihomo.yaml" "$Temp_Dir/mihomo_config.yaml"
            action "提取代理配置" sed -n '/^proxies:/,$p' "$Temp_Dir/mihomo_config.yaml" > "$Temp_Dir/proxy.txt"
            action "合并配置文件" sh -c "cat \"$Temp_Dir/templete_config.yaml\" > \"$Temp_Dir/config.yaml\" && cat \"$Temp_Dir/proxy.txt\" >> \"$Temp_Dir/config.yaml\""
            action "复制最终配置文件" cp "$Temp_Dir/config.yaml" "$Conf_Dir/"
            return 0
        else
            echo "错误: 下载配置文件失败。"
            return 1
        fi
    else
        echo "错误: 检测订阅地址失败。"
        return 1
    fi
}

# 配置 Dashboard
configure_dashboard() {
    echo -e '\n--- 配置 Dashboard ---'
    action "配置Dashboard路径" sed -i "" "/^#\?external-ui: /s#.*#external-ui: $Dashboard_Dir#g" "$Conf_Dir/config.yaml"
    action "配置API Secret" sed -i "" "/^secret: /s#\(secret: \).*#\1${Secret}#g" "$Conf_Dir/config.yaml"
    return 0
}

# 启动 Mihomo 服务
start_mihomo() {
    echo -e '\n--- 启动 Mihomo 服务 ---'
    action "启动Mihomo服务" "$Server_Dir/bin/mihomo" -d "$Conf_Dir/config.yaml" &> "$Log_Dir/mihomo.log" &
    Mihomo_PID=$!
    echo "Mihomo 服务已在后台启动 (PID: $Mihomo_PID)。"
    echo "Dashboard 访问地址: http://<ip>:9090/ui"
    echo "Secret: ${Secret}"
    echo "若要停止 Mihomo 服务，请执行: kill $Mihomo_PID"
    return 0
}

# Fallback 配置 (这里添加了使用 fallback.yaml 的逻辑)
fallback_config() {
    echo -e '\n--- Fallback 配置 ---'
    if [ -f "$Conf_Dir/fallback.yaml" ]; then
        echo "发现 fallback.yaml，使用它来启动 Mihomo。"
        action "启动Mihomo服务" "$Server_Dir/bin/mihomo" -d "$Conf_Dir/fallback.yaml" &> "$Log_Dir/mihomo.log" &
        Mihomo_PID=$!
        echo "Mihomo 服务已在后台启动 (PID: $Mihomo_PID)。"
        echo "Dashboard 访问地址 (可能使用默认配置): http://<ip>:9090/ui"
        echo "Secret (可能为空): ${Secret}" #  fallback  可能没有 Secret
        echo "若要停止 Mihomo 服务，请执行: kill $Mihomo_PID"
        return 0
    else
        echo "错误: 未找到 fallback.yaml，无法执行 Fallback 配置。"
        return 1
    fi
}

#################### 脚本流程控制 ####################

echo "欢迎使用 Mihomo 管理脚本"

while true; do
    echo -e "\n请选择要执行的操作:"
    echo "1. 初始化脚本"
    echo "2. 获取 CPU 架构"
    echo "3. 更新订阅文件"
    echo "4. 配置 Dashboard"
    echo "5. 启动 Mihomo 服务"
    echo "6. 执行 Fallback 配置"
    echo "7. 退出"
    read -p "请输入选项编号: " choice

    case "$choice" in
        1)
            echo -e "\n--- 初始化脚本 ---"
            # 检查脚本工作目录 (B)
            echo "脚本工作目录: $Server_Dir"
            # 设置关键变量 (D)
            echo "配置目录: $Conf_Dir"
            echo "临时目录: $Temp_Dir"
            echo "日志目录: $Log_Dir"
            echo "Dashboard 目录: $Dashboard_Dir"
            echo "订阅 URL: $URL"
            echo "Secret: $Secret"
            # 创建必要目录 (E)
            action "创建必要目录" mkdir -p "$Conf_Dir" "$Temp_Dir" "$Log_Dir" "$Dashboard_Dir"
            # 设置可执行权限 (F)
            action "设置可执行权限 (bin)" find "$Server_Dir/bin" -type f -exec chmod +x {} \;
            action "设置可执行权限 (scripts)" find "$Server_Dir/scripts" -type f -exec chmod +x {} \;
            action "设置可执行权限 (subconverter)" chmod +x "$Server_Dir/tools/subconverter/subconverter"
            # 取消代理环境变量 (M)
            unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY
            action "取消代理环境变量" echo "已取消代理环境变量"
            ;;
        2)
            get_cpu_arch
            ;;
        3)
            update_subscription
            ;;
        4)
            configure_dashboard
            ;;
        5)
            start_mihomo
            ;;
        6)
            fallback_config
            ;;
        7)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新输入。"
            ;;
    esac
done
