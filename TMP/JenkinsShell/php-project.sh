#!/bin/bash -ilex
SERVER="[target IP]" # or SERVER=(target IP1, target IP2)
DIR="/data"

if [[ $METHOD == "deploy" ]]; then
    rm -fr .env
    cp 	env/.env .env
    /usr/local/php7.3/bin/php /usr/local/bin/composer install --ignore-platform-reqs --no-scripts

    echo "开始同步目录至应用服务器"
    ansible ${SERVER} -m synchronize -a "src=./ dest=${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} compress=yes delete=yes recursive=yes dirs=yes archive=no" -u nginx
    ansible ${SERVER} -m shell -a "source /etc/profile && /bin/bash ${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME}/bin/deploy.sh" -u nginx
    ansible ${SERVER} -m shell -a "ln -fns ${DIR}/releases/${JOB_NAME}/${BUILD_DISPLAY_NAME} ${DIR}/content/${JOB_NAME}" -u nginx
    # 当需要挂载文件时取消注释
    # ansible ${SERVER} -m file -a "src=/data/attaches/{JOB_NAME} dest=${DIR}/${JOB_NAME}/storage/attaches state=link" -u nginx
    ansible ${SERVER} -m shell -a "sudo systemctl restart php-fpm" -u nginx
    echo "目录同步完成"

elif [[ $METHOD == "rollback" ]]; then
    echo "准备回滚..."
    ansible ${SERVER} -m shell -a "if [[ -d ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ]];then ln -sfn ${DIR}/releases/${JOB_NAME}/${ROLLBACK_VERSION} ${DIR}/content/${JOB_NAME}&& echo "已回滚至版本${ROLLBACK_VERSION}";else echo 'folder is not exist';fi" -u nginx
fi
