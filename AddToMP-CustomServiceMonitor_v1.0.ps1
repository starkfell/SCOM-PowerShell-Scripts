#  --- [AddToMP-CustomServiceMonitor_v1.0] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        09.02.2013
# Last Modified:    09.05.2013
#
# Description:      This Script provides an automated method of adding Custom Service Monitors in SCOM to an existing
#                   unsealed Management Pack.
#
#
# Changes:          09.02.2013 - [R. Irujo]
#                   - Modified the GetUnitMonitorTypes Query when creating a new Service Monitor to use the
#                     ManagementPackUnitMonitorTypeCritiera with a String Query to improve the performance 
#                     of the script. This change will be applied to earlier related scripts.
#
#                   09.03.2013 - [R. Irujo]
#                   - Changed the AlertMessage variable to generate a unique GUID for itself while being declared. This was necessary
#                     to ensure that any additional monitors added later on we're not forced to use the same Alert Message settings.
#                   - Additional Notes added into Script.
#                   - Cleaned up MP Query section to no longer require a ForEach loop to parse the results for the Custom Class.
#
#                   09.05.2013 - [R. Irujo]
#                   - Added a check to see if the Service Monitor to be added already exists in the Management Pack.
#                   - Removed Try-Catch Block from section that determines if the Management Pack already exists.
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


	Write-Host "Management Server:                    $($ManagementServer)"            
	Write-Host "Management Pack Display Name:         $($ManagementPackDisplayName)" 
	Write-Host "Service Name:                         $($ServiceName)"                 
	Write-Host "Service Display Name:                 $($ServiceDisplayName)"         
	Write-Host "Check Startup Type [True or False]:   $($CheckStartupType)`n"          

	
	Write-Host "Connecting to the SCOM Management Group"
	$MG = New-Object Microsoft.EnterpriseManagement.ManagementGroup($ManagementServer)


	# Determining if the Management Pack exists based upon its Display Name using a String Query.
	Write-Host "Determining if Management Pack - [$($ManagementPackDisplayName)] already exists."
	
	$MPQuery            = "DisplayName = '$($ManagementPackDisplayName)'"
	$MPCriteria         = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria($MPQuery)
	$MP                 = $MG.GetManagementPacks($MPCriteria)[0]
	
	If ($MP.Count -eq "0") {
		Write-Host "Management Pack - [$($ManagementPackDisplayName)] was NOT found in SCOM. Script will now exit."
		exit 2;
	}

	Write-Host "Management Pack - [$($ManagementPackDisplayName)] was found in SCOM. Script will continue."


	# Determining if the Service Monitor already exists in the Management Pack based upon its Name.
    	$ServiceMonitorCheck = $MP.GetMonitors()
	
	Foreach ($Item in $ServiceMonitorCheck) {
		If ($Item.DisplayName -eq $ServiceDisplayName) {
			Write-Host "[$($ServiceDisplayName)] Service already exists in [$($ManagementPackDisplayName)]. Script will not exit"
			exit 2;
		}
	}

	Write-Host "[$($ServiceDisplayName)] Service was not found in [$($ManagementPackDisplayName)]. Script will continue."


	# Retrieving the Custom Class in the Management Pack.
	$CustomClass = $MP.GetClasses()[0]


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
	$AlertMessage = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackStringResource($MP, ("CustomServiceMonitorAlertMessage_"+$ServiceName.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")))
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


	# Applying changes to the Management Pack in the SCOM Database.	
	try {
		Write-Host "Attempting to Add [$($Monitor.DisplayName)] - Service Monitor to Management Pack - [$($MP.DisplayName)]"
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

Write-Host "Deployment of Custom Service Monitor for [$($ServiceDisplayName)] to Management Pack - [$($ManagementPackDisplayName)] was Successful!"
