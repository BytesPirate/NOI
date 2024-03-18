#!/bin/bash -ilex

SERVER="[target IP]" # or SERVER=(target IP1, target IP2)
DIR="/data"

if [[ ${METHOD} == "deploy" ]]; then
    ansible ${SERVER} -m file -a "path=${DIR}/releases/${JOB_NAME} state=directory" -u nginx
    if [[ ${MODULE_NAME} == "all" ]]; then
        mvn clean package -Dmaven.test.skip=true
        echo "编译完成"

        mkdir -p ../deploy_tmp/${JOB_NAME}
        /bin/cp -rf ./[Java Name1]/target/*.jar ../deploy_tmp/${JOB_NAME}/${JOB_NAME}-[Java Name1].jar
        /bin/cp -rf ./[Java Name2]/target/*.jar ../deploy_tmp/${JOB_NAME}/${JOB_NAME}-[Java Name2].jar

        echo "开始同步目录到应用服务器"
        ansible ${SERVER} -m synchronize -a "src=../deploy_tmp/${JOB_NAME} dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
        ansible ${SERVER} -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/${JOB_NAME} dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
        ansible ${SERVER} -m shell -a "sudo supervisorctl restart ${JOB_NAME}-[Java Name1] ${JOB_NAME}-[Java Name2]" -u nginx
        echo "部署完成"

    else
        mvn clean package -pl ${MODULE_NAME} -an
        echo "编译完成"
        mkdir -p ../deploy_tmp/${JOB_NAME}
        /bin/cp -rf ./${MODULE_NAME}/target/*.jar ../deploy_tmp/${JOB_NAME}/${JOB_NAME}-${MODULE_NAME}.jar
        echo "开始同步目录至应用服务器"
        ansible ${SERVER} -m synchronize -a "src=../deploy_tmp/${JOB_NAME} dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/ compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
        ansible ${SERVER} -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/${JOB_NAME} dest=${DIR}/content/${JOB_NAME} state=link"  -u nginx
        ansible ${SERVER} -m shell -a "sudo supervisorctl restart ${JOB_NAME}-${MODULE_NAME}" -u nginx
        echo "目录同步完成"
    fi

    echo ${SERVER} > ./${JOB_NAME}.log

elif [[ $METHOD == "rollback" ]]; then
    echo "准备回滚..."
    IP=`cat ./${JOB_NAME}.log`
    ansible ${IP} -m shell -a "if [[ -d ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ]];then ln -sfn ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ${DIR}/content/${JOB_NAME}&& echo "已回滚至版本${ROLLBACK_VERSION}";else echo 'folder is not exist';fi" -u nginx
    ansible ${SERVER} -m shell -a "sudo supervisorctl restart ${JOB_NAME}-*" -u nginx
fi
