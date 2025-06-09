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

# DOWNLOAD CERT ######################################################################################################
function downloadCert() {
    echo -e "[${redColor}*${endColor}] Downloading Cert"
    if curl -s http://127.0.0.1:8080/cert -o cacert.der; then
        echo -e "[${redColor}*${endColor}] Converting .der to .pem format"
        if openssl x509 -inform der -in cacert.der -out burpsuite.pem 2>/dev/null; then
            echo -e "[${redColor}*${endColor}] Checking and Renaming cert to hash"
            hash_value=$(openssl x509 -inform PEM -subject_hash_old -in burpsuite.pem 2>/dev/null | head -n 1)
            export hash_value
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

# SELECT DEVICE ######################################################################################################
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
        echo -e "[${greenColor}*${endColor}] Some devices have been found:"
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

# DETECT DEVICE TYPE #################################################################################################
function detectDeviceType() {
    local device_info=$(adb -s "$device" shell getprop ro.kernel.qemu 2>/dev/null)
    local build_product=$(adb -s "$device" shell getprop ro.build.product 2>/dev/null)
    local build_model=$(adb -s "$device" shell getprop ro.product.model 2>/dev/null)
    
    if [[ "$device_info" == "1" ]]; then
        if [[ "$build_product" == *"google_apis"* ]] || [[ "$build_model" == *"Google APIs"* ]] || [[ "$build_product" == *"sdk"* ]]; then
            echo "android_studio_emulator"
        elif [[ "$build_product" == *"genymotion"* ]] || [[ "$build_model" == *"Genymotion"* ]]; then
            echo "genymotion"
        else
            echo "generic_emulator"
        fi
    else
        echo "physical_device"
    fi
}

# CHECK ROOT ACCESS ##################################################################################################
function checkRootAccess() {
    local device_type="$1"
    
    # For Android Studio emulators try adb root first ####
    if [[ "$device_type" == "android_studio_emulator" ]] || [[ "$device_type" == "generic_emulator" ]]; then
        echo -e "[${redColor}*${endColor}] Attempting adb root for emulator"
        adb -s "$device" root >/dev/null 2>&1
        sleep 2
        
        # Check if we have root via adb ####
        local whoami_result=$(adb -s "$device" shell whoami 2>/dev/null)
        if [[ "$whoami_result" == "root" ]]; then
            echo -e "[${greenColor}*${endColor}] Root access confirmed via adb root"
            echo "adb_root"
            return
        fi
    fi
    
    # Try su -c method for other devices ####
    local root_check=$(adb -s "$device" shell "su -c 'id'" 2>/dev/null)
    if [[ $root_check == *"uid=0"* ]]; then
        echo -e "[${greenColor}*${endColor}] Root access confirmed via su"
        echo "su_root"
        return
    fi
    
    # Try alternative su syntax ####
    local root_check2=$(adb -s "$device" shell "su 0 id" 2>/dev/null)
    if [[ $root_check2 == *"uid=0"* ]]; then
        echo -e "[${greenColor}*${endColor}] Root access confirmed via su 0"
        echo "su0_root"
        return
    fi
    
    echo "no_root"
}

# INSTALL CERT #######################################################################################################
function installCert() {
    local cert="$hash_value.0"
    local device_type=$(detectDeviceType)

    echo -e "[${redColor}*${endColor}] Installing cert on device"
    echo -e "[${blueColor}*${endColor}] Device type detected: $device_type"
    
    # Push certificate to device first ####
    echo -e "[${redColor}*${endColor}] Pushing certificate to device"
    adb -s "$device" push "$cert" /sdcard/ >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Failed to push certificate to device\n"
        return
    fi

    # Check root access ####
    echo -e "[${redColor}*${endColor}] Checking root access"
    local root_method=$(checkRootAccess "$device_type")
    
    if [[ "$root_method" == "no_root" ]]; then
        handleNonRootDevice "$cert" "$device_type"
        return
    fi

    # Install certificate ####
    case $root_method in
        "adb_root")
            installCertWithAdbRoot "$cert"
            ;;
        "su_root")
            installCertWithSu "$cert"
            ;;
        "su0_root")
            installCertWithSu0 "$cert"
            ;;
        *)
            echo -e "[${yellowColor}!${endColor}] Unknown root method, trying standard approach"
            installCertWithSu "$cert"
            ;;
    esac
}

