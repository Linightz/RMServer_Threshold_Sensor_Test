# RMServer_Threshold_Sensor_Test
The automation of sensor testing of those with threshold triggers on rack-mount servers using BASH and IPMI commands.

Written by Kevin SJ Huang 2019/1/29

## Script usage: ./Thres_Sensor_Test.sh <Sensor_Name> <LAN_IP> <BMC_IP> <BMC_USER> <BMC_PWD>

Missing any of the above parameter will result in test failures.
If sensor name contains spaces, use double quotes or it will be errors.
Make sure your LAN port is set to reconnect automatically after reboot.
This script is designed to run on RHEL7.

This script is designed to test the following sensor threshold ONLY:
Ambient Temp, 
CPU DTS, 
SysBrd 12V 5V 3.3V, 
CMOS Battery, 
Fan N Tach

Use of other sensors will result in test incomplete.

This script uses OOB only, please have the SUT BMC IP ready and run the script on a test client.
In order to check for reboot event, SUT LAN IP is also mandatory.
Test log will show if the SUT has been rebooted, but it won't be considered into pass/fail critiria.

## check_sshpass and check_lan_auto_reconnect not available at the moment
## Need to manually set the SUT to auto re-connect to LAN after reboot prior to test
