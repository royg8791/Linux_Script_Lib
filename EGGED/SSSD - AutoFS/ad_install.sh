#!/bin/bash
#
# installs the given machine in the AD domain (using sssd).
# adds access to "sysadmin" group along given groups.
# gives sudo access to "sysadmin" group.
#
# Author: Roy Guttmann
######################################################
function usage () {
  echo -e "----- ADD Linux Servers to AD Domain -----\

  \n$0 <-s SERVER> <-g GROUP> <-S>\

  \nUsage:\
  \n    -s SERVER     What SERVER you want to add to the AD domain,\
  \n                    can be given IPv4 or Domain-Name.\
  \n                    (must give server)\
  \n    -g GROUP      The GROUP you want to give acces to this SERVER (given above),\
  \n                    has to be an existing group in the AD (case-sensitive).\
  \n                    (optional)\
  \n    -S            Add SUDO privileges to the chosen GROUP.\
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
  printf "Testing to see if $SERVER has correct DNSs"
  test_dns=$(ssh -q root@$IP 'cat /etc/resolv.conf')
  [[ $(echo "$test_dns"|egrep "10.0.100.155|10.0.100.156"|wc -l) -ne 2 ]] && error_exit "DNS is wrongly configured."
  printf "\e[2K\rDNSs - ${GN}OK${NC}\n"
  printf "Testing to see if $SERVER has internet access"
  test_internet=$(ssh -q root@$IP 'ping -W1 -c1 -q google.com &>/dev/null;echo $?;ping -W1 -c1 -q 8.8.8.8 &>/dev/null;echo $?')
  for i in $test_internet;do [[ $i -ne 0 ]] && INET="no";done # error_exit "No Internet Access.";done
  printf "\e[2K\r"
  [[ -z "$INET" ]] && printf "\e[2K\rInternet access - ${GN}OK${NC}\n"
  echo -e "server: $IP - passed connection test - ${GN}OK${NC}"
}

function gather_info () {
  server_info=$(mysql -N --user=root --password=Aa123456 phpipam -e\
    "SELECT inet_ntoa(ip_addr),custom_OSDIST,custom_OSVER FROM ipaddresses WHERE custom_OSTYPE = 'linux'"|\
    grep $IP)
  DISTR=$(awk '{print $2}' <<< $server_info)
  VER=$(awk '{print $3}' <<< $server_info)
  # define Package Manager (PM)
  if [[ "oracle rhel centos" =~ "$DISTR" ]]; then
    PM="yum"
    [[ $VER < 7 ]] && error_exit "Server OS is too OLD."
  elif [[ "$DISTR" == "ubuntu" ]]; then
    PM="apt"
    [[ $VER < 16 ]] && error_exit "Server OS is too OLD."
  fi
  echo -e "OS distribution: $DISTR - Package Manager: $PM - ${GN}OK${NC}"
}

