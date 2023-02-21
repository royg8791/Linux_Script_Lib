#!/bin/bash
#
# will run on machine startup
# checks if api-gateway is stopped/running
# stop the process if needed and run from scrach
#
# author: Roy Guttmann
#################################################
# runs with daemon service on startup:
#
# /etc/systemd/system/apigw.service
#
# [Unit]
# Description=API Gateway Boot
# [Service]
# ExecStart=/root/.apigw_boot.sh
# [Install]
# WantedBy=multi-user.target
#
# with script: /root/.apigw_boot.sh
#
# source /root/.bashrc
# /usr/bin/apigw_check reboot &>/tmp/apigw_boot.log
# echo -e "\n\n" >> /tmp/apigw_boot.log
# #################################################
function usage () {
  echo -e "\nAPIGW_check <reboot/status/start/stop>\

  \nreboot/restart      Stops the service and then Restarts it.\
  \nstatus              Displays service Status.\
  \nstart               Starts the service.\
  \nstop                Stops the service.\n"
  exit 0
}

function apigw () {
  local action=$1
  if [[ "$WL_yes" == "no" ]]; then
    su weblogic -c "python /home/weblogic/api_gw_install/APIGateway.py \
      -f /home/weblogic/api_gw_install/gateway-props.json \
      -a $action -u weblogic -p welcome1"
  else
    python /home/weblogic/api_gw_install/APIGateway.py \
      -f /home/weblogic/api_gw_install/gateway-props.json \
      -a $action -u weblogic -p welcome1
  fi
}

function error_exit () {
  local msg=$1
  echo -e "$msg"
  exit 0
}

ACTION=$1
actions="restart reboot status start stop"
[[ -z "$ACTION" || -z "$(echo $actions|grep -w $ACTION)" ]] && usage

cd /home/weblogic/api_gw_install
[[ "$(whoami)" != "weblogic" ]] && WL_yes=no

if [[ "$ACTION" == "restart" || "$ACTION" == "reboot" ]]; then
  data=$(apigw "status")
  gw=$(grep "gateway server:" <<< "$data"|awk '{print $NF}')
  
  # check special cases
  if [[ "${gw,,}" != "running" ]]; then
    apigw_check "start"
  else
    apigw_check "stop"
    sleep 3
    apigw_check "start"      
  fi
else
  apigw "$ACTION"
fi

exit 0