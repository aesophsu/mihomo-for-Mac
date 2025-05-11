#!/bin/bash
# 该脚本的作用是获取Mac os系统上运行的CPU架构信息，并将其输出到标准输出流。

function exitWithError {
    local errorMessage="$1"
    echo -e "\033[31m[ERROR] $errorMessage\033[0m" >&2
    exit 1
}

# Function to get CPU architecture for macOS
function get_macos_arch {
    uname -m
}

# Determine the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    CpuArch=$(get_macos_arch)
else
    exitWithError "Unsupported operating system: $OSTYPE"
fi

echo "CPU architecture: $CpuArch"
export CpuArch # Make CpuArch available to the calling script
