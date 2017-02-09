# create a network neighborhood to be used in
# multiple vdom test case

# var initialization
set fso_ip "192.0.2.1"
set fso_user "admin"
set fso_passwd "notmypasword"
set bps [bps::connect $fso_ip $fso_user $fso_passwd]

# define vdoms and interfaces
# vdom / phy_interfaces should be an integer
set vdom 32
set phy_interfaces 8
set neighborhood_name {tmp_NN}


# no need to change
set vdom_max [expr $vdom*2]
set hosts_client "8."
set hosts_server "9."
set fso_mac_prefix "02:1a:c1"
set fg_ports $phy_interfaces
set vdoms_per_port_pair [expr $vdom/($fg_ports/2)]

# insert the start vlan value as odd integer
set vlan_base 301

# should be higher than interface 4th mac addr field
set start_vlan_mac_index 10
set vlan_limit [expr $vlan_base + $vdom_max - 1]

# create NN object
set mynetwork [$bps createNetwork]

# start Neighborhood creation
$mynetwork begin
$mynetwork configure -name "$neighborhood_name"

# Interface object creation
lassign [$mynetwork add interface -id {i1} -number 1 -mac_address {02:1a:c1:01:00:00}] id obj
lassign [$mynetwork add interface -id {i2} -number 2 -mac_address {02:1a:c1:02:00:00}] id obj
lassign [$mynetwork add interface -id {i3} -number 3 -mac_address {02:1a:c1:03:00:00}] id obj
lassign [$mynetwork add interface -id {i4} -number 4 -mac_address {02:1a:c1:04:00:00}] id obj
lassign [$mynetwork add interface -id {i5} -number 5 -mac_address {02:1a:c1:05:00:00}] id obj
lassign [$mynetwork add interface -id {i6} -number 6 -mac_address {02:1a:c1:06:00:00}] id obj
lassign [$mynetwork add interface -id {i7} -number 7 -mac_address {02:1a:c1:07:00:00}] id obj
lassign [$mynetwork add interface -id {i8} -number 8 -mac_address {02:1a:c1:08:00:00}] id obj


# VLAN objects creation and assignment to correct BP port
set mac_ref $start_vlan_mac_index
for {set j 0} {$j < [expr $phy_interfaces/2] } {incr j} {
    set int_container [expr $j*2+1]
    set index_odd [expr $vlan_base+$j*2*$vdoms_per_port_pair]
    for {set i [expr ($vdoms_per_port_pair*$j)+1]} {$i < $vdoms_per_port_pair*($j+1)+1} {incr i} {
        if {$mac_ref > 255} {
            set mac_ref $start_vlan_mac_index
        }
        set mac_address [format "%s:%02x:00:00" $fso_mac_prefix $mac_ref]
        lassign [$mynetwork add vlan -id "v$index_odd" -default_container "i$int_container" -inner_vlan $index_odd -mac_address "$mac_address"] id obj
        set index_even [expr $index_odd + 1]
        if {$index_odd < $vlan_limit} {
            incr mac_ref
            set mac_address [format "%s:%02x:00:00" $fso_mac_prefix $mac_ref]
            lassign [$mynetwork add vlan -id "v$index_even" -default_container "i[expr $int_container+1]" -inner_vlan $index_even -mac_address "$mac_address"] id obj
        }
        incr index_odd 2
        incr mac_ref
    }
}


# Virtual Router objects creation
for {set index_odd $vlan_base} {$index_odd <= $vlan_limit} {incr index_odd 2} {
   set index_even [expr $index_odd + 1]
   set subnet [expr $index_odd - $vlan_base + 1]
   lassign [$mynetwork add ip_router -id "vr_$index_odd" -default_container "v$index_odd" -ip_address "172.17.${subnet}.1" -gateway_ip_address "172.17.${subnet}.254" -netmask 24] id obj
   lassign [$mynetwork add ip6_router -id "vr6_$index_odd" -default_container "v$index_odd" -ip_address "fd40:1:1:${subnet}::1" -gateway_ip_address "fd40:1:1:${subnet}::ffff" -prefix_length 64] id obj
   if {$index_odd < $vlan_limit} {
      incr subnet
      lassign [$mynetwork add ip_router -id "vr_$index_even" -default_container "v$index_even" -ip_address "172.17.${subnet}.1" -gateway_ip_address "172.17.${subnet}.254" -netmask 24] id obj
      lassign [$mynetwork add ip6_router -id "vr6_$index_even" -default_container "v$index_even" -ip_address "fd40:1:1:${subnet}::1" -gateway_ip_address "fd40:1:1:${subnet}::ffff" -prefix_length 64] id obj

   }
}


