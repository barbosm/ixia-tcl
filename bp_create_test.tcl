# this will create a new test based on a profile 
# and assign a specific network neighborhood to it

# login
set fso_ip "192.0.2.1"
set fso_user "admin"
set fso_passwd "notmypassword"
set bps [bps::connect $fso_ip $fso_user $fso_passwd]

# test variables
set template "Firewall - 64 byte packets"
set name "New Test - FW 128B"
set nn "BreakingPoint Loopback"


# create new test
set test [$bps createTest -template $template -name $name]

# change NN
$test configure -neighborhood $nn
$test save
