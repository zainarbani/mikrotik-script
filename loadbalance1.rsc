# mar/21/2022 01:25:31 by RouterOS 6.49.4
#
# PCC + NTH load balance with recursive gateway
# https://www.daryllswer.com/multi-wan-setups-with-retail-isps-part-2-implementation-using-routeros
#
# PCC same speed ex: 2:0-ISP1, 2:1-ISP2
# PCC diff speed ex: 3:0-ISP1, 3:1-ISP1, 3:2-ISP2
# NTH same speed ex: 2:1-ISP1, 2:2-ISP2
# NTH diff speed ex: 3:1-ISP1, 3:2-ISP1, 3:3-ISP2


:local ETHISP1 "ether1";
:local ETHISP2 "ether2";
:local ETHCLIENT "ether3";
:local GWISP1 "10.10.10.1";
:local GWISP1 "20.20.20.1";
:local LOCALNET {"192.168.0.1"; "192.168.1.1"; "192.168.2.1"};

:foreach i in=$LOCALNET do={
 /ip firewall address-list add address=$i list=local
}

/ip firewall nat
add action=masquerade chain=srcnat out-interface=$ETHISP1
add action=masquerade chain=srcnat out-interface=$ETHISP2

/ip firewall mangle
add action=accept chain=prerouting comment=accept-local \
    dst-address-list=local
add action=mark-connection chain=prerouting comment=LB-conn connection-mark=\
    no-mark in-interface=$ETHISP1 new-connection-mark=ISP1_conn \
    passthrough=no
add action=mark-connection chain=prerouting connection-mark=no-mark \
    in-interface=$ETHISP2 new-connection-mark=ISP2_conn passthrough=no
add action=mark-connection chain=prerouting comment=LB-pcc connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local dst-port=80,8080,443 \
    in-interface=$ETHCLIENT new-connection-mark=ISP1_conn passthrough=yes \
    per-connection-classifier=both-addresses-and-ports:3/0 protocol=tcp
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local dst-port=80,8080,443 \
    in-interface=$ETHCLIENT new-connection-mark=ISP1_conn passthrough=yes \
    per-connection-classifier=both-addresses-and-ports:3/1 protocol=tcp
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local dst-port=80,8080,443 \
    in-interface=$ETHCLIENT new-connection-mark=ISP2_conn passthrough=yes \
    per-connection-classifier=both-addresses-and-ports:3/2 protocol=tcp
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local dst-port=80,8080,443 \
    in-interface=$ETHCLIENT new-connection-mark=ISP1_conn passthrough=yes \
    per-connection-classifier=both-addresses-and-ports:3/0 protocol=udp
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local dst-port=80,8080,443 \
    in-interface=$ETHCLIENT new-connection-mark=ISP1_conn passthrough=yes \
    per-connection-classifier=both-addresses-and-ports:3/1 protocol=udp
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local dst-port=80,8080,443 \
    in-interface=$ETHCLIENT new-connection-mark=ISP2_conn passthrough=yes \
    per-connection-classifier=both-addresses-and-ports:3/2 protocol=udp
add action=mark-connection chain=prerouting comment=LB-nth connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local in-interface=$ETHCLIENT \
    new-connection-mark=ISP1_conn nth=3,1 passthrough=yes
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local in-interface=$ETHCLIENT \
    new-connection-mark=ISP1_conn nth=3,2 passthrough=yes
add action=mark-connection chain=prerouting connection-mark=no-mark \
    dst-address-list=!local dst-address-type=!local in-interface=$ETHCLIENT \
    new-connection-mark=ISP2_conn nth=3,3 passthrough=yes
add action=mark-routing chain=prerouting comment=LB-route connection-mark=ISP1_conn \
    in-interface=$ETHCLIENT new-routing-mark=to_ISP1 passthrough=no
add action=mark-routing chain=prerouting connection-mark=ISP2_conn \
    in-interface=$ETHCLIENT new-routing-mark=to_ISP2 passthrough=no
add action=mark-routing chain=output connection-mark=ISP1_conn \
    new-routing-mark=to_ISP1 out-interface=$ETHISP1 passthrough=no
add action=mark-routing chain=output connection-mark=ISP2_conn \
    new-routing-mark=to_ISP2 out-interface=$ETHISP2 passthrough=no

/ip route
add distance=1 gateway=$GWISP1
add distance=1 dst-address=9.9.9.9/32 gateway=$GWISP1
add check-gateway=ping distance=1 gateway=9.9.9.9 routing-mark=to_ISP1 \
    target-scope=30
add distance=2 gateway=$GWISP1 routing-mark=to_ISP2
add distance=2 gateway=$GWISP2
add distance=1 dst-address=9.9.9.10/32 gateway=$GWISP2
add check-gateway=ping distance=1 gateway=9.9.9.10 routing-mark=to_ISP2 \
    target-scope=30
add distance=2 gateway=$GWISP2 routing-mark=to_ISP1

# special route rule example
/ip firewall address-list
add list=speedtest address=s.speedtest.net
add list=speedtest address=c.speedtestcustom.com

/ip firewall mangle
add action=mark-connection chain=prerouting comment=speedtest-to-ISP2 \
    dst-address-list=speedtest in-interface=ether3 new-connection-mark=ISP2_conn \
    passthrough=yes place-before=[find where comment=LB-route]
