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
default_vpn_int=`ip address | grep "^[0-9]:" | grep -v "^[0-9]: lo:" | tail -n1 | cut -d" " -f2 | sed "s/://g"`

echo '******'
read -p "Enter interface to set DHCP on (i.e. network where CTF boxes will be placed) [$default_int]: " dhcp_int
dhcp_int=${dhcp_int:-$default_int}

if [ $default_int == $default_vpn_int ]; then
	echo Only a single network interface is detected. Add VPN interface in /etc/netplan later
	singleInt="Y"
else
	singleInt="N"
	read -p "Enter interface to set VPN on (i.e. network where players will access CTF net) [$default_vpn_int]: " vpn_int
	vpn_int=${vpn_int:-$default_vpn_int}
	default_vpn_ip=$(ip ad show dev $vpn_int | grep "inet " | sed 's/^ *//g' | cut -d" " -f2 | cut -d '/' -f1)
	read -p "Enter IP address to set VPN on (i.e. network where players will access CTF net) [$default_vpn_ip]: " vpn_ip
	vpn_ip=${vpn_ip:-$default_vpn_ip}
	read -p "Is this a static IP [y|N]: " is_static_vpn_ip
	is_static_vpn_ip=${is_static_vpn_ip:-N}
	if [ $is_static_vpn_ip == "Y" ] || [ $is_static_vpn_ip == "y" ]; then
		default_vpn_gateway_ip=$(echo $vpn_ip | cut -d'.' -f1,2,3)
		default_vpn_gateway_ip="${default_vpn_gateway_ip}.1"
		read -p "Enter default gateway for VPN interface [$default_vpn_gateway_ip]: " vpn_gateway_ip
		vpn_gateway_ip=${vpn_gateway_ip:-$default_vpn_gateway_ip}
	fi
fi


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

if [ $singleInt == "Y" ]; then
echo """network:
  version: 2
  ethernets:
    $dhcp_int:
      dhcp4: false
      addresses: [10.20.30.1/24]
""" | sudo tee /etc/netplan/00-installer-config.yaml
elif [ $is_static_vpn_ip == "n" ] || [ $is_static_vpn_ip == "N" ]; then
echo """network:
  version: 2
  ethernets:
    $dhcp_int:
      dhcp4: false
      addresses: [10.20.30.1/24]
    $vpn_int:
      dhcp4: true
""" | sudo tee /etc/netplan/00-installer-config.yaml
else
echo """network:
  version: 2
  ethernets:
    $dhcp_int:
      dhcp4: false
      addresses: [10.20.30.1/24]
    $vpn_int:
      dhcp4: false
      addresses: [$vpn_ip/24]
      gateway4: $vpn_gateway_ip
      nameservers: 
        addresses: [$vpn_gateway_ip]
""" | sudo tee /etc/netplan/00-installer-config.yaml

fi

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
if [ $singleInt == "N" ]; then
	read -p "Would you like to build the VPN server now? [Y/n] " vpn_now
	vpn_now=${vpn_now:-Y}
	
	if [[ $vpn_now == "Y" || $vpn_now == "y" ]]; then
		echo Building VPN now
		./buildVpn.sh $vpn_int $vpn_ip
	else
		echo "Not building VPN now. You can build later with ./buildVpn.sh"
		echo "***************** DONE ********************"
	fi
else
	echo "Not building VPN now. You can build later with ./buildVpn.sh"
	echo "***************** DONE ********************"
fi
	
