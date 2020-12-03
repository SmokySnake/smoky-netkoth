#!/bin/bash
sudo echo -e '''
*** SmokySnake Build netkoth CTF Server ***

         ( )

 0---0   ( ) 
( o o )
 `V_V`==o
   \ \
    \ \
     ) )
    / /
'''

ip address show

default_int=`ip address | grep "^[0-9]:" | grep -v "^[0-9]: lo:" | head -n1 | cut -d" " -f2 | sed "s/://g"`

echo '******'
read -p "Enter interface to set DHCP on [$default_int]: " dhcp_int
dhcp_int=${dhcp_int:-$default_int}


echo 'sudo apt install isc-dhcp-server -Y'
sudo apt install isc-dhcp-server -y

echo 'install python and python3'
sudo apt install python -y
sudo apt install python3 -y

echo 'Install other useful things'
sudo apt install tmux -y

echo "[!]echo INTERFACES=\"$dhcp_int\" | sudo tee /etc/default/isc-dhcp-server"
echo "INTERFACES=\"$dhcp_int\"" | sudo tee /etc/default/isc-dhcp-server

echo '[*]Edit /etc/dhcp/dhcp.conf to correct dhcp parameters'
echo '''
option domain-name "smoky.ctf";

default-lease-time 60;
max-lease-time 7200;
ddns-update-style none;
authoritative;

# Trying to stop multiple leases to same MAC. Not really working
one-lease-per-client true;
deny duplicates;
ignore-client-uids true;

# Set the dhcp ranges and parameters
subnet 10.20.30.0 netmask 255.255.255.0{
	option routers 10.20.30.1;
	option broadcast-address 10.20.30.255;
	option subnet-mask 255.255.255.0;
        range 10.20.30.101 10.20.30.200;
}
''' | sudo tee /etc/dhcp/dhcpd.conf

echo '[*]Set static IP to this machine. If you have multiple interfaces, apply other interface settings manually from the backup created in /etc/netplan/00-installer-config.yaml.BAK'

# Check if backup exists, if not create, if so, don't overwrite original
if [ ! -e /etc/netplan/00-installer-config.yaml.BAK ]; then
	sudo cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.BAK
fi

echo """network:
  version: 2
  ethernets:
    $dhcp_int:
      dhcp4: false
      addresses: [10.20.30.1/24]
""" | sudo tee /etc/netplan/00-installer-config.yaml

# Apply the static ip addres changes
sudo netplan apply


# Start the DHCP server
sudo service isc-dhcp-server start

# Set up firewall rules
# Block all IPV6
sudo sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw

# Open DHCP, ssh, and webserver ports
sudo ufw allow ssh
sudo ufw allow 67/udp
sudo ufw allow 68/udp
sudo ufw allow 80/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 8080/tcp

echo Server built, to start open two terminal sessions \(tmux or ssh\) and run:
echo python netkoth.py
echo Navigate to the smoky-netkoth/www directory:
echo python -m SimpleHTTPServer 8000

# Should we build the vpn server while we're here?
read -p "Would you like to build the VPN server now? [Y/n] " vpn_now
vpn_now=${vpn_now:-Y}

if [[ $vpn_now == "Y" || $vpn_now == "y" ]]; then
	echo Building VPN now
	./buildVpn.sh
else
	echo "Not building VPN now. You can build later with ./buildVpn.sh"
	echo "***************** DONE ********************"
fi
	
