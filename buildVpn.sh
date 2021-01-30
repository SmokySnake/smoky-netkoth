#!/bin/bash
echo OpenVPN build script for NetKoth CTF
sudo echo Building OpenVPN Server and config files
me=$(whoami)

# Get user defined variables
ip address
ctf_int=$1
phys_ip=$2
[ ! -z $ctf_int ] && echo CTF interface: $ctf_int || read -p "Please type the name of the interface ctf targets are on (e.g. ens33):" ctf_int
[ ! -z $phys_ip ] && echo CTF IP: $phys_ip || read -p "Please type the IP address of the interface connected to the physical network (e.g. 192.168.237.16): " phys_ip
read -p "Please enter the email for your ca cert, can be fake, just remember it [ctf@ctf.com] " ca_email
ca_email=${ca_email:-ctf@ctf.com}

# Set up directory variables
EASY_DIR="/home/$me/easy-rsa"
CLIENT_DIR="/home/$me/client-configs"

# Install openvpn and easy-rsa
sudo apt install openvpn easy-rsa

# Set up directories
cd ~/
mkdir $EASY_DIR
mkdir -p $CLIENT_DIR/keys
mkdir $CLIENT_DIR/files
ln -s /usr/share/easy-rsa/* $EASY_DIR
sudo chown $me $EASY_DIR
chmod 700 $EASY_DIR
chmod -R 700 $CLIENT_DIR

# Set vars
cd $EASY_DIR

# Create vars file
var_string="""set_var EASYRSA_REQ_COUNTRY    \"US\"
set_var EASYRSA_REQ_PROVINCE   \"NewYork\"
set_var EASYRSA_REQ_CITY       \"New York City\"
set_var EASYRSA_REQ_ORG        \"DigitalOcean\"
set_var EASYRSA_REQ_EMAIL      \"$ca_email\"
set_var EASYRSA_REQ_OU         \"Community\"
set_var EASYRSA_ALGO 	       \"ec\"
set_var EASYRSA_DIGEST         \"sha512\"
"""

echo "$var_string" > $EASY_DIR/vars

# Generate keys
$EASY_DIR/easyrsa init-pki
$EASY_DIR/easyrsa build-ca nopass
sudo cp $EASY_DIR/pki/ca.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
$EASY_DIR/easyrsa gen-req server nopass

# Copy server private key to openvpn directory
sudo cp $EASY_DIR/pki/private/server.key /etc/openvpn/server
echo Please type \'yes\'
$EASY_DIR/easyrsa sign-req server server

# Copyo signed certifcates to openvpn directory
sudo cp $EASY_DIR/pki/ca.crt /etc/openvpn/server
sudo cp $EASY_DIR/pki/issued/server.crt /etc/openvpn/server

# Generate Cryptographic material
openvpn --genkey --secret $EASY_DIR/ta.key
sudo cp $EASY_DIR/ta.key /etc/openvpn/server

# Generate client keys
$EASY_DIR/easyrsa gen-req client1 nopass
cp $EASY_DIR/pki/private/client1.key $CLIENT_DIR/keys/

# Generate client certificates
echo Please type \'yes\'
$EASY_DIR/easyrsa sign-req client client1
cp $EASY_DIR/pki/issued/client1.crt $CLIENT_DIR/keys/

# Move keys and certs to client-configs directory
cp $EASY_DIR/ta.key $CLIENT_DIR/keys
cp $EASY_DIR/pki/ca.crt $CLIENT_DIR/keys
sudo chown $me.$me $CLIENT_DIR/keys/*

# Generate server.conf file
server_conf_string='''port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh none
server 10.20.31.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "route 10.20.30.0 255.255.255.0"
duplicate-cn
keepalive 10 120
tls-crypt ta.key
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
explicit-exit-notify 1
'''

echo "$server_conf_string" | sudo tee /etc/openvpn/server/server.conf

# Enable ip forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Allow ip forwarding in firewall
ufw_string="""#OPENVPN RULES
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.20.31.0/24 -o $ctf_int -j MASQUERADE
COMMIT
# END OPENVPN RULES
"""

sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.BAK
echo "$ufw_string" | sudo tee /etc/ufw/before.rules 
sudo cat /etc/ufw/before.rules.BAK | sudo tee -a /etc/ufw/before.rules 

sudo sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw

# Set up other fireall access rules
sudo ufw allow 1194
sudo ufw allow OpenSSH

sudo ufw disable
sudo ufw enable

# Start OpenVPN
sudo systemctl -f enable openvpn-server@server.service
sudo systemctl start openvpn-server@server.service
sudo systemctl status openvpn-server@server.service

# Generate client.ovpn file
base_conf_string="""client
dev tun
proto udp
remote $phys_ip 1194
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
key-direction 1
verb 3
"""

echo "$base_conf_string" | tee $CLIENT_DIR/base.conf

KEY_DIR=$CLIENT_DIR/keys
OUTPUT_DIR=$CLIENT_DIR/files
BASE_CONFIG=$CLIENT_DIR/base.conf

# Generate client ovpn files
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/client1.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/client1.key \
    <(echo -e '</key>\n<tls-crypt>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-crypt>') \
    > ${OUTPUT_DIR}/client1.ovpn    



