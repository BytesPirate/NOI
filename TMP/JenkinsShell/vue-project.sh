#!/bin/bash -ile
SERVER="[target IP]"    # or SERVER=(target IP1, target IP2)
DIR='/data'

if [[ $METHOD == "deploy" ]]; then
    mkdir -p ../deploy_tmp/${JOB_NAME}
    nvm use v16.19.0
    node -v
    npm install

    if [[ ${MODULE_NAME} == "all" ]]; then
        npm run build:all
        echo "编译完成"
        /bin/cp -rf ./dist/ ../deploy_tmp/${JOB_NAME}
    else
        npm run build ${MODULE_NAME}
        echo "编译完成"
        /bin/cp -rf ./dist/ ../deploy_tmp/${JOB_NAME}/dist/
    fi

    echo "开始同步至目标服务器"
    cp -r ./dist ../tmp_${JOB_NAME}/
    ansible ${SERVER} -m file -a "path=${DIR}/releases/${JOB_NAME} state=directory" -u nginx
    ansible ${SERVER} -m synchronize -a "src=../deploy_tmp/${JOB_NAME}/dist dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} compress=yes recursive=yes dirs=yes archive=no" -u nginx
    echo "同步完成" && echo "创建软链"
    ansible ${SERVER} -m file -a "src=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} dest=${DIR}/content/${JOB_NAME} state=link" -u nginx
    echo "创建软链完成"

elif [[ $METHOD == "rollback" ]]; then
    echo "软件回滚"
    ansible ${SERVER} -m shell -a "if [[ -d ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ]];then ln -sfn ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ${DIR}/content/${JOB_NAME} && echo "已回滚至${ROLLBACK_VERSION}版本"; else echo '回滚失败，目录不存在'; fi" -u nginx
fi
