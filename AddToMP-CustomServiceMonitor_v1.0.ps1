#  --- [AddToMP-CustomServiceMonitor_v1.0] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        09.02.2013
# Last Modified:    09.02.2013
#
# Description:      This Script provides an automated method of adding Custom Service Monitors in SCOM to an existing
#                   unsealed Management Pack.
#
#
# Changes:          09.02.2013 - [R. Irujo]
#                   - Modified the GetUnitMonitorTypes Query when creating a new Service Monitor to use the 
#                     ManagementPackUnitMonitorTypeCriteria with a String Query to improve the performance
#                     of the script. This change will be applied to earlier related scripts.
#
#
# Additional Notes: Mind the BACKTICKS throughout the Script! In particular, any XML changes that you may decide to add/remove/change
#                   will require use of them to escape special characters that are commonly used.
#
#
# Syntax:          ./AddToMP-CustomServiceMonitor_v1.0 <Management_Server> <Management_Pack_Display_Name> <Service_Name> <Service_Display_Name> <Check_Startup_Type_Value>
#
# Example:         ./AddToMP-CustomServiceMonitor_v1.0 SCOMMS01.fabrikam.local "Custom Service Monitors - Main MP" wuauserv "Windows Update" True

param($ManagementServer,$ManagementPackDisplayName,$ServiceName,$ServiceDisplayName,$CheckStartupType)

# [---START---] Try-Catch Wrapper for Entire Script.
try {

	Clear-Host

	# Importing SCOM SDK DLL Files.
	Import-Module "C:\Program Files\System Center 2012\Operations Manager\Console\SDK Binaries\Microsoft.EnterpriseManagement.Core.dll"
	Import-Module "C:\Program Files\System Center 2012\Operations Manager\Console\SDK Binaries\Microsoft.EnterpriseManagement.OperationsManager.dll"
	Import-Module "C:\Program Files\System Center 2012\Operations Manager\Console\SDK Binaries\Microsoft.EnterpriseManagement.Runtime.dll"


	# Checking Parameter Values.
	if (!$ManagementServer) {
		Write-Host "A Management Server Name must be provided, i.e. - SCOMMS01.fabrikam.local."
		exit 2;
		}

	if (!$ManagementPackDisplayName) {
		Write-Host "A Management Pack Display Name must be provided, i.e. - Custom Service Monitor MP01."
		exit 2;
		}

	if (!$ServiceName) {
		Write-Host "The Name of the Service you want to Monitor must be provided, i.e. - wuauserv."
		exit 2;
		}

	if (!$ServiceDisplayName) {
		Write-Host "The Display Name of the Service you want to Monitor must be provided, i.e. - Windows Update."
		exit 2;
		}		
		
	if (!$CheckStartupType) {
		Write-Host "A Check Startup Type Value for the Service Monitor must be provided, i.e. 'True' or 'False'."
		exit 2;
		}		


	Write-Host "ManagementServer: "          $ManagementServer
	Write-Host "ManagementPackDisplayName: " $ManagementPackDisplayName


	Write-Host "Connecting to the SCOM Management Group"
	$MG = New-Object Microsoft.EnterpriseManagement.ManagementGroup($ManagementServer)

	# Making sure that the Management Pack exists in SCOM based upon its Display Name.
	Write-Host "Determining if Management Pack - [$($ManagementPackDisplayName)] already exists"
	try {
		[string]$MPQuery    = "DisplayName = '$($ManagementPackDisplayName)'"
		$MPCriteria         = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria($MPQuery)
		$FindManagementPack = $MG.GetManagementPacks($MPCriteria)
		ForEach ($Item in $FindManagementPack) {
			$CustomClass      += $Item.GetClasses() | Where-Object {$_.DisplayName -like "*Custom*"}
			$ManagementPackID += $Item.Name
			}
			If ($FindManagementPack.ToString().Length -eq "0") {
			Write-Host "Management Pack - [$($ManagementPackDisplayName)] was NOT found in SCOM. Script will now exit."
			exit 2;
			}
		}
	catch {
			[System.Management.Automation.MethodInvocationException] | Out-Null
		}
			
	Write-Host "Management Pack - [$($ManagementPackDisplayName)] was found in SCOM. Script will continue."
	
	Write-Host "Retrieving the ManagementPack's BaseType [ManagementPackStore] to use to add the Monitor too."
	$MP = $MG.GetManagementPacks("$($ManagementPackID)")[0]
	
	
	# Creating New Service Monitor
	$MonitorTypeQuery     = "Name = 'Microsoft.Windows.CheckNTServiceStateMonitorType'"
	$MonitorCriteria      = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorTypeCriteria($MonitorTypeQuery)
	$ServiceMonitorType   = $MG.GetUnitMonitorTypes($MonitorCriteria)[0]
	$Monitor              = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitor($MP,($ServiceName.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")


	# Setting new New Monitor Up as a Service Monitor and targeting the Hosts of the Group in the MP.
	$Monitor.set_DisplayName($ServiceDisplayName)
	$Monitor.set_Category("Custom")
	$Monitor.set_TypeID($ServiceMonitorType)
	$Monitor.set_Target($CustomClass)


	# Configure Monitor Alert Settings
	$Monitor.AlertSettings = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorAlertSettings
	$Monitor.AlertSettings.set_AlertOnState("Error")
	$Monitor.AlertSettings.set_AutoResolve($true)
	$Monitor.AlertSettings.set_AlertPriority("Normal")
	$Monitor.AlertSettings.set_AlertSeverity("Error")
	$Monitor.AlertSettings.set_AlertParameter1("`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$")
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
	$MonitorConfig = "<ComputerName>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$</ComputerName>
	                  <ServiceName>$($ServiceName)</ServiceName>
					  <CheckStartupType>$($CheckStartupType)</CheckStartupType>"

	$Monitor.set_Configuration($MonitorConfig)


	# Specify Parent Monitor by ID
	$MonitorCriteria  = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorCriteria("Name='System.Health.AvailabilityState'")
	$ParentMonitor    = $MG.GetMonitors($MonitorCriteria)[0]
	$Monitor.ParentMonitorID = [Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackAggregateMonitor]]::op_implicit($ParentMonitor)


	Write-Host "$($Monitor.DisplayName) - Service Monitor was successfully deployed to Management Pack - $($MP.DisplayName)"


	# Applying changes to the Management Pack in the SCOM Database.	
	try {
		$MP.AcceptChanges()
		}
	catch [System.Exception]
		{
			echo $_.Exception
			exit 2
		}

# [---END---] Try-Catch Wrapper for Entire Script.
	}
catch [System.Exception]
	{
			echo $_.Exception
			exit 2
	}

Write-Host "Deployment of Custom Service Monitor for [$($ServiceDisplayName)] to Management Pack - [$($ManagementPackDisplayName)] is Complete!"