# Static IP hosts objects creation
set index_odd $vlan_base
set index_even [expr {$index_odd + 1}]
set remainder [expr {$vdom_max%2}]
set count_limit [expr {($vdom_max/2) + $remainder}]
set vdom_idx 1
set subnet 1
set fw 1
set ips 3
set cf "_fw_"
set ci "_ips_"

for {set i 1} {$i <= $count_limit} {incr i} {
   set host_id [format "vd%02d" $vdom_idx]
   lassign [$mynetwork add ip_static_hosts -id $host_id$cf$subnet -default_container "vr_${index_odd}" -tags "${subnet}${cf}client client_fw" -ip_address "${hosts_client}${subnet}.${fw}.1" -count 254 -gateway_ip_address "172.17.${subnet}.1" -netmask 24] id obj
   lassign [$mynetwork add ip_static_hosts -id $host_id$ci$subnet -default_container "vr_${index_odd}" -tags "${subnet}${ci}client client_ips" -ip_address "${hosts_client}${subnet}.${ips}.1" -count 254 -gateway_ip_address "172.17.${subnet}.1" -netmask 24] id obj
   lassign [$mynetwork add ip6_static_hosts -id 6$host_id$cf$subnet -default_container "vr6_${index_odd}" -tags "${subnet}${cf}6client client6_fw" -ip_address "fd40:1:8:${subnet}:${fw}::1" -count 254 -gateway_ip_address "fd40:1:1:${subnet}::1" -prefix_length 96] id obj
   lassign [$mynetwork add ip6_static_hosts -id 6$host_id$ci$subnet -default_container "vr6_${index_odd}" -tags "${subnet}${ci}6client client6_ips" -ip_address "fd40:1:8:${subnet}:${ips}::1" -count 254 -gateway_ip_address "fd40:1:1:${subnet}::1" -prefix_length 96] id obj
   if {($i < $count_limit) || ($remainder == 0)} {
      incr subnet
      set host_id [format "vd%02d" $vdom_idx]
      lassign [$mynetwork add ip_static_hosts -id $host_id$cf$subnet -default_container "vr_${index_even}" -tags "${subnet}${cf}server server_fw" -ip_address "${hosts_server}${subnet}.${fw}.1" -count 254 -gateway_ip_address "172.17.${subnet}.1" -netmask 24] id obj
      lassign [$mynetwork add ip_static_hosts -id $host_id$ci$subnet -default_container "vr_${index_even}" -tags "${subnet}${ci}server server_ips" -ip_address "${hosts_server}${subnet}.${ips}.1" -count 254 -gateway_ip_address "172.17.${subnet}.1" -netmask 24] id obj
      lassign [$mynetwork add ip6_static_hosts -id 6$host_id$cf$subnet -default_container "vr6_${index_even}" -tags "${subnet}${cf}6server server6_fw" -ip_address "fd40:1:9:${subnet}:${fw}::1" -count 254 -gateway_ip_address "fd40:1:1:${subnet}::1" -prefix_length 96] id obj
      lassign [$mynetwork add ip6_static_hosts -id 6$host_id$ci$subnet -default_container "vr6_${index_even}" -tags "${subnet}${ci}6server server6_ips" -ip_address "fd40:1:9:${subnet}:${ips}::1" -count 254 -gateway_ip_address "fd40:1:1:${subnet}::1" -prefix_length 96] id obj
   }
   incr index_odd 2
   incr index_even 2
   incr vdom_idx
   incr subnet
}

## Define Test Paths
set index_odd $vlan_base
set index_even [expr {$index_odd + 1}]
set remainder [expr {$vdom_max%2}]
set count_limit [expr {($vdom_max/2) + $remainder}]
set vdom_idx 1
set cf "_fw_"
set ci "_ips_"
set subnet 1

for {set i 1} {$i <= $count_limit} {incr i} {
   set host_id [format "vd%02d" $vdom_idx]
   set subnet_s [expr $subnet + 1]
   $mynetwork addPath $host_id$cf$subnet $host_id$cf$subnet_s
   $mynetwork addPath $host_id$ci$subnet $host_id$ci$subnet_s
   $mynetwork addPath 6$host_id$cf$subnet 6$host_id$cf$subnet_s
   $mynetwork addPath 6$host_id$ci$subnet 6$host_id$ci$subnet_s   
   incr index_odd 2
   incr index_even 2
   incr vdom_idx
   incr subnet 2
}

$mynetwork commit
$mynetwork save

itcl::delete object $mynetwork
