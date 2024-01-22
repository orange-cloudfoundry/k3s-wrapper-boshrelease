#!/bin/bash

#--- Delete cilium interface
cilium_ifaces="$(ifconfig | grep "cilium" | sed -e "s+:.*++g")"

for iface in ${cilium_ifaces} ; do
  ip link delete ${iface}
done

#--- Clean iptables from cilium rules
iptables-save | grep -iv cilium | iptables-restore
ip6tables-save | grep -iv cilium | ip6tables-restore