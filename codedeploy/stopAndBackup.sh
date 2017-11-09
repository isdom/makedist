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

VERSION=$(cat $MODULE_HOME/version.txt)
BACKUPDIR=/home/$MODULE_NAME/.backup/$VERSION

echo module name: $MODULE_NAME
echo module home: $MODULE_HOME
echo pidfile: $PIDFILE
echo version file: $VERSION
echo backup dir: $BACKUPDIR

# dir not exist
if [ ! -d $MODULE_HOME ]; then
    echo $MODULE_HOME not exist, skip stop and backup
    exit 0
fi

su - $MODULE_NAME << EOF
if [ -f $PIDFILE ]
then
    kill -9 $(cat $PIDFILE)
    rm $PIDFILE
    echo $MODULE_NAME STOPPED
fi

if [ ! -d ~/.backup ]; then
    mkdir ~/.backup
fi

echo backup $MODULE_NAME from $MODULE_HOME to $BACKUPDIR
mv $MODULE_HOME $BACKUPDIR
EOF

exit 0
