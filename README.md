# BurpSuite Cert for Android Installer

## v1

## About
This is an automated script for install BurpSuite certificate in Android devices.

### The script was tested and developed for Android devices running in Genymmotion.

If you have errors in the execution of the script, visit the step by step in the post I have written:
### [POST](https://lautarovculic.com/intercept-android-app-traffic-with-burpsuite/)

## Setup your proxy in bash

```bash
alias adb_set_proxy="adb -s <deviceIP>:5555 shell settings put global http_proxy $(ip -o -4 addr show <interfaceNetwork> | awk '{print $4}' | sed 's/\/.*//g'):8080"
```
```bash
alias adb_unset_proxy='adb -s <deviceIP> shell settings put global http_proxy :0'
```

- **deviceIP**: Android Genymotion IP Address.
- **interfaceNetwork**: Network interface where your local IPv4 address is located.

https://lautarovculic.com
