#!/usr/bin/env bash
#set -x
# ============================== !! NOTE !! ===================================
#
#          ____  ___  ___    _______  ___  ___  ___________  _______   ________
#         /  " \(: "||_  |  |   _  "\|"  \/"  |("     _   ")/"     "| /"       )
#        /__|| ||  (__) :|  (. |_)  :)\   \  /  )__/  \\__/(: ______)(:   \___/
#           |: | \____  ||  |:     \/  \\  \/      \\_ /    \/    |   \___  \
#          _\  |     _\ '|  (|  _  \\  /   /       |.  |    // ___)_   __/  \\
#         /" \_|\   /" \_|\ |: |_)  :)/   /        \:  |   (:      "| /" \   :)
#        (_______) (_______)(_______/|___/          \__|    \_______)(_______/
#
#
# 注：该脚本适用于 CentOS、OpenEuler 等系统
# 注：适配 x86 架构
# 注：可能有些小 BUG
# Author: J1nH4ng<jinhang@14bytes.com>
# Date: 2024-03-22
# Version: 0.1
# ==============================================================================

# =========================== 基本配置项 ========================================
Init_Version="0.1 Dev(2024/03/22)"
Default_DNS=61.177.7.1
error=0
wget_option="-q --show-progress"
Download_Dir=/usr/local/src

# =========================== 软件版本（Dev） ================================
# https://go.dev/dl/
GO_Version=
