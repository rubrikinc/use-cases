#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

if [ "$(id -g -n)" != 'vyattacfg' ] ; then
	exec sg vyattacfg -c "/bin/vbash $(readlink -f $0) $@"
fi

echo "[*] Entering configuration mode"
configure

echo "[V] Configuration Interfaces"

set interfaces ethernet eth0 address MANAGEMENT_IP_BITMASK
set interfaces ethernet eth0 description MANAGEMENT_NAME

commit

set protocols static route 0.0.0.0/0 next-hop MANAGEMENT_GATEWAY

set service https api keys id rbk key RBKAPIKEY
set service https api port 8080
set service https virtual-host rbk01 listen-address MANAGEMENT_IP
set service https virtual-host rbk01 server-name MANAGEMENT_IP
set service https certificates system-generated-certificate lifetime 7000

set service ssh port 22
set service ssh listen-address MANAGEMENT_IP

commit 

save
