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

# DOWNLOAD CERT
function downloadCert() {
    echo -e "[${redColor}*${endColor}] Downloading Cert"
    if curl -s localhost:8080/cert -o cacert.der; then
        echo -e "[${redColor}*${endColor}] Converting .der to .pem format"
        if openssl x509 -inform der -in cacert.der -out burpsuite.pem 2> /dev/null; then
            echo -e "[${redColor}*${endColor}] Checking and Renaming cert to hash"
            hash_value=$(openssl x509 -inform PEM -subject_hash_old -in burpsuite.pem 2> /dev/null | head -n 1)
            if [[ -n $hash_value ]]; then
                mv burpsuite.pem "$hash_value.0"
                rm cacert.der
                echo -e "[${greenColor}DONE${endColor}]\n"
                selectDevice
            else
                echo -e "[${redColor}ERROR${endColor}] Failed to generate hash value\n"
                rm cacert.der burpsuite.pem
            fi
        else
            echo -e "[${redColor}ERROR${endColor}] Failed to convert .der to .pem format\n"
            rm cacert.der
        fi
    else
        echo -e "[${redColor}ERROR${endColor}] Failed to download certificate\n"
    fi
}

# SELECT DEVICE
function selectDevice() {
    echo -e "[${redColor}*${endColor}] Searching for Devices"
    devices=$(adb devices -l | grep -w 'device')
    device_count=$(echo "$devices" | wc -l)

    if [ "$device_count" -eq 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Please, run Genymotion.\n"
        return
    elif [ "$device_count" -eq 1 ]; then
        device=$(echo "$devices" | awk '{print $1}')
        echo -e "[${greenColor}*${endColor}] One device has been found: $device"
    else
        echo -e "[${greenColor}*${endColor}] Some devices has been found:"
        echo "$devices" | nl -w2 -s') '

        read -p "Select a number for one device: " device_number
        device=$(echo "$devices" | sed -n "${device_number}p" | awk '{print $1}')
    fi

    if [ -n "$device" ]; then
        device_ip=$(adb -s "$device" shell ip route | awk '{print $9}')
        echo -e "[${greenColor}*${endColor}] Device selected: $device"
        echo -e "[${greenColor}DONE${endColor}]\n"

        export DEVICE_NAME="$device"
        export DEVICE_IP="$device_ip"
        installCert
    else
        echo -e "[${redColor}ERROR${endColor}] Can't get a device. Check connections and try again.\n"
    fi
}

# INSTALL CERT
function installCert() {
	echo -e "[${redColor}*${endColor}] Installing cert on device"
	adb -s $device root >/dev/null 2>&1
	sleep 1
	adb -s $device shell mount -o remount,rw /
	adb -s $device push 9a5ba575.0 /system/etc/security/cacerts/
	adb -s $device shell ls /system/etc/security/cacerts/9a5ba575.0 >/dev/null 2>&1
	if [ $? -eq 0 ]; then
        echo -e "[${greenColor}*${endColor}] Cert file found on device"

        echo -e "[${greenColor}*${endColor}] Cert installed"
        echo -e "[${greenColor}DONE${endColor}]\n"

        rm $hash_value.0

        echo -e "[${greenColor}https://lautarovculic.com${endColor}]\n"
        echo -e "Do you want automatize and control the flow of proxy?"
        echo -e "Check [${greenColor}https://github.com/lautarovculic/burpCertAndroid/?tab=readme-ov-file#setup-your-proxy-in-bash${endColor}]\n"
    else
        echo -e "[${redColor}!${endColor}] Cert file not found on device. Installation failed.\n"
    fi
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

			## Call Download Cert Function
			downloadCert
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
