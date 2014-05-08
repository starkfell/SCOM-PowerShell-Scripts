############################################################################################################################
# Powershell Script:    SCOM_Remove_RegKey_From_Hosts.ps1
#
# Author:      			Ryan Irujo
#
# Inception:            08.17.2012
# Last Modified:        08.17.2012
#
# Description:          This Script removes existing Registry Keys used by SCOM for monitoring purposes. The script 
#                       checks to see that the SCOM SubKey already exists under HKLM\SOFTWARE. If the SCOM SubKey isn't 
#                       found the script exits. If the SCOM SubKey is found the Monitor SubKey Value provided by the user is
#                       checked to see if it exists under the SCOM SubKey. If the Monitor SubKey value is found, it is then 
#						removed. Output is provided to the user in the Console throughout th entire process.
#
# Version Updates:      08.17.2012 - [R.Irujo]
#						Initial Version
#
# PowerShell Syntax:    ./SCOM_Remove_RegKey_From_Hosts.ps1 [Monitor_SubKey_Value] "[Server_List]"
#
# PowerShell Example:   ./SCOM_Remove_RegKey_From_Hosts.ps1 PaymentProcessorExceptionsMonitor "C:\Scripts\Server_List.csv"
#
############################################################################################################################

Param($Monitor_Key_Value,$Server_List)

Clear-Host
$ErrorActionPreference = "SilentlyContinue"

# List of Servers to Add Registry Key To.
$objCSV = Import-Csv "$Server_List"

# Checking the Monitor SubKey Value provided by the user. If the value is NULL, then the script exits.
if (!$Monitor_Key_Value) {Write-Host "The Monitor SubKey you provided equals NULL! Please provide a string value."; exit}

# Checking that the Host List provided by the user exists. If the Path or File doesn't exist, then the script exits.
if (!$objCSV) {Write-Host "The Path or File Name of the Server List you provided doesn't exist!"; exit}


# Going through the Server List Recursively.
ForEach($strHost in $objCSV){

	Write-Host "                    "
	Write-Host "$($StrHost.Hostname)"
	Write-Host "----------------------------------------------------------------------------------------"

	# Opening Up Remote Registry Key on Host(s).
	$RegAccess       = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$strHost.Hostname)

	# Opening up Path to SOFTWARE SubKey.
	$SOFTWARE_SubKey = $RegAccess.OpenSubKey("SOFTWARE\",$True)

	# Checking to see if the SCOM SubKey exits under the SOFTWARE SubKey
	$SCOM_Key_Check  = $SOFTWARE_SubKey.GetSubKeyNames() | Where-Object {$_ -eq "SCOM"}

	# If the SCOM SubKey does not exist, it is created on the Host under - HKLM\SOFTWARE\
	If ($SCOM_Key_Check -ne "SCOM") {
		Write-Host "SCOM Subkey does NOT exist on $($strHost.Hostname)! Verify that it requires this custom MP!"; exit
		}
		Else {
		Write-Host "SCOM Subkey found on $($strHost.Hostname). Looking for $($Monitor_Key_Value) SubKey..."
		}


	# Opening up the Path to where all SCOM Monitoring Keys reside - HKLM\SOFTWARE\SCOM\
	$Monitor_SubKey = $RegAccess.OpenSubKey("SOFTWARE\SCOM\",$True)

	# Retrieveing the Monitoring Key to be removed.
	$Monitor_SubKey_Check = $Monitor_SubKey.GetSubKeyNames() | Where-Object {$_ -eq $Monitor_Key_Value}

		
	# If the Monitoring Key exists under - HKLM\SOFTWARE\SCOM\, it is removed.
	If ($Monitor_SubKey_Check -eq $Monitor_Key_Value) {
		Write-Host "$($Monitor_Key_Value) Subkey found on $($strHost.Hostname)! Removing SubKey..."
		$Monitor_SubKey.DeleteSubKey($Monitor_Key_Value)
		#$Monitor_SubKey.CreateSubKey($Monitor_Key_Value)
		Write-Host "$($Monitor_Key_Value) Subkey has been removed from $($strHost.Hostname)!"
		}
		Else {
		Write-Host "$($Monitor_Key_Value) Subkey was NOT FOUND on $($strHost.Hostname)"
		}
	}
