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
    [ -z "$PID" ] && { echo "MDCA CEF Connector is not running"; exit 1; }
    echo "Stopping MDCA CEF Connector, pid: $PID..."
    kill -9 $PID 1>/dev/null 2>/dev/null && { echo "MDCA CEF Connector killed"; } || { echo "Could not kill MDCA CEF Connector"; }
    rm $PIDFile
}

CEFConnector_pid() {
    PID=`ps ax | grep -e"$JAR_NAME" | grep -v "grep" | awk '{printf(substr($0,1,6))}'`
    echo $PID > $PIDFile
    [ -z "$PID" ] && return 1;
    return 0;
}

# Script Configuration
SCRIPT_DIR="/opt/mdca-cef"

# Script Variables
SCRIPT_NAME=`basename $0`
JAR_NAME=$(jq -r '.jarName' $SCRIPT_DIR/settings.json)
TOKEN=$(jq -r '.token' $SCRIPT_DIR/settings.json)
LOG_DIR=$(jq -r '.logDir' $SCRIPT_DIR/settings.json)
PROXY=$(jq -r '.proxy' $SCRIPT_DIR/settings.json)
PIDFile="$SCRIPT_DIR/mdca-cef-connector.pid"

# Creates log directory if not exist 
mkdir -p $LOG_DIR

case "$1" in
   start)
        CEFConnector_pid
        [ -z "$PID" ] || { echo "MDCA CEF Connector is already running, pid: $PID"; exit 1; }
        CEFConnector_start
        sleep 1
        CEFConnector_pid
        [ -z "$PID" ] && { echo "MDCA CEF Connector is not running"; exit 1; }
        echo "MDCA CEF Connector is running, pid: $PID"
        exit $?
    ;;

    stop)
        CEFConnector_pid
        CEFConnector_stop
        exit $?
    ;;
    
    status)
        CEFConnector_pid
        [ -z "$PID" ] && { echo "MDCA CEF Connector is not running"; exit 1; }
        echo "MDCA CEF Connector is running, pid: $PID"
    ;;
    
    *)
        echo "Usage: $SCRIPT_NAME { start | stop | status | resetdb }"
        exit 1;;
esac