#!/bin/bash
#
# This script aims to help you configure proxy for Azure Arc for Servers (Linux), 
# defining proxy configuration to the deamons only instead of globally as the native
# azcmagent_proxy does.
#
# Some excerpt for this was extracted from "azcmagent_proxy", which is copyrighted by Microsoft
# and comes with Azure Arc for Server (Linux) installation
# 
# Note #1:  this script must be run as root
# Note #2:  this script only works for systemd platforms for now
# 

DAEMON_CONFIG_DIR=/lib/systemd/system
DAEMON_CONFIG_DIR2=/usr/lib/systemd/system
HIMDSD_SERVICE=himdsd.service
GCAD_SERVICE=gcad.service
EXTD_SERVICE=extd.service

DAEMON_GLOBAL_CONFIG_DIR=/lib/systemd/system.conf.d
PROXY_CONF=${DAEMON_GLOBAL_CONFIG_DIR}/proxy.conf
PROXY_ENV=https_proxy
AHA_PATH=/opt/azcmagent/bin/azcmagent

function print_usage
{
    echo "Usage:  azcmagent_proxydaemon.sh <URL> - to add URL as the proxy for daemons only"
    exit 1
}

function add_proxy_to_daemon ()
{
    if [ $# -ne 1 ]; then
        echo "add_proxy_to_daemon() must be called with one argument"
        exit 1
    fi

    UNIT_FILE=${DAEMON_CONFIG_DIR}/$1
    if [ ! -f ${UNIT_FILE} ]; then
	UNIT_FILE=${DAEMON_CONFIG_DIR2}/$1
	if [ ! -f ${UNIT_FILE} ]; then
            echo "Warning:  unit file $1 does not exist"
            return 0
	fi
    fi

    echo "Setting proxy environment variable to file: ${UNIT_FILE}"
    sed -i "/\[Service\]/aEnvironment=${PROXY_ENV}=${url}" ${UNIT_FILE}
}
function add_proxy_to_aha ()
{
    echo "Adding proxy environment variable to file:  ${AHA_PATH}"

    sed -i "/ Environment Variables below ======/aexport ${PROXY_ENV}=${url}" ${AHA_PATH}
}

function remove_proxy_from_daemon ()
{
    if [ $# -ne 1 ]; then
        echo "remove_proxy() must be called with one argument"
        exit 1
    fi

    UNIT_FILE=${DAEMON_CONFIG_DIR}/$1
    if [ ! -f ${UNIT_FILE} ]; then
	UNIT_FILE=${DAEMON_CONFIG_DIR2}/$1
	if [ ! -f ${UNIT_FILE} ]; then
            echo "Warning:  unit file $1 does not exist"
            return 0
	fi
    fi

    grep -q "Environment=${PROXY_ENV}=" ${UNIT_FILE}
    if [ $? -ne 0 ]; then
        return 0
    fi

    sed -i "/Environment=${PROXY_ENV}=/d" ${UNIT_FILE}
}

function remove_proxy_from_aha ()
{
    if [ ! -f ${AHA_PATH} ]; then
        echo "Error:  file ${AHA_PATH} does not exist"
        exit 1
    fi

    echo "Removing proxy environment variable from file:  ${AHA_PATH}"

    grep -q "export ${PROXY_ENV}=" ${AHA_PATH}
    if [ $? -ne 0 ]; then
        echo "    No proxy previously configured"
        return 0
    fi

    sed -i "/export ${PROXY_ENV}=/d" ${AHA_PATH}
}

# Make sure we are running as root
if [ $EUID != 0 ]; then
   echo "$0 must be invoked as root!"
   exit 1
fi


if [ $# -ne 1 ]; then
   print_usage
fi

url=$1

# For backward compatibility, we always check to see if proxy settings should be
# removed from individual daemon settings
remove_proxy_from_daemon ${HIMDSD_SERVICE}
remove_proxy_from_daemon ${GCAD_SERVICE}
remove_proxy_from_daemon ${EXTD_SERVICE}
remove_proxy_from_aha

add_proxy_to_daemon ${HIMDSD_SERVICE}
add_proxy_to_daemon ${GCAD_SERVICE}
add_proxy_to_daemon ${EXTD_SERVICE}
add_proxy_to_aha

systemctl daemon-reexec
systemctl restart himdsd
systemctl restart gcad
systemctl restart extd