#!/bin/bash
#
# gathers info about Linux Servers
#
# author: Roy Guttmann
###################
function usage () { 
  echo -e "\n----- Linux Servers -----\
  \nGather Info\
  \n\n$0 <-e ENV> <-t TYPE> <-d DISTR> <-u OWNER>\
  
  \nUsage:\
  \n    -e ENV        The environment that the machines are running for,\
  \n                    e.g. PRD=\"Production\", TST=\"Testing\", DR=\"Disaster Recovery\".\
  \n    -t TYPE       The Type of the machine, what kind of a machine it is,\
  \n                    e.g. physical, vmware, nutanix, cloud, service, aws.\
  \n    -d DISTR      The Distribution of the Linux OS,\
  \n                    e.g. ubuntu, centos, rhel, oracle.\
  \n    -u OWNER      The Owner of the machine, in Email Address:\
  \n                    Example - \"user@example.com\"\
  \n                    ** if OWNER is specified => return only this parameters results.\
  \n    -h            Display \"this\" Help/Usage page.\n"
  exit 1
}

function mysql_usage () {
  # run command based on Linux OS with extra args if needed
  local ARGS=$@
  mysql -N --user=root --password=Aa123456 phpipam -e \
    "SELECT hostname,inet_ntoa(ip_addr),custom_Type,custom_ENV,custom_OSTYPE,custom_OSDIST,custom_OSVER,custom_CPUs,custom_MEMgb,Owner FROM ipaddresses WHERE custom_OSTYPE = 'linux' $ARGS ORDER BY inet_ntoa(ip_addr);"
  exit 0
}

while getopts ":he:t:u:d:" opt; do
  case ${opt} in
    e) ENV=$OPTARG;;
	  t) TYPE=$OPTARG;;
    d) DISTR=$OPTARG;;
	  u) OWNER=$OPTARG;;
    h|*) usage;;
  esac
done

if [[ "$ENV" || "$TYPE" || "$DISTR" || "$OWNER" ]]; then
  [[ "$ENV" ]] && en="AND custom_ENV = '$ENV'"
  [[ "$TYPE" ]] && ty="AND custom_Type = '$TYPE'"
  [[ "$DISTR" ]] && dist="AND custom_OSDIST = '$DISTR'"
  [[ "$OWNER" ]] && own="AND owner = '$OWNER'"
  mysql_usage "$en $ty $dist $own"
else
  mysql_usage
fi
