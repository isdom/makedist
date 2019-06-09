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

function launchjar() {
    BOOT_JAR=$(find $SERVER_HOME/lib -name 'jocean-j2se*')
    ECSID=$(curl -s http://100.100.100.200/latest/meta-data/instance-id)
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
    JAVA_OPTS="${JAVA_OPTS} -Duser.dir=$SERVER_HOME -Dapp.name=$SERVER_NAME -Decs.id=$ECSID"
    echo "start java -jar ${BOOT_JAR} with args ${JAVA_OPTS}"
    nohup java $JAVA_OPTS -jar $BOOT_JAR >/dev/null &
    echo $! > $PIDFILE
    UDSFILE=$SERVER_HOME/$(cat $PIDFILE).socket
    trycnt=0
    while [ ! -e $UDSFILE ];do
        let trycnt+=1
        if  [ $trycnt -gt 10 ];then
            echo "can't find unix domain socket file: $UDSFILE, exit with -1"
            exit -1
        fi
        echo "[$trycnt]: wait 3s for unix domain socket file: $UDSFILE"
        sleep 3s
    done
}

case $1 in
launch)
    launchjar
    echo "JAR LAUNCHED"
    ;;

bsh)
    UDSFILE=$SERVER_HOME/$(cat $PIDFILE).socket
    APPVER=$(echo "bsh $2;" | nc --no-shutdown -U $UDSFILE)
    echo $APPVER
    ;;

cmd)
    UDSFILE=$SERVER_HOME/$(cat $PIDFILE).socket
    echo "$2 $3 $4 $5 $6 $7 $8 $9;" | nc --no-shutdown -U $UDSFILE > cmd.log
    cat cmd.log
    ;;

start)
    launchjar
    UDSFILE=$SERVER_HOME/$(cat $PIDFILE).socket
    read endpoint namespace role dataid < /home/gdt/etc/acmbootV3.cfg
    RESULT=$(echo "startapp $endpoint $namespace $role $dataid;" | nc --no-shutdown -U $UDSFILE)
    echo "START SRV AND APP: $RESULT"
    ;;

stop)
    echo "Stopping $SERVER_NAME ... "
    if [ ! -f $PIDFILE ]
    then
        echo "warn: could not find file $PIDFILE"
    else
        UDSFILE=$SERVER_HOME/$(cat $PIDFILE).socket
        if [ -e $UDSFILE ];then
            RESULT=$(echo "unfwd;" | nc --no-shutdown -U $UDSFILE)
            echo "invoke un-forward: $RESULT"
            trycnt=0
            RESULT=$(echo "tradecnt;" | nc --no-shutdown -U $UDSFILE)
            while [ "$RESULT" != "0" ];do
                let trycnt+=1
                if  [ $trycnt -gt 5 ];then
                    echo "current trade count is $RESULT, wait for $trycnt times 3s, skip trade count and continue stopapp"
                    break
                fi
                echo "wait 3s because of current trade count is $RESULT"
                sleep 3s
                RESULT=$(echo "tradecnt;" | nc --no-shutdown -U $UDSFILE)
            done
            echo "current trade count is $RESULT, so stop app and exit srv"
            RESULT=$(echo "stopapp;exitsrv;" | nc --no-shutdown -U $UDSFILE)
            echo "STOP APP AND EXIT SRV: $RESULT"
        else
            echo "warn: could not find Unix Domain Socket $UDSFILE, just kill -9 $(cat $PIDFILE)"
            kill -9 $(cat $PIDFILE)
        fi
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
