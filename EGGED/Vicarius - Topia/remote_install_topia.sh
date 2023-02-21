#!/bin/bash
#
# installs TOPIA system on remote server
#
# Author: Roy Guttmann
######################################################
function usage () {
  echo -e "----- ADD Linux Servers to ${UYL}TOPIA${NC} system -----\

  $0 <-s SERVER>\

  Usage:\
      -s SERVER     What SERVER you want to add to the Topia system,\
                      can be given IPv4 or Domain-Name.\
                      (must give server)\
      -h            Display \"this\" Help/Usage page."
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
  for i in $test_internet;do [[ $i -ne 0 ]] && error_exit "No Internet Access.";done
  printf "\e[2K\rserver: $IP - passed connection test - ${GN}OK${NC}\n"
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

function install_topia () {
  if [[ "$PM" == "yum" ]]; then
    test_wget=$(ssh -q root@$IP "yum -q list --installed wget net-tools 2>/dev/null|wc -l")
    [[ $test_wget -ne 3 ]] && install_wget=$(ssh -q root@$IP "yum install -y wget net-tools &>/dev/null;echo $?")
    [[ $install_wget -ne 0 ]] && error_exit "${UYL}wget${NC} is not installed."
  elif [[ "$PM" == "apt" ]]; then
    test_wget=$(ssh -q root@$IP "apt -q list installed wget net-tools 2>/dev/null|wc -l")
    [[ $test_wget -ne 3 ]] && install_wget=$(ssh -q root@$IP "apt install -y wget net-tools &>/dev/null;echo $?")
    [[ $install_wget -ne 0 ]] && error_exit "${UYL}wget${NC} is not installed."
  fi
  ssh -q root@$IP "mkdir -p /tmp/Topia && cd /tmp/Topia && wget -O /tmp/Topia/Topia.sh https://vicarius-installer.s3.amazonaws.com/Topia.sh && chmod +x /tmp/Topia/Topia.sh"
  ssh -q root@$IP "/tmp/Topia/Topia.sh /SecretKey=76JTV09qFS5sau8aYqqszSrGj9VQHy1XMzNyhYWT195e4P0NndFmLmbaoi9pSLxabIaSa7GCCdqocuxPyPr56SqPQh3tYtJPpJ4LG0fDrW4rMMTLfWot7vg66LGYNe942BVVsSEDyunBtW8DM4PgTZwlh7QD2ZVQULYMwUFDYgd0LGkbny3IMzrbfnS95xT9fVPwdHoWUc1HvfPz8ZY5HiaBoZ0rkFE7TovccqH1hWTYhnZuIXjM6n5C3bjidDDK /Hostname=https://egged-api-gateway.vicarius.cloud /AgentType=LocalAgent"
}

while getopts ":hs:" opt; do
  case ${opt} in
    s) SERVER=$OPTARG;;
    h|*) usage;;
  esac
done

[[ -z "$SERVER" ]] && usage

echo -e "===== ${UYL}${SERVER}${NC} ====="

if [[ -z "$(egrep -v "[a-z]" <<< $SERVER)" ]]; then
  IP=$(host $SERVER|awk '{print $NF}')
  [[ $(wc -l<<<"$IP") -gt 1 ]] && IP=$(head -1<<<"$IP")
else
  IP=$SERVER
fi

# test if server was already added to the AD domain
printf "Checking if $SERVER is up"
ping -W1 -c1 -q $IP &>/dev/null && HN=$(ssh -q -o ConnectTimeout=1 root@$IP "hostname"|cut -d. -f1)
[[ -z "$HN" ]] && error_exit "couldn't connect to the server - ${RD}NO PING/SSH${NC}."
printf "\e[2K\r$SERVER - ${GN}UP${NC}\n"
if [[ "$(egrep -w "$SERVER|$IP|$HN" /root/topia/added)" ]]; then
  echo -e "Already in the TOPIA system - ${GN}OK${NC}\n"
  exit 0
else
  test_connection
  gather_info
  install_topia
  [[ $? -ne 0 ]] && error_exit "had problem adding $SERVER to Topia."
fi

echo "$HN - $IP" >> /root/topia/added

echo -e "${GN}SUCCESSFULLY FINISHED${NC}\n"
