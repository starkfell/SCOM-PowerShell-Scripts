#  --- [Monitors_AlertOnState_Settings] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        05.17.2013
# Last Modified:    05.20.2013
#
# Description:      Script that retrieves the AlertOnState Settings on all enabled Monitors in SCOM. This script borrow heavily 
#                   from the existing script found in the TechNet article link below:
#                
#                   http://social.technet.microsoft.com/Forums/en-US/operationsmanagergeneral/thread/328d5479-6ff6-49dc-b342-81f3ca70ce30/
#
#                   This Script needs to be ran from a machine that has the Operations Manager Console installed.
#
#
# Changes:          05.20.2013 - [R. Irujo]
#                   - Code Cleanup and added comments to existing Code.
#
#
# Additional Notes: AlertOnState has two possible values: "Warning" and "Error"
#
#
# Syntax:          ./Monitors_AutoResolve_Settings <RMS_Server> <AlertOnState_Value>
#
# Example:         ./Monitors_AutoResolve_Settings SCOMServer101.scom.local Warning

param($RMS,$AlertOnState)

Clear-Host

#Verifying that the $RMS variables has been provided.
if (!$RMS) {
  Write-Host "The SCOM Management Server currently hosting the RMS Role must be provided."
	exit 1
	}


# Verifying that the $AlertOnState has been provided and is set to either Warning or Error.
if (($AlertOnState -ne "Warning") -and ($AlertOnState -ne "Error")) {
	Write-Host "AutoResolve variable must be set to 'Warning' or 'Error'."
	exit 1
	}

# Setting Array Variables used below to null.
[array]$Monitors                  = $null
[array]$EnabledMonitors           = $null
[array]$MonitorsWithAlertSettings = $null
[array]$MonitorsSetAlertSettings  = $null
[array]$FinalResults              = $null

# Importing the Operations Manager Microsoft.EnterpriseManagement.ManagementGroup Class
Import-Module "C:\Program Files\System Center 2012\Operations Manager\Setup\Microsoft.EnterpriseManagement.OperationsManager.dll"


# Connecting to the Management Server running the RMS Role and retrieving a list of all Management Packs.
$ManagementGroup = New-Object Microsoft.EnterpriseManagement.ManagementGroup($RMS)
$ManagementPacks = $ManagementGroup.GetManagementPacks()


# Retrieving a list of all existing Monitors and storing them in an array.
foreach ($ManagementPack in $ManagementPacks) {
	$ExistingMonitors = $ManagementPack.GetMonitors()
	[array]$Monitors += $ExistingMonitors
	}

# Sorting through the list of all Monitors and storing the Enabled Monitors in an array.
foreach ($Monitor in $Monitors) {
	if ($Monitor.Enabled -ne "false") {
		[array]$EnabledMonitors += $Monitor
		}
	}

# Sorting through the list of Enabled Monitors and retriving all existing Alert Settings and storing them in an array.
foreach ($EnabledMonitor in $EnabledMonitors) {
	if ($EnabledMonitor.AlertSettings -ne $null) {
		[array]$MonitorsWithAlertSettings += $EnabledMonitor
		}
	}

# Sorting through all Alert Settings and returning back those that have their AlertOnState setting equal to the $AlertOnState
# variable declared at the top of the script.
foreach ($Monitor in $MonitorsWithAlertSettings) {
	$AlertOnStateSettings = $Monitor.get_AlertSettings().AlertOnState
	if ($AlertOnStateSettings -eq $AlertOnState) {
		[array]$FinalResults += $Monitor.GetManagementPack().DisplayName + " - " + $Monitor.DisplayName + " - " + $AlertOnStateSettings
		}
	}


#Return Back Final Results
Write-Host "Management Pack Name - Monitor Name - AlertOnState Settings"
$FinalResults



