#!/bin/bash

# finds free IPs for use by new VMs

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

vlan=$1

[[ -z "$vlan" ]] && echo -e "\nUsage:\n  $0 <vlan>\n    e.g.  $0 110" && exit 1

counter=0
for i in $(seq 254);do
  let counter+=1
  progress_bar 254 $counter
  [[ -z "$(mysql -N --user=root --password=Aa123456 phpipam -e\
    "SELECT hostname,inet_ntoa(ip_addr) FROM ipaddresses ORDER BY inet_ntoa(ip_addr);"|\
    grep 10.0.${vlan}.${i})" ]] && \
    [[ $(host 10.0.${vlan}.${i} &>/dev/null;echo $?) -ne 0 ]] && \
    [[ $(ping -W1 -c1 10.0.${vlan}.${i} &>/dev/null;echo $?) -ne 0 ]] && \
    result_ips+="10.0.$vlan.$i\n"
done

echo -e "\e[0;32m${result_ips}\e[0m"
