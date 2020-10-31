# smoky-netkoth
My version of Irongeek's netkoth CTF scoreboard. Automatically grabs flag ips based on DHCP leases.

Credit goes to Irongeek and the original can be found at the original site: http://www.irongeek.com/

## Usage:
Build the server with the `buildServer.sh` script by setting up DHCP (note only tested on Ubuntu 20.04). Only works automatically with single interface, can have multiple but requires some manual fiddling with netplan. See notes in script
```
ubuntu@ubuntu2004:~$ chmod 755 buildServer.sh
ubuntu@ubuntu2004:~$ ./buildServer.sh
ubuntu@ubuntu2004:~$ python netkoth.py
ubuntu@ubuntu2004:~$ cd ../www #Wherever the smoky-netkoth/www directory is
ubuntu@ubuntu2004:~$ python -m SimpleHTTPServer 8000
```

Now have users navigate to `http://10.20.30.1:8000` to see the scoreboard and game instructions

Connect users with static IPs in the range `10.20.30.10-100`, and connect any challenge box such as found at vulnhub, that has DHCP enabled and can have a webserver set up (doesn't even need to be set up intially, but once participants root the box they should be able to set one up). 

This server will hand out DHCP IPs in the range `10.20.30.101-200`, and periodically check for a flag at `http://IP:80/flag.html`. Users will receive points by filling their team name into this `flag.html` file in the format `<team>USERNAME</team>`

Have fun!!
