#!/bin/bash

# 开启系统代理
proxy_on() {
	export http_proxy=http://127.0.0.1:7890
	export https_proxy=http://127.0.0.1:7890
 	export all_proxy=http://127.0.0.1:7890
	export no_proxy="127.0.0.1,localhost,$(networksetup -listallrouters | tail -n +2 | awk '{print $1}')"
    	export HTTP_PROXY=http://127.0.0.1:7890
    	export HTTPS_PROXY=http://127.0.0.1:7890
 	export NO_PROXY="127.0.0.1,localhost,$(networksetup -listallrouters | tail -n +2 | awk '{print $1}')"
	echo -e "\033[32m[√] 已开启代理\033[0m"
}

# 关闭系统代理
proxy_off(){
	unset http_proxy
	unset https_proxy
 	unset all_proxy
	unset no_proxy
  	unset HTTP_PROXY
	unset HTTPS_PROXY
	unset NO_PROXY
	echo -e "\033[31m[×] 已关闭代理\033[0m"
}
