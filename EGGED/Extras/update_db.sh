#!/bin/bash
#
# MySQL
# DB ==> phpipam
# TABLE ==> ipaddresses
# updates LINUX OS_distribution and OS_version
#
# Author: Roy Guttmann
########################################
function progress_bar () {
  # This function will print to the screen (depending on the screen size)
  # a "Progress" bar, e.g. <Progress: [#####-------------] 23.4%>
  local length=$1
  local counter=$2

  screen_size=$(stty size|cut -d' ' -f2)
  [[ $counter -eq $length ]] && printf "%${screen_size}s" && return
  let prog=100000/${length}*${counter}

  dec=$(echo $prog|rev|cut -c3-|cut -c1|rev)
  [[ -z "$dec" ]] && dec=0
  num=$(echo $prog|rev|cut -c4-|rev)
  [[ -z "$num" ]] && num=0

  let bar_size=${screen_size}-20
  let fill=${bar_size}*${num}/100
  let empty=${bar_size}-${fill}
  fill=$(printf "%${fill}s")
  empty=$(printf "%${empty}s")
  printf "Progress [${fill// /#}${empty// /-}] ${num}.${dec}%%\r"
}

function update_linux_server () {
  local ip=$1
  release=$(timeout 2 ssh root@$ip -q 'cat /etc/*release')

  distr=$(grep "^ID=" <<< "$release"|cut -d= -f2|head -1)
  [[ "$distr" =~ "ol" ]] && distr="oracle"
  [[ -z "$distr" ]] && distr=$(echo -e "$release"|awk '{print $1}')
  [[ "$distr" == "Red" ]] && distr="rhel"
  distr=$(echo ${distr,,}|sed 's/"//g')

  version=$(grep "^VERSION_ID=" <<< "$release"|cut -d= -f2|tail -1)
  [[ -z "$version" ]] && version=$(echo -e "$release"|awk '{print $(NF-1)}' 2>/dev/null)
  version=$(echo ${version,,}|sed 's/"//g')

  [[ -z "$distr" || -z "$version" ]] && return

  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_OSDIST = '$distr' WHERE inet_ntoa(ip_addr) = '$ip'"
  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_OSVER = '$version' WHERE inet_ntoa(ip_addr) = '$ip'"

  # update CPUs and Memory
  release2=$(timeout 2 ssh root@$ip -q 'cat /proc/cpuinfo /proc/meminfo')
  cpus=$(grep '^processor' <<< "$release2" | wc -l)
  mem=$(grep '^MemTotal:' <<< "$release2" | awk '{print $2}')
  mem=$(echo $mem|awk '{print $mem/1048576}')
  mem1=$(echo $mem|cut -d. -f1)
  mem2=$(echo $mem|cut -d. -f2|cut -c-1)
  mem="${mem1}.${mem2}"
  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_CPUs = '$cpus' WHERE inet_ntoa(ip_addr) = '$ip'"
  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_MEMgb = '$mem' WHERE inet_ntoa(ip_addr) = '$ip'"
}

function update_windows_server () {
  local ip=$1
  release=$(timeout 2 wmic --user egged_d/admin_sched --password MGGFH-R9YR7 //$ip "select Caption,Version from Win32_OperatingSystem" 2>/dev/null|tail -1)
  [[ "$(grep -i "error" <<< "$release")" ]] && return

  distr=$(cut -d'|' -f1 <<< "$release")
  version="${release##*|}"
  [[ -z "$distr" || -z "$version" ]] && return

  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_OSDIST = '$distr' WHERE inet_ntoa(ip_addr) = '$ip'"
  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_OSVER = '$version' WHERE inet_ntoa(ip_addr) = '$ip'"

  # update CPUs and Memory
  release2=$(timeout 2 wmic --user egged_d/admin_sched --password MGGFH-R9YR7 //$ip "select NumberOfProcessors,TotalPhysicalMemory from Win32_ComputerSystem" 2>/dev/null|tail -1)
  cpus=$(cut -d'|' -f2 <<< "$release2")
  mem=$(cut -d'|' -f3 <<< "$release2")  
  mem=$(echo $mem|awk '{print $mem/1073741824}')
  mem1=$(echo $mem|cut -d. -f1)
  mem2=$(echo $mem|cut -d. -f2|cut -c-1)
  mem="${mem1}.${mem2}"
  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_CPUs = '$cpus' WHERE inet_ntoa(ip_addr) = '$ip'"
  mysql --user=root --password=Aa123456 phpipam -e "UPDATE ipaddresses SET custom_MEMgb = '$mem' WHERE inet_ntoa(ip_addr) = '$ip'"

}

function update_table () {
  local table=$1
  ips=$(echo "$table" | awk '{print $1}')
  amount=$(wc -l <<< "$ips")
  counter=0
  for ip in $ips; do
    let counter+=1
    progress_bar $amount $counter

    os_type=$(grep -w "$ip" <<< "$table"|awk '{print $2}')

    if [[ "${os_type,,}" == "windows" ]]; then
      update_windows_server $ip
    elif [[ "${os_type,,}" == "linux" ]]; then
      update_linux_server $ip
    fi
  done
}

table_phpipam=$(mysql --user=root --password=Aa123456 phpipam -e "SELECT inet_ntoa(ip_addr),custom_OSTYPE FROM ipaddresses WHERE custom_OSTYPE = 'windows' or custom_OSTYPE ='linux' ORDER BY inet_ntoa(ip_addr)"|grep -v ip_addr)

update_table "$table_phpipam"
