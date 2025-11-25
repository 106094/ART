$ssidname="rpiroom"
$check= netsh wlan show interface |  findstr /C:"Wi-Fi" /C:"SSID" /C:"State"
if(!($check -match $ssidname)){
    netsh wlan connect name=$ssidname ssid=$ssidname

}
