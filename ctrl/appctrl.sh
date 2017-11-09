#!/bin/sh

FINDNAME=$0
while [ -h $FINDNAME ] ; do FINDNAME=`ls -ld $FINDNAME | awk '{print $NF}'` ; done
SERVER_HOME=`echo $FINDNAME | sed -e 's@/[^/]*$@@'`
unset FINDNAME

if [ "$SERVER_HOME" = '.' ]; then
   SERVER_HOME=$(echo `pwd` | sed 's/\/bin//')
else
   SERVER_HOME=$(echo $SERVER_HOME | sed 's/\/bin//')
fi

SERVER_NAME=$(cat $SERVER_HOME/module.txt)

if [ ! -d $SERVER_HOME/pids ]; then
    mkdir $SERVER_HOME/pids
fi

PIDFILE=$SERVER_HOME/pids/$SERVER_NAME.pid

BOOT_JAR=$(find $SERVER_HOME/lib -name 'jocean-j2se*')

case $1 in
start)
    ETCDIR=$SERVER_HOME/../etc
    read HEAP_MEMORY PERM_MEMORY DIRECT_MEMORY < $ETCDIR/run.cfg
    echo "Starting $SERVER_NAME with params heap size: $HEAP_MEMORY, perm size: $PERM_MEMORY, direct size: $DIRECT_MEMORY"

    JAVA_OPTS="-server -XX:+HeapDumpOnOutOfMemoryError"
    
    shift
    ARGS=($*)
    for ((i=0; i<${#ARGS[@]}; i++)); do
        case "${ARGS[$i]}" in
        -D*)    JAVA_OPTS="${JAVA_OPTS} ${ARGS[$i]}" ;;
        -Heap*) HEAP_MEMORY="${ARGS[$i+1]}" ;;
        -Perm*) PERM_MEMORY="${ARGS[$i+1]}" ;;
        -Direct*) DIRECT_MEMORY="${ARGS[$i+1]}" ;;
        esac
    done
    # JAVA_OPTS="${JAVA_OPTS} -Dcom.sun.management.jmxremote.port=${JMX_PORT}"
    JAVA_OPTS="${JAVA_OPTS} -Xms${HEAP_MEMORY} -Xmx${HEAP_MEMORY} -XX:PermSize=${PERM_MEMORY} -XX:MaxPermSize=${PERM_MEMORY}  "
    JAVA_OPTS="${JAVA_OPTS} -XX:MaxDirectMemorySize=${DIRECT_MEMORY}"
    JAVA_OPTS="${JAVA_OPTS} -XX:+AlwaysPreTouch"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.recycler.maxCapacity=0"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.allocator.tinyCacheSize=0"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.allocator.smallCacheSize=0"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.allocator.normalCacheSize=0"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.allocator.type=pooled"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.leakDetection.level=PARANOID"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.leakDetection.maxRecords=50"
    JAVA_OPTS="${JAVA_OPTS} -Dio.netty.leakDetection.acquireAndReleaseOnly=true"
    JAVA_OPTS="${JAVA_OPTS} -Duser.dir=${SERVER_HOME} -Dapp.name=$SERVER_NAME"
    echo "start java -jar ${BOOT_JAR} with args ${JAVA_OPTS}"
    nohup java $JAVA_OPTS -jar $BOOT_JAR >/dev/null &
    echo $! > $PIDFILE
    echo STARTED
    ;;

stop)
    echo "Stopping $SERVER_NAME ... "
    if [ ! -f $PIDFILE ]
    then
        echo "warn: could not find file $PIDFILE"
    else
        kill -9 $(cat $PIDFILE)
        rm $PIDFILE
        echo STOPPED
    fi
    ;;

restart)
    ./appctrl.sh stop
    sleep 1
    ./appctrl.sh start
    ;;

esac

exit 0
