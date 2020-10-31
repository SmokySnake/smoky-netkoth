#!/usr/local/bin/python
"""
This is Irongeek's automated scoring code for the NetKotH game.
Create a netkothconfig.ini in the same directory as the script
to look something like:
______________________________________________________________
[General]
outfile = default.htm
sleeptime = 6

[Servers To Check]
linux = http://127.0.0.1/a.htm
windows = http://127.0.0.1/b.htm
wildcard = http://127.0.0.1/c.htm
______________________________________________________________
Server names can be changed (no ":" or "=" characters please),
and the score file will be generated by the script. I'm just now
learning Python, so I'm sure there are better ways to do some
of the tasks I do in this script. You can also make a
template.htm file, and tags that match the server name in all
upper case will be replaced with the score information for that
box.

"""
import urllib2
import urllib
import re
import ConfigParser
import time
import re

#------Make some globals
config = ConfigParser.RawConfigParser()
scores = ConfigParser.RawConfigParser()
configfile =""
serverstocheck = ""
sleeptime = ""
outfile = ""
PORT = 8000


def getsettings():        
        print "Grabbing settings"
        global configfile, serverstocheck, sleeptime, outfile
        configfile = config.read("netkothconfig.ini")
        serverstocheck = config.items("Servers To Check")
        sleeptime = config.getint("General", "sleeptime")
        outfile = config.get("General", "outfile")
        
def checkpagesandscore():
        scoresfile = scores.read("netkothscores.txt")
        for server in serverstocheck:
            try:
                print "About to check server " + server[0] + " " + server[1]
                url = urllib2.urlopen(server[1],None,10)
                #url = urllib2.urlopen(server[1])
                html = url.read()        
                team = re.search('<team>(.*)</team>', html, re.IGNORECASE).group(1).strip().replace("=","").replace("<","").replace(">","")
                print "Server " + server[0] + " owned by " + team
                serverscoressection = server[0]+"Scores"
                if not scores.has_option("TotalScores", team): 
                    scores.set("TotalScores", team, 0)
                currentscore = scores.getint( "TotalScores",team)
                scores.set( "TotalScores", team, currentscore+1)
                if not scores.has_option(serverscoressection, team): 
                    scores.set(serverscoressection, team, 0)
                currentscore = scores.getint( serverscoressection,team)
                scores.set( serverscoressection, team, currentscore+1)
            except IOError:
                print server[0] + " " + server[1] + " may be down, skipping it"
            except AttributeError:
                print server[0] + " may not be owned yet"
        with open("netkothscores.txt", 'wb') as scoresfile:                
                scores.write(scoresfile)

def makescoresections():
        scoresfile = scores.read("netkothscores.txt")
        if not scores.has_section("TotalScores"):
                scores.add_section("TotalScores")

        for server in serverstocheck:
                serverscoressection = server[0]+"Scores"
                if not scores.has_section(serverscoressection):
                        scores.add_section(serverscoressection)
        
def maketables(server):
        print "Making score table for " + server[0]
        try:
            serverscoressection = server[0]+"Scores"
            serverscores = scores.items(serverscoressection)
            tableresults = "<div id=\"" + server[0] + "\">"
            tableresults = tableresults + "<table border=\"2\">\n<tr>"
            tableresults = tableresults + "<td colspan=\"2\"><center><b class=\"scoretabletitle\">" +(server[0]).title() + "</b><br>"
            tableresults = tableresults + "<a href=\"" + server[1] + "\">" + server[1]  +"</a>"
            tableresults = tableresults + "</center></td>"
            tableresults = tableresults + "</tr>\n"
            serverscores.sort(key=lambda score: -int(score[1]))
            toptagstart="<div class=\"topscore\">"
            toptagend="</div>"
            for team in serverscores:
                tableresults = tableresults + "<tr><td>" + toptagstart + team[0].title() + toptagend + "</td><td>" + toptagstart + str(team[1]) +  toptagend  + "</td></tr>\n"
                toptagstart="<div class=\"otherscore\">"
                toptagend="</div>"
            tableresults = tableresults + "</table></div>"
            return tableresults
        except:
            print "No section for " + server[0]

# Writes all DHCP leases in the dhcpd.leases file to the config file to collect flags from
# This currently means expired IPs as well as participants IPs are set up as flags at
# http://IP:80/flag.html. Adds interesting dynamic but might need to change.
# TODO: Change the port that flags are found at. Forces participants to listen to net traffic
def get_ips():
    # The file where dhcp files are kept (including old ones)
    lease_file = open('/var/lib/dhcp/dhcpd.leases', 'r')

    # The file final flag ips are written to
    out_file = open('netkothconfig.ini','w')

    # Match on all IPs
    ip_pattern = re.compile("\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")

    # Extract unique IPs from file since sets don't write duplicates (including expired IPs)
    ips = list(set(result.lower() for result in re.findall(ip_pattern, lease_file.read(), flags=0)))
    ips.sort()

    # Prepare the output
    var_num = 1

    # Set up the config file string
    out_string = '''[General]
outfile = ../www/index.html
sleeptime = 60

[Servers To Check]\n'''

    for ip in ips:
        out_string += 'flag' + str(var_num) + ' = ' + 'http://' + ip + ':80/flag.html\n'
        var_num += 1

    # Write the output string to the config file
    n = out_file.write(out_string)

    # Clean up and close out of opened files
    out_file.close()
    lease_file.close()

#------Main begin
while 1:
        #------Update config file IPs from DHCP leases
        get_ips()
        #------Check files that may have changed since las loop
        getsettings() #-------Grab core config values, you have the option to edit config file as the game runs
        makescoresections() #In case score setions for a bax are not there
        templatefilehandle = open("template.htm", 'r')        
        scorepagestring=templatefilehandle.read()
        #------Look at all the pages to see who owns them.
        checkpagesandscore()       

        #------Make Tables
        for server in serverstocheck:
            thistable = maketables(server)
            serverlabeltag=("<" + server[0] + ">").upper()
            print "Searching for " + serverlabeltag + " tag to replace in template.htm (case sensitive)"
            scorepagestring = scorepagestring.replace(serverlabeltag,thistable)
        #------Make Total Table
        thistable = maketables(["Total",""])
        serverlabeltag=("<TOTAL>").upper()
        print "Searching for " + serverlabeltag + " to replace (case sensitive)"
        scorepagestring = scorepagestring.replace(serverlabeltag,thistable)
        #------Making the score page
        print "Writing " + outfile
        outfilehandle = open(outfile, 'w')
        outfilehandle.write(scorepagestring)
        outfilehandle.close()
        print "Sleeping for " + str(sleeptime)
        time.sleep(sleeptime)
#------Main end
