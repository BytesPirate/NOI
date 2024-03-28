#!/bin/bash -ilex

SERVER=""  # 由于生产环境需要轮询此变量梯次重启服务，故此变量不能写ansible hosts分组名。
DIR='/data'

if [[ $METHOD == "deploy" ]]; then
  ansible ${SERVER} -m file -a "path=${DIR}/releases/${JOB_NAME}/${MODULE_NAME} state=directory" -u nginx
  ansible ${SERVER} -m file -a "path=${DIR}/content/${JOB_NAME} state=directory" -u nginx
  mkdir -p ../deploy_tmp/${JOB_NAME}

  mvn clean package -pl ${MODULE_NAME} -am -Dmaven.test.skip=true
  echo "编译完成"

  /bin/cp -rf ./${MODULE_NAME}/target/*.jar ../deploy_tmp/${JOB_NAME}/${MODULE_NAME}.jar

  echo "开始同步目录至应用服务器"
  ansible ${SERVER} -m synchronize -a "src=../deploy_tmp/${JOB_NAME}/${MODULE_NAME}.jar dest=${DIR}/releases/${JOB_NAME}/${MODULE_NAME}/${MODULE_NAME}_${BUILD_DISPLAY_NAME}.jar delete=yes archive=no recursive=yes" -u nginx
  ansible ${SERVER} -m file -a "src=${DIR}/releases/${JOB_NAME}/${MODULE_NAME}/${MODULE_NAME}_${BUILD_DISPLAY_NAME}.jar dest=${DIR}/content/${JOB_NAME}/${MODULE_NAME}.jar state=link" -u nginx
  ansible ${SERVER} -m shell -a "sudo supervisorctl restart ${JOB_NAME}_${MODULE_NAME}" -u nginx
  echo "应用重启完成"

  sed -i '1,7!d' .${JOB_NAME}.env
  echo "${BUILD_DISPLAY_NAME}\ ${SERVER}\ ${MODULE_NAME}" >> .${JOB_NAME}.env
  ansible ${SERVER} -m script -a "chdir=${DIR}/releases/${JOB_NAME}/${MODULE_NAME} /data/jenkins/scripts/clean_old_build.sh" -u nginx

elif [[ $METHOD == "rollback" ]]; then
  echo "准备回滚..."
  SERVER=`cat .${JOB_NAME}.env |grep ${ROLLBACK_VERSION} |awk -F "=" '{print $2}'`
  MODULE_NAME=`cat .${JOB_NAME}.env |grep ${ROLLBACK_VERSION} |awk -F "=" '{print $3}'`

  ansible ${SERVER} -m shell -a "if [[ -f ${DIR}/releases/${JOB_NAME}/${MODULE_NAME}/${MODULE_NAME}_${BUILD_DISPLAY_NAME}.jar ]];then ln -sfn ${DIR}/releases/${JOB_NAME}/${MODULE_NAME}/${MODULE_NAME}_${BUILD_DISPLAY_NAME}.jar ${DIR}/content/${JOB_NAME}/${MODULE_NAME}.jar && echo "已回滚至版本${ROLLBACK_VERSION}";else echo '回滚的版本不存在！' && exit 0;fi" -u nginx
  ansible ${SERVER} -m shell -a "sudo supervisorctl restart ${JOB_NAME}_${MODULE_NAME}" -u nginx
  echo "应用回滚完成"
fi
