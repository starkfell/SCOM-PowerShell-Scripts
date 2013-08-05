#  --- [Create-SCOMServiceMonitor] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        08.03.2013
# Last Modified:    08.04.2013
#
# Description:      This Script provides an automated method of creating Service Monitors in SCOM. The Script will
#                   be parameterized in the very near future. Because of the amount of resources that are used on when this script is ran, 
#                   it is probably best that you run it directly on a Management Server where the Operations Console is installed.
#                   Code from both links below was utilized within this script:
#
#		    http://msdn.microsoft.com/en-us/library/bb960506.aspx
#		    http://social.technet.microsoft.com/Forums/systemcenter/en-US/9967b3b9-669d-49d5-aeef-0f6e7f298e43/how-to-create-a-dependency-monitor-for-an-group-using-powershell-
#
#
# Changes:          08.04.2013 - [R. Irujo]
#                   - Code Cleanup and Documentation Added.
#
#
# Additional Notes: Mind the BACKTICKS throughout the Script! In particular, any XML changes that you may decide to add/remove/change
#                   will require use of them to escape special characters that are commonly used.
#
#
# Syntax:          ./Create-SCOMServiceMonitor <Service_Display_Name> <ServiceName> <CheckStartupType>
#
# Example:         ./Create-SCOMServiceMonitor "VMware Tools" "VMTools" "True"

Clear-Host

$ServiceDisplayName = "VMware Tools"
$ServiceName        = "VMTools"
$CheckStartupType   = "True"


# Import Operations Module if it isn't already imported.
If (!(Get-Module OperationsManager)) {
	Import-Module "D:\Program Files\System Center 2012\Operations Manager\Powershell\OperationsManager\OperationsManager.psd1"
	}
	

# Connect to SCOM Management Group.
$MG = Get-SCOMManagementGroup
$ServiceMonitorType   = $MG.GetUnitMonitorTypes() | Where-Object {$_.Name -eq "Microsoft.Windows.CheckNTServiceStateMonitorType"}
$MonitorClassCriteria = $MG.GetMonitoringClasses() | Where-Object {$_.DisplayName -eq "Windows Server 2008 R2 Full Operating System"}


# Retrieving SCOM Management Pack to work with.
$MP        = Get-SCOMManagementPack | Where-Object {$_.DisplayName -like "*Fourth*"}
$MPApublic = [Microsoft.EnterpriseManagement.Configuration.ManagementPackAccessibility]::Public


# Creating New Service Monitor
$Monitor = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitor($MP,($ServiceName+"_"+[Guid]::NewGuid().ToString().Replace("-","")),$MPApublic)


# Setting new New Monitor Up as a Service Monitor and targeting the Hosts of the Group in the MP.
$Monitor.set_DisplayName($ServiceDisplayName)
$Monitor.set_TypeID($ServiceMonitorType)
$Monitor.set_Target($MonitorClassCriteria)


# Configure Monitor Alert Settings
$Monitor.AlertSettings = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorAlertSettings
$Monitor.AlertSettings.set_AlertOnState("Error")
$Monitor.AlertSettings.set_AutoResolve($true)
$Monitor.AlertSettings.set_AlertPriority("Normal")
$Monitor.AlertSettings.set_AlertSeverity("Error")
$Monitor.AlertSettings.set_AlertParameter1("`$Target/Host/Property[Type=`"Windows1!Microsoft.Windows.Computer`"]/NetworkName$")
$Monitor.AlertSettings.AlertMessage


# Configure Alert Settings - Alert Message
$AlertMessage = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackStringResource($MP, "Service.Monitor.Alert.Message")
$AlertMessage.set_DisplayName("The $($ServiceDisplayName) Service has Stopped")
$AlertMessage.set_Description("The $($ServiceDisplayName) Service has Stopped on {0}")
$Monitor.AlertSettings.set_AlertMessage($AlertMessage)


# Configure Health States for the Monitor
$HealthyState = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorOperationalState($Monitor, "Success")
$ErrorState   = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorOperationalState($Monitor, "Error")
$HealthyState.set_HealthState("Success")
$HealthyState.set_MonitorTypeStateID("Running")
$ErrorState.set_HealthState("Error")
$ErrorState.set_MonitorTypeStateID("NotRunning")
$Monitor.OperationalStateCollection.Add($HealthyState)
$Monitor.OperationalStateCollection.Add($ErrorState)


# Specifying Service Monitoring Configuration
$MonitorConfig = "<ComputerName>`$Target/Host/Property[Type=`"Windows1!Microsoft.Windows.Computer`"]/NetworkName$</ComputerName>
                  <ServiceName>$($ServiceName)</ServiceName>
				  <CheckStartupType>$($CheckStartupType)</CheckStartupType>"

$Monitor.set_Configuration($MonitorConfig)


# Specify Parent Monitor by ID
$MonitorCriteria  = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorCriteria("Name='System.Health.AvailabilityState'")
$ParentMonitor    = $MG.GetMonitors($MonitorCriteria)[0]
$Monitor.ParentMonitorID = [Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackAggregateMonitor]]::op_implicit($ParentMonitor)


# Verify and Add Changes to the Management Pack. 
$MP.Verify()
$MP.AcceptChanges()

Write-Host "$($Monitor.DisplayName) - Service Monitor was successfully deployed to Management Pack - $($MP.DisplayName)"

