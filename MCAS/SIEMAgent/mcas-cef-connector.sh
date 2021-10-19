#!/bin/bash

CEFConnector_start() {
    echo "Starting MCAS CEF Connector"
    if [ -n "$PROXY"  ]; then
        java -jar $SCRIPT_DIR/$JAR_NAME --logsDirectory $LOG_DIR --proxy $PROXY --token $TOKEN &
    else
        java -jar $SCRIPT_DIR/$JAR_NAME --logsDirectory $LOG_DIR --token $TOKEN &
    fi
    echo "MCAS CEF Connector started"
}

CEFConnector_stop() {
    [ -z "$PID" ] && { echo "MCAS CEF Connector is not running"; exit 1; }
    echo "Stopping MCAS CEF Connector, pid: $PID..."
    kill -9 $PID 1>/dev/null 2>/dev/null && { echo "MCAS CEF Connector killed"; } || { echo "Could not kill MCAS CEF Connector"; }
    rm $PIDFile
}

CEFConnector_pid() {
    PID=`ps ax | grep -e"$JAR_NAME" | grep -v "grep" | awk '{printf(substr($0,1,6))}'`
    echo $PID > $PIDFile
    [ -z "$PID" ] && return 1;
    return 0;
}

# Load Script variables
SCRIPT_NAME=`basename $0`
SCRIPT_DIR="/opt/MCASCEFConnector"
JAR_NAME=$(jq -r '.jarName' $SCRIPT_DIR/settings.json)
TOKEN=$(jq -r '.token' $SCRIPT_DIR/settings.json)
LOG_DIR=$(jq -r '.logDir' $SCRIPT_DIR/settings.json)
PROXY=$(jq -r '.proxy' $SCRIPT_DIR/settings.json)
PIDFile=$(echo $0 | sed 's/\.sh/\.pid/g')

# Creates log directory if not exist 
mkdir -p $LOG_DIR

case "$1" in
   start)
        CEFConnector_pid
        [ -z "$PID" ] || { echo "MCAS CEF Connector is already running, pid: $PID"; exit 1; }
        CEFConnector_start
        sleep 1
        CEFConnector_pid
        [ -z "$PID" ] && { echo "MCAS CEF Connector is not running"; exit 1; }
        echo "MCAS CEF Connector is running, pid: $PID"
        exit $?
    ;;

    stop)
        CEFConnector_pid
        CEFConnector_stop
        exit $?
    ;;
    
    status)
        CEFConnector_pid
        [ -z "$PID" ] && { echo "MCAS CEF Connector is not running"; exit 1; }
        echo "MCAS CEF Connector is running, pid: $PID"
    ;;
    
    *)
        echo "Usage: $SCRIPT_NAME { start | stop | status | resetdb }"
        exit 1;;
esac