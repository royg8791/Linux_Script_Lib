#!/bin/bash
#
# installs AUTOFS on the given machine.
# implements homedirectories of AD users to sssd.
#
# Author: Roy Guttmann
######################################################
function usage () {
  echo -e "----- ${UYL}AUTOFS${NC} - Linux Servers - AD Domain -----\
  \n
  \n$0 <-s SERVER>\
  \n
  \nUsage:\
  \n    -s SERVER     What SERVER you want to implement autoFS on,\
  \n                    can be given IPv4 or Domain-Name.\
  \n                    (must give server)\
  \n    -h            Display \"this\" Help/Usage page."
  exit 1
}
# colors for usage
NC='\e[0m' # no color
RD='\e[0;31m' # red
GN='\e[0;32m' # green
UGN='\e[4;32m' # underlined green
UYL='\e[4;33m' # underlined yellow

function error_exit () {
  local msg=$@
  printf "\e[2K\r${RD}ERROR${NC}: $msg\n\n"
  exit 2
}

function test_connection () {
  # printf "Testing to see if $SERVER has correct DNSs"
  # test_dns=$(ssh -q root@$IP 'cat /etc/resolv.conf')
  # [[ $(echo "$test_dns"|egrep "10.0.100.155|10.0.100.156"|wc -l) -ne 2 ]] && error_exit "DNS is wrongly configured."
  # printf "\e[2K\rDNSs - ${GN}OK${NC}\n"
  printf "Testing to see if $SERVER has internet access"
  test_internet=$(ssh -q root@$IP 'ping -W1 -c1 -q google.com &>/dev/null;echo $?;ping -W1 -c1 -q 8.8.8.8 &>/dev/null;echo $?')
  for i in $test_internet;do [[ $i -ne 0 ]] && INET="no";done # error_exit "No Internet Access.";done
  printf "\e[2K\r"
  [[ -z "$INET" ]] && printf "\e[2K\rInternet access - ${GN}OK${NC}\n"
  echo -e "server: $IP - passed connection test - ${GN}OK${NC}"
}

function gather_info () {
  server_info=$(mysql -N --user=root --password=Aa123456 phpipam -e\
    "SELECT inet_ntoa(ip_addr),custom_OSDIST FROM ipaddresses WHERE custom_OSTYPE = 'linux'"|\
    grep $IP)
  DISTR=$(awk '{print $2}' <<< $server_info)
  # define Package Manager (PM)
  if [[ "oracle rhel centos" =~ "$DISTR" ]]; then
    PM="yum"
  elif [[ "$DISTR" == "ubuntu" ]]; then
    PM="apt"
  fi
  echo -e "OS distribution: $DISTR - Package Manager: $PM - ${GN}OK${NC}"
}

function install_autofs () {
  printf "Installing relevant components on $SERVER"
  # test if the given server is connected to the relevant AD domain
  # domain_test=$(ssh -q root@$IP "realm list|grep ^[^' ']")
  # [[ -z "$(grep egged.intra <<< $domain_test)" ]] && error_exit "Server is not in the AD system"
  if [[ "$PM" == "yum" ]]; then
    # check if "autofs" is already installed
    is_installed=$(ssh -q root@$IP "yum -q list installed autofs")
    if [[ $(wc -l <<< "$is_installed") -ne 2 ]]; then
      # if not installed try installing
      [[ "$INET" ]] && error_exit "NO Internet Access."
      installation=$(ssh -q root@$IP "yum -q install -y autofs &>/dev/null;echo $?")
      [[ $installation -ne 0 ]] && error_exit "Had a problem while installing needed components."
    fi
  elif [[ "$PM" == "apt" ]]; then
    # check if "autofs" is already installed
    is_installed=$(ssh -q root@$IP "apt list --installed autofs")
    if [[ $(wc -l <<< "$is_installed") -ne 2 ]]; then
      # if not installed try installing
      [[ "$INET" ]] && error_exit "NO Internet Access."
      installation=$(ssh -q root@$IP "apt install -y autofs &>/dev/null;echo $?")
      [[ $installation -ne 0 ]] && error_exit "Had a problem while installing needed components."
    fi
  fi
  printf "\e[2K\rAll needed components are Installed - ${GN}OK${NC}\n"

  printf "Altering autofs/sssd/AD files to create homedirs for AD users that are mounted on request."
  # add autofs mount point and change auto home dir for AD users, if doesn't already exists
  if [[ -z "$(ssh -q root@$IP "grep -w nas /etc/auto.master")" ]]; then
    ssh -q root@$IP "echo '/-      /etc/auto.nas        --timeout=120' >> /etc/auto.master &&\
    echo -e '/egged-homes        -fstype=nfs,rw,soft,intr        egged-nas.egged.intra:/egged-homes\n\
    \n/egged-shared         -fstype=nfs,rw,soft,intr        egged-nas.egged.intra:/egged-shared' > /etc/auto.nas &&\
    sed -i 's/fallback_homedir.*/fallback_homedir = \/egged-homes\/users\/\%u/' /etc/sssd/sssd.conf"
    ssh -q root@$IP "mkdir -p /egged-homes && mkdir -p /egged-shared && systemctl restart sssd && systemctl start autofs && systemctl restart autofs"
  else
    ssh -q root@$IP "sed -i 's/.*nas.*//g' /etc/auto.master && rm -rf /etc/auto.nas01 &&\
    echo '/-      /etc/auto.nas        --timeout=120' >> /etc/auto.master &&\
    echo -e '/egged-homes        -fstype=nfs,rw,soft,intr        egged-nas.egged.intra:/egged-homes\n\
    \n/egged-shared         -fstype=nfs,rw,soft,intr        egged-nas.egged.intra:/egged-shared' > /etc/auto.nas &&\
    sed -i 's/fallback_homedir.*/fallback_homedir = \/egged-homes\/users\/\%u/' /etc/sssd/sssd.conf"
    ssh -q root@$IP "mkdir -p /egged-homes && mkdir -p /egged-shared && systemctl restart sssd && systemctl start autofs && systemctl restart autofs"

  fi
  printf "\e[2K\rSuccessfuly created mount point and homedirs for AD users - ${GN}OK${NC}\n"
}

while getopts ":hs:" opt; do
  case ${opt} in
    s) SERVER=$OPTARG;;
    h|*) usage;;
  esac
done

echo -e "===== ${UYL}${SERVER}${NC} ====="

[[ -z "$SERVER" ]] && usage
if [[ -z "$(egrep -v "[a-z]" <<< $SERVER)" ]]; then
  IP=$(host $SERVER|awk '{print $NF}')
else
  IP=$SERVER
fi

# test if server was already added to the AD domain
printf "Checking if $SERVER is up"
ping -c1 -W1 -q $IP &>/dev/null && HN=$(ssh -q -o ConnectTimeout=1 root@$IP "hostname"|cut -d. -f1)
[[ -z "$HN" ]] && error_exit "couldn't connect to the server - ${RD}NO PING/SSH${NC}."
printf "\e[2K\r$SERVER - ${GN}UP${NC}\n"
if [[ "$(egrep -w "$SERVER|$IP|$HN" /root/autofs/added)" ]]; then
  echo -e "Already has autofs configured - ${GN}OK${NC}\n"
  exit 0
else
  gather_info
  test_connection
  install_autofs
fi

echo "$HN - $IP" >> /root/autofs/added

echo -e "${GN}SUCCESSFULLY FINISHED${NC}\n"
