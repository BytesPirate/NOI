#!/bin/bash -ilex
#
# Script Name: Jenkins Java Project Shell
#
# Author: J1n H4ng<jinhang@mail.14bytes.com>
# Date: March 26, 2024
#
# Last Editor: J1n H4ng<jinhang@mail.14bytes.com>
# Last Modified: March 28, 2024
#
# Description: Jenkins Java Project Shell
#
# MODULE_NAME: 需要编译的模块名称
# 选项有：
#   - ONLY MODULE_NAME 1
#   - ONLY MODULE_NAME 2
#   - WITHOUT MODULE_NAME 1
#   - WITHOUT MODULE_NAME 2
#
# METHOD: deploy or rollback

# 需要部署到的服务器地址或服务器组别名（在 Jenkins 所在的服务器中的 /etc/ansible/hosts 中查看）
# SERVER="[target IP]" OR SERVER=(target IP1, target IP2) OR SERVER=(target group name) like SERVER="web"
SERVER="[target IP]"

# 项目部署的目录位置，一般部署位置为/data/releases/项目名/版本号，特殊情况下请取消注释并赋值，默认值为 /data
# DIR=""
DIR="${DIR:-/data}"

# MODULE_NAME 需要编译的模块名称，需要新模块时添加 CHILD_MODULE_NAME_4，以此类推
CHILD_MODULE_NAME_1=""
CHILD_MODULE_NAME_2=""
CHILD_MODULE_NAME_3=""
# CHILD_MODULE_PORT 子模块占用的端口号，便于 Supervisord 进行管理
CHILD_MODULE_PORT_1=""
CHILD_MODULE_PORT_2=""
CHILD_MODULE_PORT_3=""
# PROD_NAME 是否为生产环境，默认为测试环境
# PROD_NAME=""
PROD_NAME="${PROD_NAME:test}"

# TODO：移动位置，使得逻辑清除
# 构建一个数组，便于遍历特定目录拷贝 jar 包到特定目录下，新增 CHILD_MODULE_NAME 时会自动添加
CHILD_MODULE_MEMBERS=()

for i in {1..10}; do
  CHILD_MODULE_NAME="CHILD_MODULE_NAME_$i"
  if [[ -n "${!CHILD_MODULE_NAME}" ]]; then
    CHILD_MODULE_MEMBERS+=("${!CHILD_MODULE_NAME}")
  else
    break
  fi
done

# 前置条件：构建目录
# Jenkins 服务器通过 ansible 创建项目 releases 目录
ansible "${SERVER}" -m file -a "path=${DIR}/releases/${JOB_NAME} state=directory" -u nginx
# Jenkins 服务器通过 ansible 创建项目 content 目录
ansible "${SERVER}" -m file -a "path=${DIR}/content/${JOB_NAME} state=directory" -u nginx
# Jenkins 服务器创建部署临时目录
mkdir -p ../deploy_tmp/"${JOB_NAME}"
# 创建项目的 env 文件
[[ ! -f ."${JOB_NAME}".env ]] && touch ."${JOB_NAME}".env

# 构建单个模块
function build_single_module() {
  mvn clean package -pl "$1" -am
  echo "编译 $1 完成"
  /bin/cp -rf ./"$1"/target/*.jar ../deploy_tmp/"${JOB_NAME}"/"${JOB_NAME}"-"$1".jar
  echo "开始同步至应用服务器"
  ansible "${SERVER}" -m synchronize \
    -a "src=../deploy_tmp/${JOB_NAME} \
    dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ \
    compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
  ansible "${SERVER}" -m file \
    -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} \
    dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
  ansible "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-$1" -u nginx
}

function clean_old_package() {
  total=$(ls | wc -l) #取出当前项目总构建数量
  if [ "${total}" -gt 5 ]; then #只对总构建数量超过10个的项目进行操作
      del_appnum=$(expr "${total}" - 5) #判断需要删除的构建数量
      del_applist=$(ls -tr | head -${del_appnum}) #列出需要删除的构建的列表
      echo -e "以下发布将被删除：\n ${del_applist}"
      sudo rm -rf "${del_applist}"
  fi
}
function create_supervisord_conf() {
  echo "创建 supervisord 配置文件"
}

if [[ "${METHOD}" == "deploy" ]]; then
  case "${MODULE_NAME}" in
    "all")
      mvn clean package -Dmaven.test.skip=true
      echo "编译完成"
      for target_name in "${CHILD_MODULE_MEMBERS[@]}"; do
        /usr/bin/cp -rf ./"${target_name}"/target/*.jar ../deploy_tmp/"${JOB_NAME}"/"${target_name}".jar
      done
      echo "开始同步至应用服务器"
      ansible "${SERVER}" -m synchronize -a "src=../deploy_tmp/${JOB_NAME} dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
      ansible "${SERVER}" -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/${JOB_NAME} dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
      ansible "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-{${CHILD_MODULE_MEMBERS[0],${CHILD_MODULE_MEMBERS[1]},${CHILD_MODULE_MEMBERS[2]}}" -u nginx
      echo "部署完成"
    ;;
    "only ${CHILD_MODULE_NAME_1}")
    ;;
    "only ${CHILD_MODULE_NAME_2}")
    ;;
    "only ${CHILD_MODULE_NAME_3}")
    ;;
  esac
elif [[ "${METHOD}" == "rollback" ]]; then
  echo "准备回滚..."
  IP=$(cat ./"${JOB_NAME}".log)
  ansible "${IP}" -m shell \
    -a "if [[ -d ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ]];then \
    ln -sfn ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ${DIR}/content/${JOB_NAME}&& \
    echo "已回滚至版本${ROLLBACK_VERSION}";else echo 'folder is not exist';fi" -u nginx
  ansible "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-*" -u nginx
fi
