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

	echo "Install function"

}

# DEVICES LIST FUNCTION
function devicesList() {

	echo "Devices function"
	installCert

}


## ADB INSTALLLED?
if command -v adb &> /dev/null; then
    echo -e "\n[${redColor}*${endColor}] Checking if ADB is installed."
    echo -e "[${greenColor}DONE${endColor}]"

    ## BURP RUNNING?
    if ps aux | grep -v grep | grep -q burpsuite; then
    	echo -e "\n[${redColor}*${endColor}] Checking if BurpSuite is Running."
    	echo -e "[${greenColor}DONE${endColor}]\n"

		## Call Function
		devicesList
    else
        echo -e "\n[${redColor}!${endColor}] Please run BurpSuite."
        exit 0
    fi

else
    echo -e "\n[${redColor}!${endColor}] ADB is not installed, please instal ADB."
    exit 0
fi

