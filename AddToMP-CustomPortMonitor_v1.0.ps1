#  --- [AddToMP-CustomPortMonitor_v1.1] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        09.22.2013
# Last Modified:    09.29.2013
#
# Description:      Code is in progress.....currently non-functional.
#
#
# Syntax:          ./AddToMP-CustomServiceMonitor_v1.0 <Management_Server> <Management_Pack_Display_Name> <Service_Name> <Service_Display_Name> <Check_Startup_Type_Value>
#
# Example:         ./AddToMP-CustomServiceMonitor_v1.0 SCOMMS01.fabrikam.local "Custom Service Monitors - Main MP" wuauserv "Windows Update" True

param($ManagementServer,$ManagementPackDisplayName,$ServiceName,$ServiceDisplayName,$CheckStartupType)

$ManagementServer           = "SCOMMS223.scom.local"
#$ManagementPackDisplayName  = "Custom Service Monitors - Base OS"
#$ManagementPackDisplayName  = "Test Port Monitor - 80"
$ManagementPackDisplayName  = "Test Port Monitor - Sandbox"
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


	# Checking to see if Synthetic Transactions Library Reference already exists in Management Pack.
	$SyntheticLibrary                = "Microsoft.SystemCenter.SyntheticTransactions.Library"
	$CheckIfSyntheticReferenceExists = $MP.get_References().ContainsKey("MicrosoftSystemCenterSyntheticTransactionsLibrary")
	If ($CheckIfSyntheticReferenceExists -eq $true) {
		Write-Host "Synthetic Transactions Library already exists in [$($ManagementPackDisplayName)], Script will continue..."
		}
	Else {
		# Getting Synthetic Transaction Library Reference from Management Server.
		$MPToAdd_1          = $MG.GetManagementPacks($SyntheticLibrary)[0]
		$MPAlias_1          = "MicrosoftSystemCenterSyntheticTransactionsLibrary"
	
		# Adding Synthetic Transaction Library to Management Pack.
		$MPReference_1      = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($MPToAdd_1)
		$MP.References.Add($MPAlias_1,$MPReference_1)
		Write-Host "Synthetic Transactions Library successfully added to [$($ManagementPackDisplayName)]."
		}


	# Checking to see if Microsoft Windows Library Reference already exists in Management Pack.
	$WindowsLibrary                = "Microsoft.Windows.Library"
	$CheckIfWindowsReferenceExists = $MP.get_References().ContainsKey("Windows")
	If ($CheckIfWindowsReferenceExists -eq $true) {
		Write-Host "Microsoft Windows Library already exists in [$($ManagementPackDisplayName)], Script will continue..."
		}
	Else {
		# Getting Microsoft Windows Library Reference from Management Server.
		
		$MPToAdd_2          = $MG.GetManagementPacks($WindowsLibrary)[0]
		$MPAlias_2          = "Windows"
	
		# Adding Microsoft Windows Library to Management Pack.
		$MPReference_2      = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($MPToAdd_2)
		$MP.References.Add($MPAlias_2,$MPReference_2)
		Write-Host "Microsoft Windows Library successfully added to [$($ManagementPackDisplayName)]."
		}





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
	
	# Creating new Relationship Class Type
	$TCPPortRelationshipClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationship($MP,("TCPPortCheck_"+$Port.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")+"_Group_Contains_"+$TCPPortCheckCustomClass),"Public")
	$TCPPortRelationshipClassCriteria     = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationshipCriteria("Name='System.Containment'")
	$TCPPortRelationshipClassBase         = $MG.EntityTypes.GetRelationshipClasses($TCPPortRelationshipClassCriteria)[0]
	$TCPPortRelationshipClass.Base        = $TCPPortRelationshipClassBase
	$TCPPortRelationshipClass.DisplayName = "Group of Test Port Monitor - 81"
	$TCPPortRelationshipSource            = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationshipEndpoint($TCPPortRelationshipClass,"TCPPortCheckGroupCustomClass_Source")
	$TCPPortRelationshipTarget            = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRelationshipEndpoint($TCPPortRelationshipClass,"TCPPortCheckCustomClass_Target")	
	$TCPPortRelationshipSource.Type       = $TCPPortCheckGroupCustomClass
	$TCPPortRelationshipTarget.Type       = $TCPPortCheckCustomClass
	$TCPPortRelationshipClass.Source      = $TCPPortRelationshipSource
	$TCPPortRelationshipClass.Target      = $TCPPortRelationshipTarget

	
	
	
	# Creating a Module Composition Node Type with the ID of Probe.
	$TCPPortCheckProbeModuleCompositionNodeType        = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$TCPPortCheckProbeModuleCompositionNodeType.ID     = "Probe"
	
	# Creating a Module Composition Node Type with the ID of Scheduler.
	$TCPPortCheckSchedulerModuleCompositionNodeType    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$TCPPortCheckSchedulerModuleCompositionNodeType.ID = "Scheduler"	
	
	
	# Creating new Data Source Module Type
	$TCPPortCheckDataSourceModule                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModuleType($MP,($TCPPortCheckCustomClass.ToString()+"_TCPPortCheckDataSource"),"Public")
	$TCPPortCheckDataSourceModuleOutputTypeSourceMP  = $MG.GetManagementPacks($SyntheticLibrary)[0] 
	$TCPPortCheckDataSourceModuleOutputType          = $TCPPortCheckDataSourceModuleOutputTypeSourceMP.GetDataType("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckData")
	$TCPPortCheckDataSourceModule.set_OutputType([Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackDataType]]::op_implicit($TCPPortCheckDataSourceModuleOutputType))
	
	$TCPPortCheckDataSourceModuleTypeReference                = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($TCPPortCheckDataSourceModule,"Scheduler")
	$TCPPortCheckDataSourceModuleTypeReference.TypeID         = $MG.GetMonitoringModuleTypes("System.Scheduler")[0]
	$TCPPortCheckDataSourceModuleTypeReferenceConfiguration   = "<Scheduler><SimpleReccuringSchedule><Interval Unit=`"Seconds`">120</Interval></SimpleReccuringSchedule><ExcludeDates /></Scheduler>"
	$TCPPortCheckDataSourceModuleTypeReference.Configuration  = $TCPPortCheckDataSourceModuleTypeReferenceConfiguration
	
	$TCPPortCheckProbeActionModuleTypeReference               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($TCPPortCheckDataSourceModule,"Probe")
	$TCPPortCheckProbeActionModuleTypeReference.TypeID        = $MG.GetMonitoringModuleTypes("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckProbe")[0]
	$TCPPortCheckProbeActionModuleTypeReferenceConfiguration  = "<ServerName>SCOMDEVSRV</ServerName><Port>81</Port>"
	$TCPPortCheckProbeActionModuleTypeReference.Configuration = $TCPPortCheckProbeActionModuleTypeReferenceConfiguration
	
	
	$TCPPortCheckDataSourceModule.DataSourceCollection.Add($TCPPortCheckDataSourceModuleTypeReference)
	$TCPPortCheckDataSourceModule.ProbeActionCollection.Add($TCPPortCheckProbeActionModuleTypeReference)
	
	$TCPPortCheckDataSourceModule.Node               = $TCPPortCheckProbeModuleCompositionNodeType
	$TCPPortCheckDataSourceModule.Node.NodeCollection.Add($TCPPortCheckSchedulerModuleCompositionNodeType)
	
	
	
	#$TCPPortCheckDataSourceModule.Node               = $TCPPortCheckProbeModuleCompositionNodeType
	#$TCPPortCheckDataSourceModule.Node.NodeCollection.Add($TCPPortCheckSchedulerModuleCompositionNodeType)
	
	<## Creating Data Source Collection for Data Source Module
	$TCPPortCheckDataSourceCollection                = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModule($TCPPortCheckDataSourceModule,"Scheduler")
	$TCPPortCheckDataSourceCollection.TypeID         = $MG.GetMonitoringModuleTypes("System.Scheduler")[0]
	$TCPPortCheckDataSourceCollectionConfiguration   = "<Scheduler><SimpleReccuringSchedule><Interval Unit=`"Seconds`">120</Interval></SimpleReccuringSchedule><ExcludeDates /></Scheduler>"
	$TCPPortCheckDataSourceCollection.Configuration  = $TCPPortCheckDataSourceCollectionConfiguration
	
	
	# Creating Probe Action Collection for Data Source Module
    $TCPPortCheckProbeActionCollection               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackProbeActionModule($TCPPortCheckDataSourceModule,"Probe")
	$TCPPortCheckProbeActionCollection.TypeID        = $MG.GetMonitoringModuleTypes("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckProbe")[0]
	$TCPPortCheckProbeActionCollectionConfiguration  = "<ServerName>SCOMDEVSRV</ServerName><Port>81</Port>"
	$TCPPortCheckProbeActionCollection.Configuration = $TCPPortCheckProbeActionCollectionConfiguration
	

	$TCPPortCheckDataSourceModule.Node               = $TCPPortCheckProbeModuleCompositionNodeType
	$TCPPortCheckDataSourceModule.Node.NodeCollection.Add($TCPPortCheckSchedulerModuleCompositionNodeType)

	#>

	#$TCPPortCheckDataSourceModule.ProbeActionCollection.Add([Microsoft.EnterpriseManagement.Configuration.ManagementPackSubElementCollection``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference]]$TCPPortCheckProbeActionCollection)
	#$TCPPortCheckDataSourceModule.ProbeActionCollection.Add([Microsoft.EnterpriseManagement.Configuration.ManagementPackSubElementCollection``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference]]$TCPPortCheckProbeActionTypeReference)
	#$TCPPortCheckProbeActionTypeReference = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($TCPPortCheckDataSourceModule,"ProbeRef")
	#$TCPPortCheckDataSourceModule.set_OutputType([Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackDataType]]::op_implicit($TCPPortCheckDataSourceModuleOutputType))
	#$TCPPortCheckDataSourceModule.CreateNavigator()
	#$TCPPortCheckDataSourceModuleOutputTypeSourceMP  = $MG.GetManagementPacks($SyntheticLibrary)[0]  
	#$TCPPortCheckDataSourceModuleOutputType          = $TCPPortCheckDataSourceModuleOutputTypeSourceMP.GetDataType("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckData")
	#$TCPPortCheckDataSourceModule.set_OutputType([Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackDataType]]::op_implicit($TCPPortCheckDataSourceModuleOutputType))
	#$TCPPortCheckDataSourceModuleImplementation      = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataType(
	#$TCPPortCheckDataSourceModuleOutputType          = $MG.GetMonitoringModuleTypes("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckProbe")[0]
	

	<#
	# Creating New Port Monitor
	$PortMonitorTypeQuery = "Name = 'Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckProbe'"
	$PortMonitorCriteria  = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorTypeCriteria($PortMonitorTypeQuery)
	$PortMonitorType      = $MG.GetUnitMonitorTypes($PortMonitorCriteria)[0]
	#>
	


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
