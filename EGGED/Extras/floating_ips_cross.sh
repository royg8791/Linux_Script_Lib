#!/bin/bash
#
# performs switch between floating IPs within two servers
#
# author: Roy Guttmann
#############################################################################

prod_test=$(ping -W1 -c1 -q 10.0.110.253 &>/dev/null;echo $?)
[[ $prod_test -eq 0 ]] && prod_host=$(ssh -q oracle@icprod "hostname")
factory_test=$(ping -W1 -c1 -q 10.0.110.254 &>/dev/null;echo $?)
[[ $factory_test -eq 0 ]] && factory_host=$(ssh -q oracle@icfactory "hostname")

if [[ "$prod_host" && "$factory_host" && "prod_host" != "$factory_host" ]]; then
  ssh -q oracle@$prod_host "sudo ifconfig ens192:0 down"
  ssh -q oracle@$factory_host "sudo ifconfig ens192:1 down"
  ssh -q oracle@$factory_host "sudo ifconfig ens192:0 10.0.110.253 netmask 255.255.255.0 up"
  ssh -q oracle@$prod_host "sudo ifconfig ens192:1 10.0.110.254 netmask 255.255.255.0 up"
elif [[ "$prod_host" && "prod_host" == "$factory_host" ]]; then
  ssh -q oracle@$prod_host "sudo ifconfig ens192:0 down"
  [[ "$factory_host" == "$(hostname)" ]] && prod_host=eicprd2.egged.intra || prod_host=$(hostname)
  ssh -q oracle@$prod_host "sudo ifconfig ens192:0 10.0.110.254 netmask 255.255.255.0 up"
else
  if [[ "$prod_host" ]]; then
    [[ "$prod_host" == "$(hostname)" ]] && factory_host=eicprd2.egged.intra || factory_host=$(hostname)
    ssh -q oracle@$factory_host "sudo ifconfig ens192:0 10.0.110.254 netmask 255.255.255.0 up"
  elif [[ "$factory_host" ]]; then
    [[ "$factory_host" == "$(hostname)" ]] && prod_host=eicprd2.egged.intra || prod_host=$(hostname)
    ssh -q oracle@$factory_host "sudo ifconfig ens192:0 10.0.110.254 netmask 255.255.255.0 up"
  else
    prod_host="eicprd1.egged.intra"
    factory_host="eicprd2.egged.intra"
    ssh -q oracle@$prod_host "sudo ifconfig ens192:0 10.0.110.253 netmask 255.255.255.0 up"
    ssh -q oracle@$factory_host "sudo ifconfig ens192:1 10.0.110.254 netmask 255.255.255.0 up"
  fi
fi