# INSTALL CERT WITH ADB ROOT (Android Studio Emulators) ##############################################################
function installCertWithAdbRoot() {
    local cert="$1"
    
    echo -e "[${yellowColor}*${endColor}] Using adb root method for emulator"
    
    # Remount system as read-write ####
    echo -e "[${redColor}*${endColor}] Remounting system partition"
    adb -s "$device" shell "mount -o remount,rw /" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        adb -s "$device" shell "mount -o rw,remount /system" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${redColor}ERROR${endColor}] Failed to remount system partition"
            fallbackUserInstall "$cert"
            return
        fi
    fi

    # Copy certificate ####
    echo -e "[${redColor}*${endColor}] Copying certificate to system directory"
    adb -s "$device" shell "cp /sdcard/$cert /system/etc/security/cacerts/" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Failed to copy certificate to system directory"
        fallbackUserInstall "$cert"
        return
    fi

    # Set ownership ####
    echo -e "[${redColor}*${endColor}] Setting certificate ownership"
    adb -s "$device" shell "chown root:root /system/etc/security/cacerts/$cert" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${yellowColor}!${endColor}] Warning: Failed to set certificate ownership (might still work)"
    fi

    # Set permissions ####
    echo -e "[${redColor}*${endColor}] Setting certificate permissions"
    adb -s "$device" shell "chmod 644 /system/etc/security/cacerts/$cert" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${yellowColor}!${endColor}] Warning: Failed to set certificate permissions (might still work)"
    fi

    # Verify installation ####
    echo -e "[${redColor}*${endColor}] Verifying certificate installation"
    adb -s "$device" shell "ls -la /system/etc/security/cacerts/$cert" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "[${greenColor}*${endColor}] Certificate successfully installed as SYSTEM certificate"
        
        # Clean temp files #### 
        adb -s "$device" shell "rm /sdcard/$cert" >/dev/null 2>&1
        rm "$cert"
        
        echo -e "[${greenColor}DONE${endColor}]\n"
        echo -e "[${greenColor}*${endColor}] Please restart your emulator for the certificate to take effect"
        echo -e "[${greenColor}https://lautarovculic.com${endColor}]\n"
        echo -e "Do you want automatize and control the flow of proxy?"
        echo -e "Check [${greenColor}https://github.com/lautarovculic/burpCertAndroid/?tab=readme-ov-file#setup-your-proxy-in-bash${endColor}]\n"
    else
        echo -e "[${redColor}ERROR${endColor}] Certificate installation verification failed"
        fallbackUserInstall "$cert"
    fi
}

# INSTALL CERT WITH SU -C (Physical devices, Genymotion) #############################################################
function installCertWithSu() {
    local cert="$1"
    
    echo -e "[${yellowColor}*${endColor}] Using su -c method"
    
    # Remount system as read-write ####
    echo -e "[${redColor}*${endColor}] Remounting system partition"
    adb -s "$device" shell "su -c 'mount -o remount,rw /'" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Failed to remount system partition"
        fallbackUserInstall "$cert"
        return
    fi

    # Copy certificate to system directory ####
    echo -e "[${redColor}*${endColor}] Copying certificate to system directory"
    adb -s "$device" shell "su -c 'cp /sdcard/$cert /system/etc/security/cacerts/'" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Failed to copy certificate to system directory"
        fallbackUserInstall "$cert"
        return
    fi

    # Set ownership ####
    echo -e "[${redColor}*${endColor}] Setting certificate ownership"
    adb -s "$device" shell "su -c 'chown root:root /system/etc/security/cacerts/$cert'" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${yellowColor}!${endColor}] Warning: Failed to set certificate ownership (might still work)"
    fi

    # Set permissions ####
    echo -e "[${redColor}*${endColor}] Setting certificate permissions"
    adb -s "$device" shell "su -c 'chmod 644 /system/etc/security/cacerts/$cert'" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${yellowColor}!${endColor}] Warning: Failed to set certificate permissions (might still work)"
    fi

    # Verify installation ####
    echo -e "[${redColor}*${endColor}] Verifying certificate installation"
    adb -s "$device" shell "su -c 'ls -la /system/etc/security/cacerts/$cert'" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "[${greenColor}*${endColor}] Certificate successfully installed as SYSTEM certificate"
        
        # Clean temp files ####
        adb -s "$device" shell "su -c 'rm /sdcard/$cert'" >/dev/null 2>&1
        rm "$cert"
        
        echo -e "[${greenColor}DONE${endColor}]\n"
        echo -e "[${greenColor}*${endColor}] Please reboot your device for the certificate to take effect"
        echo -e "[${greenColor}https://lautarovculic.com${endColor}]\n"
        echo -e "Do you want automatize and control the flow of proxy?"
        echo -e "Check [${greenColor}https://github.com/lautarovculic/burpCertAndroid/?tab=readme-ov-file#setup-your-proxy-in-bash${endColor}]\n"
    else
        echo -e "[${redColor}ERROR${endColor}] Certificate installation verification failed"
        fallbackUserInstall "$cert"
    fi
}

