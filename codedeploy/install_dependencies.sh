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

user=$MODULE_NAME
group=gdt

#create group if not exists
grep -E "^$group" /etc/group >& /dev/null
if [ $? -ne 0 ]
then
    groupadd $group
fi
  
#create user if not exists
grep -E "^$user" /etc/passwd >& /dev/null
if [ $? -ne 0 ]
then  
    useradd -g $group $user
fi

USER_HOME=/home/$user

# test if user home exist
if [ ! -d $USER_HOME ]; then
    exit 1
fi

su - $user << EOF

# init run.cfg & logback.xml if NOT exist
if [ ! -d $USER_HOME/etc ]; then
    mkdir $USER_HOME/etc
fi

EOF

exit 0
