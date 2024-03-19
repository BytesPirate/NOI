#！/bin/bash
# -------------使用教程---------------
# 1. 该脚本需要放在jenkins_home目录下的scripts内
# 2. 在每次content软链完成之后使用ansible远程执行脚本，命令如下
# ansible ${SERVER} -m script -a "chdir=${DIR}/releases/${JOB_NAME} /data/jenkins/scripts/clean_old_build.sh" -u nginx

function clean_old_build_stage(){
    total=`ls | wc -l` #取出当前项目总构建数量

    if [ ${total} -gt 5 ]; then #只对总构建数量超过10个的项目进行操作
        del_appnum=`expr ${total} - 5` #判断需要删除的构建数量
        del_applist=`ls -tr | head -${del_appnum}` #列出需要删除的构建的列表
        echo -e "以下发布将被删除：\n ${del_applist}"
        sudo rm -rf ${del_applist}
    fi
}

clean_old_build_stage