# INSTALL CERT WITH SU 0 (Alternative su syntax) #####################################################################
function installCertWithSu0() {
    local cert="$1"
    
    echo -e "[${yellowColor}*${endColor}] Using su 0 method"
    
    # Remount system as read-write ####
    echo -e "[${redColor}*${endColor}] Remounting system partition"
    adb -s "$device" shell "su 0 mount -o remount,rw /" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Failed to remount system partition"
        fallbackUserInstall "$cert"
        return
    fi

    # Copy certificate to system directory ####
    echo -e "[${redColor}*${endColor}] Copying certificate to system directory"
    adb -s "$device" shell "su 0 cp /sdcard/$cert /system/etc/security/cacerts/" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${redColor}ERROR${endColor}] Failed to copy certificate to system directory"
        fallbackUserInstall "$cert"
        return
    fi

    # Set ownership ####
    echo -e "[${redColor}*${endColor}] Setting certificate ownership"
    adb -s "$device" shell "su 0 chown root:root /system/etc/security/cacerts/$cert" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${yellowColor}!${endColor}] Warning: Failed to set certificate ownership (might still work)"
    fi

    # Set permissions ####
    echo -e "[${redColor}*${endColor}] Setting certificate permissions"
    adb -s "$device" shell "su 0 chmod 644 /system/etc/security/cacerts/$cert" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${yellowColor}!${endColor}] Warning: Failed to set certificate permissions (might still work)"
    fi

    # Verify installation ####
    echo -e "[${redColor}*${endColor}] Verifying certificate installation"
    adb -s "$device" shell "su 0 ls -la /system/etc/security/cacerts/$cert" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "[${greenColor}*${endColor}] Certificate successfully installed as SYSTEM certificate"
        
        # Clean temp files ####
        adb -s "$device" shell "su 0 rm /sdcard/$cert" >/dev/null 2>&1
        rm "$cert"
        
        echo -e "[${greenColor}DONE${endColor}]\n"
        echo -e "[${greenColor}*${endColor}] Please reboot your device for the certificate to take effect"
        echo -e "[${greenColor}https://lautarovculic.com${endColor}]\n"
        echo -e "Do you want automatize and control the flow of proxy?"
        echo -e "Check [${greenColor}https://github.com/lautarovculic/burpCertAndroid/?tab=readme-ov-file#setup-your-proxy-in-bash${endColor}]\n"
    else
        echo -e "[${redColor}ERROR${endColor}] Certificate installation verification failed"
        fallbackUserInstall "$cert"
    fi
}

# FALLBACK: INSTALL AS USER CERTIFICATE ##############################################################################
function fallbackUserInstall() {
    local cert="$1"
    
    echo -e "\n[${yellowColor}!${endColor}] Falling back to USER certificate installation"
    echo -e "[${yellowColor}!${endColor}] Note: Some apps may not trust user certificates"
    
    # Convert to .crt for user installation ####
    local user_cert="burpsuite_user.crt"
    cp "$cert" "$user_cert"
    
    adb -s "$device" push "$user_cert" /sdcard/ >/dev/null 2>&1
    
    echo -e "\n[${blueColor}Manual Steps for User Certificate${endColor}]"
    echo -e "${grayColor}1.${endColor} On your device, go to Settings > Security > Encryption & credentials"
    echo -e "${grayColor}2.${endColor} Tap 'Install a certificate'"
    echo -e "${grayColor}3.${endColor} Select 'CA certificate'"
    echo -e "${grayColor}4.${endColor} Navigate to /sdcard/ and select $user_cert"
    echo -e "${grayColor}5.${endColor} Give it a name and tap OK"
    
    echo -e "\n[${purpleColor}*${endColor}] User certificate will be installed and trusted for most apps"
    echo -e "[${yellowColor}!${endColor}] For apps with certificate pinning, you may need additional steps\n"
    
    rm "$cert" "$user_cert" 2>/dev/null
}

# HANDLE NON-ROOT DEVICES ############################################################################################
function handleNonRootDevice() {
    local cert="$1"
    local device_type="$2"
    
    echo -e "[${yellowColor}!${endColor}] Root access not available"
    
    if [[ "$device_type" == "android_studio_emulator" ]]; then
        echo -e "[${yellowColor}!${endColor}] For Android Studio emulators without root:"
        echo -e "${grayColor}1.${endColor} Use an emulator image WITHOUT Google Play Store"
        echo -e "${grayColor}2.${endColor} Or enable root access in AVD settings"
        echo -e "${grayColor}3.${endColor} Or use Magisk modules for rooting"
    fi
    
    echo -e "[${blueColor}*${endColor}] Attempting user certificate installation instead"
    fallbackUserInstall "$cert"
}

# MAIN VALIDATIONS ###################################################################################################
echo -e "[${redColor}*${endColor}] Checking if ADB is installed."
if ! command -v adb &>/dev/null; then
    echo -e "[${redColor}!${endColor}] ADB is not installed, please install ADB."
    exit 1
fi
echo -e "[${greenColor}DONE${endColor}]"

echo -e "\n[${redColor}*${endColor}] Checking if OPENSSL is installed."
if ! command -v openssl &>/dev/null; then
    echo -e "[${redColor}!${endColor}] OPENSSL is not installed, please install OPENSSL."
    exit 1
fi
echo -e "[${greenColor}DONE${endColor}]"

echo -e "\n[${redColor}*${endColor}] Checking if BurpSuite is Running."
if ! pgrep -f burpsuite >/dev/null; then
    echo -e "[${redColor}!${endColor}] Please run BurpSuite.\n"
    exit 1
fi
echo -e "[${greenColor}DONE${endColor}]\n"

# Start it all
downloadCert