function active_directory () {
  # start with installing required components or test if they already exist
  printf "Installing relevant components on $SERVER"
  YUM_LST="sssd realmd adcli oddjob oddjob-mkhomedir samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python"
  APT_LST="sssd realmd adcli oddjob oddjob-mkhomedir libnss-sss libpam-sss sssd-tools samba-common-bin packagekit"
  if [[ "$PM" == "yum" ]]; then
    # check if components are already installed
    is_installed=$(ssh -q root@$IP "yum list -q installed $YUM_LST")
    [[ $(wc -l <<< "$is_installed") -ne 11 ]] &&\
    is_installed=$(ssh -q root@$IP "yum list -q installed ${YUM_LST}-utils")
    # if some components are missing - use package manager to install them
    if [[ $(wc -l <<< "$is_installed") -ne 11 ]]; then
      [[ "$INET" ]] && error_exit "NO Internet Access."
      installation=$(ssh -q root@$IP "yum install -y $YUM_LST &>/dev/null;echo $?")
      [[ $installation -ne 0 ]] &&\
      installation=$(ssh -q root@$IP "yum install -y ${YUM_LST}-utils &>/dev/null;echo $?")
      [[ $installation -ne 0 ]] && error_exit "Had a problem while installing needed components."
    fi
  elif [[ "$PM" == "apt" ]]; then
    # check if components are already installed
    is_installed=$(ssh -q root@$IP "apt list --installed $APT_LST 2>/dev/null")
    # if some components are missing - use package manager to install them
    if [[ $(wc -l <<< "$is_installed") -ne 11 ]]; then
      [[ "$INET" ]] && error_exit "NO Internet Access."
      installation=$(ssh -q root@$IP "apt install -y $APT_LST &>/dev/null;echo $?")
      [[ $installation -ne 0 ]] &&\
      installation=$(ssh -q root@$IP "apt install -y ${APT_LST}-utils &>/dev/null;echo $?")
      [[ $installation -ne 0 ]] && error_exit "Had a problem while installing needed components."
    fi
  fi
  printf "\e[2K\rAll needed components are Installed - ${GN}OK${NC}\n"
  echo -e "Joining ${UYL}egged.intra${NC} AD Domain"
  domain_test=$(ssh -q root@$IP "realm list|grep ^[^' ']")
  [[ "$(grep egged.intra <<< $domain_test)" ]] && echo -e "Server ${UGN}${SERVER}${NC} is already in the AD Domain - ${GN}OK${NC}\n" && exit 0
  ssh -q root@$IP 'realm join --user phpipam-ldap --computer-ou="OU=Linux Servers,OU=Servers,OU=DeskTop,DC=egged,DC=intra" egged.intra'
  domains=$(ssh -q root@$IP "realm list|grep ^[^' ']")
  [[ -z "$(grep egged.intra <<< $domains)" ]] && error_exit "had problems connecting to egged.intra Domain."
  echo -e "Successfuly connected to \"egged.intra\" Domain - ${GN}OK${NC}"
  printf "Altering sssd/AD files to allow access to specific groups."
  ssh -q root@$IP "sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' /etc/sssd/sssd.conf;\
    sed -i 's/access_provider = ad/access_provider = simple/' /etc/sssd/sssd.conf"
  if [[ "$GROUP" ]]; then
    sssd_line="simple_allow_groups = @sysadmin@egged.intra,@${GROUP}@egged.intra"
  else
    sssd_line="simple_allow_groups = @sysadmin@egged.intra"
  fi
  # add groups "sysadmin" and "$GROUP" to allow them access to the server.
  # if -S is specified, give SUDO privileges to the requested $GROUP
  ssh -q root@$IP "echo '$sssd_line' >> /etc/sssd/sssd.conf;echo '%sysadmin@egged.intra ALL=(ALL) ALL' >> /etc/sudoers"
  [[ "$GROUP" && "$SUDO" == "yes" ]] && ssh -q root@$IP "echo '%${GROUP}@egged.intra ALL=(ALL) ALL' >> /etc/sudoers"
  printf "\e[2K\rSuccessfuly added groups: sysadmin $GROUP - ${GN}OK${NC}\n"
  ssh -q root@$IP "realm list|egrep 'egged.intra|login'"
}

while getopts ":hs:g:S" opt; do
  case ${opt} in
    s) SERVER=$OPTARG;;
    g) GROUP=$OPTARG;;
    S) SUDO="yes";;
    h|*) usage;;
  esac
done

echo -e "===== ${UYL}${SERVER}${NC} ====="

[[ -z "$SERVER" ]] && usage
[[ $(host $SERVER|wc -l) -gt 1 ]] && error_exit "Too many DNSs/IPs configured on this IP/DNS"
if [[ -z "$(egrep -v "[a-z]" <<< $SERVER)" ]]; then
  IP=$(host $SERVER|awk '{print $NF}')
else
  IP=$SERVER
fi

# test if server was already added to the AD domain
printf "Checking if $SERVER is up"
ping -W1 -c1 -q $IP &>/dev/null && HN=$(ssh -q -o ConnectTimeout=1 root@$IP "hostname"|cut -d. -f1)
[[ -z "$HN" ]] && error_exit "couldn't connect to the server - ${RD}NO PING/SSH${NC}."
printf "\e[2K\r$SERVER - ${GN}UP${NC}\n"
if [[ "$(egrep -w "$SERVER|$IP|$HN" /root/ad-linux/added)" ]]; then
  echo -e "Already in the AD Domain - ${GN}OK${NC}\n"
  exit 0
else
  gather_info
  test_connection
  active_directory
fi
if [[ "$SUDO" ]]; then
  echo "$HN - $IP - group: $GROUP - SUDO" >> /root/ad-linux/added
else
  echo "$HN - $IP - group: $GROUP" >> /root/ad-linux/added
fi
echo -e "${GN}SUCCESSFULLY FINISHED${NC}\n"
