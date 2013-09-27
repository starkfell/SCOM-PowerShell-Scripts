#  --- [AddToMP-CustomPortMonitor_v1.0] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        09.22.2013
# Last Modified:    09.27.2013
#
# Description:      Code is in progress.....currently non-functional.
#
#
# Syntax:          ./AddToMP-CustomServiceMonitor_v1.0 <Management_Server> <Management_Pack_Display_Name> <Service_Name> <Service_Display_Name> <Check_Startup_Type_Value>
#
# Example:         ./AddToMP-CustomServiceMonitor_v1.0 SCOMMS01.fabrikam.local "Custom Service Monitors - Main MP" wuauserv "Windows Update" True

param($ManagementServer,$ManagementPackDisplayName,$ServiceName,$ServiceDisplayName,$CheckStartupType)

$ManagementServer           = "<Management_Server_Goes_Here>"
$ManagementPackDisplayName  = "Custom Service Monitors - Base OS"
$ServiceName                = "RemoteRegistry"
$ServiceDisplayName         = "Remote Registry"
$CheckStartupType           = "True"
$Port                       = "80"

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
			Write-Host "[$($ServiceDisplayName)] - Service Monitor already exists in [$($ManagementPackDisplayName)]. Script will now exit."
			exit 2;
		}
	}

	Write-Host "[$($ServiceDisplayName)] - Service Monitor was not found in [$($ManagementPackDisplayName)]. Script will continue."


	# Retrieving the Custom Class in the Management Pack.
	$CustomClasses = $MP.GetClasses()[0]


	# Getting Synthetic Transaction Library Reference
	$SyntheticLibrary = "Microsoft.SystemCenter.SyntheticTransactions.Library"
	$MPToAdd          = $MG.GetManagementPacks($SyntheticLibrary)[0]
	$MPAlias          = "MicrosoftSystemCenterSyntheticTransactionsLibrary"
	
	
	# Adding Synthetic Transaction Library to Management Pack
	$MPReference      = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($MPToAdd)
	$MP.References.Add($MPAlias,$MPReference)
	

	# Creating TCP Port Custom Classes - TCPPortCheckPerspective
	$TCPPortCheckCustomClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackClass($MP,("TCPPortCheck_"+$Port.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")
	$TCPPortCheckCustomClassBase         = $MG.EntityTypes.GetClasses("Name='Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckPerspective'")[0]
	$TCPPortCheckCustomClass.Base        = $TCPPortCheckCustomClassBase
	$TCPPortCheckCustomClass.Singleton   = $false
	$TCPPortCheckCustomClass.Hosted      = $true
	$TCPPortCheckCustomClass.DisplayName = "$($ManagementPackDisplayName), Registry Key - $($RegistryKey) - TCP Port Check"
	
	# Creating TCP Port Custom Classes - TCPPortCheckPerspectiveGroup
	$TCPPortCheckGroupCustomClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackClass($MP,("TCPPortCheck_"+$Port.ToString().Replace("$","_")+"_Group_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")
	$TCPPortCheckGroupCustomClassBase         = $MG.EntityTypes.GetClasses("Name='Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckPerspectiveGroup'")[0]
	$TCPPortCheckGroupCustomClass.Base        = $TCPPortCheckGroupCustomClassBase
	$TCPPortCheckGroupCustomClass.Singleton   = $true
	$TCPPortCheckGroupCustomClass.Hosted      = $false
	$TCPPortCheckGroupCustomClass.DisplayName = "$($ManagementPackDisplayName), Registry Key - $($RegistryKey) - TCP Port Check Group"
	
	# Creating TCP Port Custom Classes - TCPPortCheckWatcherComputersGroup
	$TCPPortCheckComputersGroupCustomClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackClass($MP,("TCPPortCheck_"+$Port.ToString().Replace("$","_")+"_WatcherComputersGroup_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")
	$TCPPortCheckComputersGroupCustomClassBase         = $MG.EntityTypes.GetClasses("Name='Microsoft.SystemCenter.ComputerGroup'")[0]
	$TCPPortCheckComputersGroupCustomClass.Base        = $TCPPortCheckComputersGroupCustomClassBase
	$TCPPortCheckComputersGroupCustomClass.Singleton   = $true
	$TCPPortCheckComputersGroupCustomClass.Hosted      = $false
	$TCPPortCheckComputersGroupCustomClass.DisplayName = "$($ManagementPackDisplayName), Registry Key - $($RegistryKey) - TCP Port Check Watcher Computers Group"
	
	# Creating new Relationship Type
	$TCPPortRelationshipClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationship($MP,("TCPPortCheck_"+$Port.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")+"_Group_Contains_"+$TCPPortCheckCustomClass),"Public")
	$TCPPortRelationshipClassCriteria     = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationshipCriteria("Name='System.Containment'")
	$TCPPortRelationshipClassBase         = $MG.EntityTypes.GetRelationshipClasses($TCPPortRelationshipClassCriteria)[0]
	$TCPPortRelationshipClass.Base        = $TCPPortRelationshipClassBase
	$TCPPortRelationshipSourceEndpoint    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationshipEndpoint($TCPPortCheckGroupCustomClass,"TCPPortCheckGroupCustomClass_Source")
	$TCPPortRelationshipTargetEndpoint    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationshipEndpoint($TCPPortCheckCustomClass,"TCPPortCheckCustomClass_Target")
	$TCPPortRelationshipClass.Source      = $TCPPortRelationshipSourceEndpoint
	$TCPPortRelationshipClass.Target      = $TCPPortRelationshipTargetEndpoint
	
	
	
	

	# Creating New Port Monitor
	$PortMonitorTypeQuery = "Name = 'Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckProbe'"
	$PortMonitorCriteria  = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorTypeCriteria($PortMonitorTypeQuery)
	$PortMonitorType      = $MG.GetUnitMonitorTypes($PortMonitorCriteria)[0]
	
	

	# Creating New Service Monitor
	$MonitorTypeQuery     = "Name = 'Microsoft.Windows.CheckNTServiceStateMonitorType'"
	$MonitorCriteria      = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorTypeCriteria($MonitorTypeQuery)
	$ServiceMonitorType   = $MG.GetUnitMonitorTypes($MonitorCriteria)[0]
	$Monitor              = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitor($MP,($ServiceName.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")


	# Setting new New Monitor Up as a Service Monitor and targeting the Hosts of the Group in the MP.
	$Monitor.set_DisplayName($ServiceDisplayName)
	$Monitor.set_Category("Custom")
	$Monitor.set_TypeID($ServiceMonitorType)
	$Monitor.set_Target($CustomClasses)


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
