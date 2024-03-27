#!/bin/bash -ilex
#
# Script Name: Jenkins Java Project Shell
#
# Author: J1n H4ng<jinhang@mail.14bytes.com>
# Date: March 26, 2024
#
# Last Editor: J1n H4ng<jinhang@mail.14bytes.com>
# Last Modified: March 27, 2024
#
# Description: Jenkins Java Project Shell
#
# MODULE_NAME: 需要编译的模块名称
# 选项有 MODULE_NAME 1, MODULE_NAME 2, WITHOUT MODULE_NAME 1, WITHOUT MODULE_NAME 2
# METHOD: deploy or rollback
#
# 需要部署到的服务器地址或服务器组别名（在 Jenkins 所在的服务器中的 /etc/ansible/hosts 中查看）
SERVER="[target IP]" # OR SERVER=(target IP1, target IP2) or SERVER=(target group name) like SERVER="web"

# 项目部署的目录位置，一般部署位置为/data/releases/项目名/版本号，特殊情况下请取消注释并赋值，默认值为 /data
# DIR=""
DIR="${DIR:-/data}"

# MODULE_NAME 需要编译的模块名称
CHILD_MODULE_NAME_1=""
CHILD_MODULE_NAME_2=""
CHILD_MODULE_NAME_3=""

CHILD_MODULE_MEMBERS=("${CHILD_MODULE_NAME_1}" "${CHILD_MODULE_NAME_2}" "${CHILD_MODULE_NAME_3}")

case "${METHOD}" in
  "deploy")
    # Jenkins 服务器通过 ansible 创建项目 releases 目录
    ansible "${SERVER}" -m file -a "path=${DIR}/releases/${JOB_NAME} state=directory" -u nginx
    # Jenkins 服务器通过 ansible 创建项目 content 目录
    ansible "${SERVER}" -m file -a "path=${DIR}/content/${JOB_NAME} state=directory" -u nginx
    # Jenkins 服务器创建部署临时目录
    mkdir -p ../deploy_tmp/"${JOB_NAME}"
    # 创建项目的 env 文件
    [[ ! -f ."${JOB_NAME}".env ]] && touch ."${JOB_NAME}".env

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
        # 验证 Supervisor 文件是否存在
        ansible "${SERVER}" -m shell -a "[[ -f /etc/supervisord.d/${JOB_NAME}_${CHILD_MODULE_NAME_1}.ini ]]" -u nginx \
        && ansible "${SERVER}" -m shell -a "[[ -f /etc/supervisord.d/${JOB_NAME}_${CHILD_MODULE_NAME_2}.ini ]]" -u nginx \
        && ansible "${SERVER}" -m shell -a "[[ -f /etc/supervisord.d/${JOB_NAME}_${CHILD_MODULE_NAME_3}.ini ]]" -u nginx \

        ansible "${SERVER}" -m shell -a "sudo supervisorctl update" -u nginx
        ansible "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-{$CHILD_MODULE_NAME_1,$CHILD_MODULE_NAME_2,$CHILD_MODULE_NAME_3}" -u nginx
        echo "部署完成"
      ;;
      # TODO: 需要修改单模块打包时的拷贝目录方式
      "only ${CHILD_MODULE_NAME_1}")
        mvn clean package -pl "${CHILD_MODULE_NAME_1}" -am
        echo "编译 ${CHILD_MODULE_NAME_1} 完成"
        /bin/cp -rf ./"${CHILD_MODULE_NAME_1}"/target/*.jar ../deploy_tmp/"${JOB_NAME}"/"${JOB_NAME}"-"${CHILD_MODULE_NAME_1}".jar
        echo "开始同步至应用服务器"
        ansible "${SERVER}" -m synchronize -a "src=../deploy_tmp/${JOB_NAME} dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
        ansible "${SERVER}" -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
        ansibel "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-${CHILD_MODULE_NAME_1}" -u nginx
      ;;
      "only ${CHILD_MODULE_NAME_2}")
        mvn clean package -pl "${CHILD_MODULE_NAME_2}" -am
        echo "编译 ${CHILD_MODULE_NAME_2} 完成"
        /bin/cp -rf ./"${CHILD_MODULE_NAME_2}"/target/*.jar ../deploy_tmp/"${JOB_NAME}"/"${JOB_NAME}"-"${CHILD_MODULE_NAME_2}".jar
        echo "开始同步至应用服务器"
        ansible "${SERVER}" -m synchronize -a "src=../deploy_tmp/${JOB_NAME} dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
        ansible "${SERVER}" -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
        ansibel "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-${CHILD_MODULE_NAME_2}" -u nginx
      ;;
      "only ${CHILD_MODULE_NAME_3}")
        mvn clean package -pl "${CHILD_MODULE_NAME_3}" -am
        echo "编译 ${CHILD_MODULE_NAME_3} 完成"
        /bin/cp -rf ./"${CHILD_MODULE_NAME_3}"/target/*.jar ../deploy_tmp/"${JOB_NAME}"/"${JOB_NAME}"-"${CHILD_MODULE_NAME_3}".jar
        echo "开始同步至应用服务器"
        ansible "${SERVER}" -m synchronize -a "src=../deploy_tmp/${JOB_NAME} dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
        ansible "${SERVER}" -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
        ansibel "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-${CHILD_MODULE_NAME_3}" -u nginx
      ;;
    esac
  ;;
  "rollback")
    echo "准备回滚..."
    IP=$(cat ./"${JOB_NAME}".log)
    ansible "${IP}" -m shell -a "if [[ -d ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ]];then ln -sfn ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ${DIR}/content/${JOB_NAME}&& echo "已回滚至版本${ROLLBACK_VERSION}";else echo 'folder is not exist';fi" -u nginx
    ansible "${SERVER}" -m shell -a "sudo supervisorctl restart ${JOB_NAME}-*" -u nginx
  ;;
esac
