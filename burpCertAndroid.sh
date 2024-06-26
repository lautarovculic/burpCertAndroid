#!/bin/bash
# Author: Lautaro D. Villarreal Culic'
# https://lautarovculic.com

# Colors #########################
greenColor="\e[0;32m\033[1m"
endColor="\033[0m\e[0m"
redColor="\e[0;31m\033[1m"
blueColor="\e[0;34m\033[1m"
yellowColor="\e[0;33m\033[1m"
purpleColor="\e[0;35m\033[1m"
turquoiseColor="\e[0;36m\033[1m"
grayColor="\e[0;37m\033[1m"
##################################

# CTRL C #########################
trap ctrl_c INT
function ctrl_c(){
	echo -e "\n${redColor}[*] Exiting...${endColor}\n"
	exit 0
}
##################################

# INSTALL CERT FUNCTION
function installCert() {
	echo "Install function (To-Do)"
}

# DEVICES LIST FUNCTION
function devicesList() {
	echo "Devices function (To-Do)"
	installCert
}

## ADB INSTALLLED?
echo -e "\n[${redColor}*${endColor}] Checking if ADB is installed."
if command -v adb &> /dev/null; then
    echo -e "[${greenColor}DONE${endColor}]"

	## OPENSSL IS INSTALLED?
	echo -e "\n[${redColor}*${endColor}] Checking if OPENSSL is installed."
    if command -v openssl &> /dev/null; then
	    echo -e "[${greenColor}DONE${endColor}]"

    	## BURP RUNNING?
		echo -e "\n[${redColor}*${endColor}] Checking if BurpSuite is Running."
    	if ps aux | grep -v grep | grep -q burpsuite; then
    	    echo -e "[${greenColor}DONE${endColor}]\n"

			## Call Function
			devicesList
    	else
        	echo -e "[${redColor}!${endColor}] Please run BurpSuite.\n"
        	exit 0
    	fi
	else
    	echo -e "\n[${redColor}!${endColor}] OPENSSL is not installed, please install OPENSSL."
		exit 0
	fi
else
    echo -e "\n[${redColor}!${endColor}] ADB is not installed, please install ADB."
    exit 0
fi
