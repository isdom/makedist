#!/bin/sh

# BASE: the caller's base path
# MODULE_NAME: module's name, eg: yjy-j1cn
# MODULE_HOME: module's home, eg: /home/yjy-j1cn/current
# PIDFILE: module's runtime pid file: /home/yjy-j1cn/current/pids/yjy-j1cn.pid
function set_module_var() {
    FINDNAME=$0
    while [ -h $FINDNAME ] ; do FINDNAME=`ls -ld $FINDNAME | awk '{print $NF}'` ; done
    BASE=`echo $FINDNAME | sed -e 's@/[^/]*$@@'`
    unset FINDNAME
    
    if [ "$BASE" = '.' ]; then
       BASE=$(echo `pwd` | sed 's/\/codedeploy//')
    else
       BASE=$(echo $BASE | sed 's/\/codedeploy//')
    fi
    
    MODULE_NAME=$(cat $BASE/module.txt)
    
    MODULE_HOME=/home/$MODULE_NAME/current
    PIDFILE=$MODULE_HOME/pids/$MODULE_NAME.pid
}

set_module_var

#change owner
chown -R $MODULE_NAME $MODULE_HOME

#add execute mode
chmod a+x $MODULE_HOME/*.sh
