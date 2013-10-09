#  --- [AddToMP-CustomPortMonitor_v1.1] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        09.22.2013
# Last Modified:    10.08.2013
#
# Description:      Code is in progress.....currently non-functional.
#
#
# Syntax:          ./AddToMP-CustomPortMonitor_v1.0 <Management_Server> <Management_Pack_Display_Name> <Service_Name> <Service_Display_Name> <Check_Startup_Type_Value>
#
# Example:         ./AddToMP-CustomPortMonitor_v1.0 SCOMMS01.fabrikam.local "Custom Service Monitors - Main MP" wuauserv "Windows Update" True

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
	
	# Creating new Data Source Module Type.
	$TCPPortCheckDataSourceModule                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModuleType($MP,($TCPPortCheckCustomClass.ToString()+"_TCPPortCheckDataSource"),"Public")
	$TCPPortCheckDataSourceModuleOutputTypeSourceMP  = $MG.GetManagementPacks($SyntheticLibrary)[0] 
	$TCPPortCheckDataSourceModuleOutputType          = $TCPPortCheckDataSourceModuleOutputTypeSourceMP.GetDataType("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckData")
	$TCPPortCheckDataSourceModule.set_OutputType([Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackDataType]]::op_implicit($TCPPortCheckDataSourceModuleOutputType))
	
	# Creating a Data Source Collection for the Data Source Module Type.
	$TCPPortCheckDataSourceModuleTypeReference                = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($TCPPortCheckDataSourceModule,"Scheduler")
	$TCPPortCheckDataSourceModuleTypeReference.TypeID         = $MG.GetMonitoringModuleTypes("System.Scheduler")[0]
	$TCPPortCheckDataSourceModuleTypeReferenceConfiguration   = "<Scheduler><SimpleReccuringSchedule><Interval Unit=`"Seconds`">120</Interval></SimpleReccuringSchedule><ExcludeDates /></Scheduler>"
	$TCPPortCheckDataSourceModuleTypeReference.Configuration  = $TCPPortCheckDataSourceModuleTypeReferenceConfiguration
	
	# Creating a Probe Action Collection for the Data Source Module Type.
	$TCPPortCheckProbeActionModuleTypeReference               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($TCPPortCheckDataSourceModule,"Probe")
	$TCPPortCheckProbeActionModuleTypeReference.TypeID        = $MG.GetMonitoringModuleTypes("Microsoft.SystemCenter.SyntheticTransactions.TCPPortCheckProbe")[0]
	$TCPPortCheckProbeActionModuleTypeReferenceConfiguration  = "<ServerName>SCOMDEVSRV</ServerName><Port>81</Port>"
	$TCPPortCheckProbeActionModuleTypeReference.Configuration = $TCPPortCheckProbeActionModuleTypeReferenceConfiguration
	
	# Adding the Data Source Collection & Probe Action Collection to the Data Source Module Type.
	$TCPPortCheckDataSourceModule.DataSourceCollection.Add($TCPPortCheckDataSourceModuleTypeReference)
	$TCPPortCheckDataSourceModule.ProbeActionCollection.Add($TCPPortCheckProbeActionModuleTypeReference)
	
	# Adding the 'Probe' Module Composition Node Type as a Node for the Data Source Module Type.
	$TCPPortCheckDataSourceModule.Node               = $TCPPortCheckProbeModuleCompositionNodeType
	
	# Adding the 'Scheduler' Module Composition Node Type as a Node Collection for the Data Source Module Type.
	$TCPPortCheckDataSourceModule.Node.NodeCollection.Add($TCPPortCheckSchedulerModuleCompositionNodeType)



	# ------------------------------ Creating New Unit Monitor Type [TimeOut] ------------------------------ #
	$UnitMonitorTypeTimeOut = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorType($MP,($TCPPortCheckCustomClass.ToString()+"_TimeOut"),"Public")
	
	# Creating Data Source for [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOutDataSource        = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeTimeOut,"DS1")
	$UnitMonitorTypeTimeOutDataSource.TypeID = $TCPPortCheckDataSourceModule
	
	# Adding Data Source to [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOut.DataSourceCollection.Add($UnitMonitorTypeTimeOutDataSource)
	
	# Creating Monitor Type States for [TimeOut] Unit Monitor Type.
	$TimeOut_MonitorTypeState_TimeOutFailure   = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeTimeOut,"TimeOutFailure")
	$TimeOut_MonitorTypeState_NoTimeOutFailure = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeTimeOut,"NoTimeOutFailure")

	# Adding Monitor Type States to [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOut.MonitorTypeStateCollection.Add($TimeOut_MonitorTypeState_TimeOutFailure)
	$UnitMonitorTypeTimeOut.MonitorTypeStateCollection.Add($TimeOut_MonitorTypeState_NoTimeOutFailure)
	
	# Creating Condition Detection - [TimeOutFailure] - for [TimeOut] Unit Monitor Type.
	$CD_TimeOutFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeTimeOut,"CDTimeOutFailure")
	$CD_TimeOutFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_TimeOutFailure.Configuration = "<Expression>
                						  <SimpleExpression>
                  							<ValueExpression>
                   							  <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							</ValueExpression>
                  							<Operator>Equal</Operator>
                  							<ValueExpression>
                    						  <Value Type=`"UnsignedInteger`">2147952460</Value>
                  							</ValueExpression>
                						  </SimpleExpression>
              							</Expression>"

	# Creating Condition Detection - [NoTimeOutFailure] - for [TimeOut] Unit Monitor Type.
	$CD_NoTimeOutFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeTimeOut,"CDNoTimeOutFailure")
	$CD_NoTimeOutFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_NoTimeOutFailure.Configuration = "<Expression>
                						    <SimpleExpression>
                  							  <ValueExpression>
                   							    <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							  </ValueExpression>
                  							  <Operator>NotEqual</Operator>
                  							  <ValueExpression>
                    						    <Value Type=`"UnsignedInteger`">2147952460</Value>
                  							  </ValueExpression>
                						    </SimpleExpression>
              							  </Expression>"

	# Adding Condition Detection - [TimeOutFailure] - to [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOut.ConditionDetectionCollection.Add($CD_TimeOutFailure)

	# Adding Condition Detection - [NoTimeOutFailure] - to [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOut.ConditionDetectionCollection.Add($CD_NoTimeOutFailure)

	# Creating a Module Composition Node Type for Regular Detection [TimeOut] Failure.
	$RD_TimeOutFailureModuleCompositionNodeType       = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_TimeOutFailureModuleCompositionNodeType.ID    = "CDTimeOutFailure"

	# Creating a Module Composition Node Type for Regular Detection [NoTimeOut] Failure.
	$RD_NoTimeOutFailureModuleCompositionNodeType     = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_NoTimeOutFailureModuleCompositionNodeType.ID  = "CDNoTimeOutFailure"

	# Creating a Module Composition Node Type for Data Source of the [TimeOut] Unit Monitor Type
	$RD_TimeOutDataSourceModuleCompositionNodeType    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_TimeOutDataSourceModuleCompositionNodeType.ID = "DS1"

	# Creating Regular Detection - [TimeOutFailure] - for [TimeOut] Unit Monitor Type.
	$RD_TimeOutFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_TimeOutFailure.MonitorTypeStateID = "TimeOutFailure"
	$RD_TimeOutFailure.Node               = $RD_TimeOutFailureModuleCompositionNodeType
	$RD_TimeOutFailure.Node.NodeCollection.Add($RD_TimeOutDataSourceModuleCompositionNodeType)

	# Creating Regular Detection - [NoTimeOutFailure] - for [TimeOut] Unit Monitor Type.
	$RD_NoTimeOutFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_NoTimeOutFailure.MonitorTypeStateID = "NoTimeOutFailure"
	$RD_NoTimeOutFailure.Node               = $RD_NoTimeOutFailureModuleCompositionNodeType
	$RD_NoTimeOutFailure.Node.NodeCollection.Add($RD_TimeOutDataSourceModuleCompositionNodeType)

	# Adding Regular Detection - [TimeOutFailure] - to [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOut.RegularDetectionCollection.Add($RD_TimeOutFailure)
	
	# Adding Regular Detection - [NoTimeOutFailure] - to [TimeOut] Unit Monitor Type.
	$UnitMonitorTypeTimeOut.RegularDetectionCollection.Add($RD_NoTimeOutFailure)



	# ------------------------------ Creating New Unit Monitor Type [ConnectionRefused] ------------------------------ #
	$UnitMonitorTypeConnectionRefused = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorType($MP,($TCPPortCheckCustomClass.ToString()+"_ConnectionRefused"),"Public")
	
	# Creating Data Source for [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefusedDataSource        = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeConnectionRefused,"DS1")
	$UnitMonitorTypeConnectionRefusedDataSource.TypeID = $TCPPortCheckDataSourceModule
	
	# Adding Data Source to [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefused.DataSourceCollection.Add($UnitMonitorTypeConnectionRefusedDataSource)
	
	# Creating Monitor Type States for [ConnectionRefused] Unit Monitor Type.
	$ConnectionRefused_MonitorTypeState_ConnectionRefusedFailure   = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeConnectionRefused,"ConnectionRefusedFailure")
	$ConnectionRefused_MonitorTypeState_NoConnectionRefusedFailure = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeConnectionRefused,"NoConnectionRefusedFailure")

	# Adding Monitor Type States to [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefused.MonitorTypeStateCollection.Add($ConnectionRefused_MonitorTypeState_ConnectionRefusedFailure)
	$UnitMonitorTypeConnectionRefused.MonitorTypeStateCollection.Add($ConnectionRefused_MonitorTypeState_NoConnectionRefusedFailure)
	
	# Creating Condition Detection - [ConnectionRefusedFailure] - for [ConnectionRefused] Unit Monitor Type.
	$CD_ConnectionRefusedFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeConnectionRefused,"CDConnectionRefusedFailure")
	$CD_ConnectionRefusedFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_ConnectionRefusedFailure.Configuration = "<Expression>
                						  <SimpleExpression>
                  							<ValueExpression>
                   							  <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							</ValueExpression>
                  							<Operator>Equal</Operator>
                  							<ValueExpression>
                    						  <Value Type=`"UnsignedInteger`">2147952461</Value>
                  							</ValueExpression>
                						  </SimpleExpression>
              							</Expression>"

	# Creating Condition Detection - [NoConnectionRefusedFailure] - for [ConnectionRefused] Unit Monitor Type.
	$CD_NoConnectionRefusedFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeConnectionRefused,"CDNoConnectionRefusedFailure")
	$CD_NoConnectionRefusedFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_NoConnectionRefusedFailure.Configuration = "<Expression>
                						    <SimpleExpression>
                  							  <ValueExpression>
                   							    <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							  </ValueExpression>
                  							  <Operator>NotEqual</Operator>
                  							  <ValueExpression>
                    						    <Value Type=`"UnsignedInteger`">2147952461</Value>
                  							  </ValueExpression>
                						    </SimpleExpression>
              							  </Expression>"

	# Adding Condition Detection - [ConnectionRefusedFailure] - to [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefused.ConditionDetectionCollection.Add($CD_ConnectionRefusedFailure)

	# Adding Condition Detection - [NoConnectionRefusedFailure] - to [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefused.ConditionDetectionCollection.Add($CD_NoConnectionRefusedFailure)

	# Creating a Module Composition Node Type for Regular Detection [ConnectionRefused] Failure.
	$RD_ConnectionRefusedFailureModuleCompositionNodeType       = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_ConnectionRefusedFailureModuleCompositionNodeType.ID    = "CDConnectionRefusedFailure"

	# Creating a Module Composition Node Type for Regular Detection [NoConnectionRefused] Failure.
	$RD_NoConnectionRefusedFailureModuleCompositionNodeType     = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_NoConnectionRefusedFailureModuleCompositionNodeType.ID  = "CDNoConnectionRefusedFailure"

	# Creating a Module Composition Node Type for Data Source of the [ConnectionRefused] Unit Monitor Type
	$RD_ConnectionRefusedDataSourceModuleCompositionNodeType    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_ConnectionRefusedDataSourceModuleCompositionNodeType.ID = "DS1"

	# Creating Regular Detection - [ConnectionRefusedFailure] - for [ConnectionRefused] Unit Monitor Type.
	$RD_ConnectionRefusedFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_ConnectionRefusedFailure.MonitorTypeStateID = "ConnectionRefusedFailure"
	$RD_ConnectionRefusedFailure.Node               = $RD_ConnectionRefusedFailureModuleCompositionNodeType
	$RD_ConnectionRefusedFailure.Node.NodeCollection.Add($RD_ConnectionRefusedDataSourceModuleCompositionNodeType)

	# Creating Regular Detection - [NoConnectionRefusedFailure] - for [ConnectionRefused] Unit Monitor Type.
	$RD_NoConnectionRefusedFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_NoConnectionRefusedFailure.MonitorTypeStateID = "NoConnectionRefusedFailure"
	$RD_NoConnectionRefusedFailure.Node               = $RD_NoConnectionRefusedFailureModuleCompositionNodeType
	$RD_NoConnectionRefusedFailure.Node.NodeCollection.Add($RD_ConnectionRefusedDataSourceModuleCompositionNodeType)

	# Adding Regular Detection - [ConnectionRefusedFailure] - to [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefused.RegularDetectionCollection.Add($RD_ConnectionRefusedFailure)
	
	# Adding Regular Detection - [NoConnectionRefusedFailure] - to [ConnectionRefused] Unit Monitor Type.
	$UnitMonitorTypeConnectionRefused.RegularDetectionCollection.Add($RD_NoConnectionRefusedFailure)



	# ------------------------------ Creating New Unit Monitor Type [DNSResolution] ------------------------------ #
	$UnitMonitorTypeDNSResolution = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorType($MP,($TCPPortCheckCustomClass.ToString()+"_DNSResolution"),"Public")
	
	# Creating Data Source for [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolutionDataSource        = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeDNSResolution,"DS1")
	$UnitMonitorTypeDNSResolutionDataSource.TypeID = $TCPPortCheckDataSourceModule
	
	# Adding Data Source to [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolution.DataSourceCollection.Add($UnitMonitorTypeDNSResolutionDataSource)
	
	# Creating Monitor Type States for [DNSResolution] Unit Monitor Type.
	$DNSResolution_MonitorTypeState_DNSResolutionFailure   = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeDNSResolution,"DNSResolutionFailure")
	$DNSResolution_MonitorTypeState_NoDNSResolutionFailure = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeDNSResolution,"NoDNSResolutionFailure")

	# Adding Monitor Type States to [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolution.MonitorTypeStateCollection.Add($DNSResolution_MonitorTypeState_DNSResolutionFailure)
	$UnitMonitorTypeDNSResolution.MonitorTypeStateCollection.Add($DNSResolution_MonitorTypeState_NoDNSResolutionFailure)
	
	# Creating Condition Detection - [DNSResolutionFailure] - for [DNSResolution] Unit Monitor Type.
	$CD_DNSResolutionFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeDNSResolution,"CDDNSResolutionFailure")
	$CD_DNSResolutionFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_DNSResolutionFailure.Configuration = "<Expression>
                						  <SimpleExpression>
                  							<ValueExpression>
                   							  <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							</ValueExpression>
                  							<Operator>Equal</Operator>
                  							<ValueExpression>
                    						  <Value Type=`"UnsignedInteger`">2147953401</Value>
                  							</ValueExpression>
                						  </SimpleExpression>
              							</Expression>"

	# Creating Condition Detection - [NoDNSResolutionFailure] - for [DNSResolution] Unit Monitor Type.
	$CD_NoDNSResolutionFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeDNSResolution,"CDNoDNSResolutionFailure")
	$CD_NoDNSResolutionFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_NoDNSResolutionFailure.Configuration = "<Expression>
                						    <SimpleExpression>
                  							  <ValueExpression>
                   							    <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							  </ValueExpression>
                  							  <Operator>NotEqual</Operator>
                  							  <ValueExpression>
                    						    <Value Type=`"UnsignedInteger`">2147953401</Value>
                  							  </ValueExpression>
                						    </SimpleExpression>
              							  </Expression>"

	# Adding Condition Detection - [DNSResolutionFailure] - to [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolution.ConditionDetectionCollection.Add($CD_DNSResolutionFailure)

	# Adding Condition Detection - [NoDNSResolutionFailure] - to [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolution.ConditionDetectionCollection.Add($CD_NoDNSResolutionFailure)

	# Creating a Module Composition Node Type for Regular Detection [DNSResolution] Failure.
	$RD_DNSResolutionFailureModuleCompositionNodeType       = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_DNSResolutionFailureModuleCompositionNodeType.ID    = "CDDNSResolutionFailure"

	# Creating a Module Composition Node Type for Regular Detection [NoDNSResolution] Failure.
	$RD_NoDNSResolutionFailureModuleCompositionNodeType     = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_NoDNSResolutionFailureModuleCompositionNodeType.ID  = "CDNoDNSResolutionFailure"

	# Creating a Module Composition Node Type for Data Source of the [DNSResolution] Unit Monitor Type
	$RD_DNSResolutionDataSourceModuleCompositionNodeType    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_DNSResolutionDataSourceModuleCompositionNodeType.ID = "DS1"

	# Creating Regular Detection - [DNSResolutionFailure] - for [DNSResolution] Unit Monitor Type.
	$RD_DNSResolutionFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_DNSResolutionFailure.MonitorTypeStateID = "DNSResolutionFailure"
	$RD_DNSResolutionFailure.Node               = $RD_DNSResolutionFailureModuleCompositionNodeType
	$RD_DNSResolutionFailure.Node.NodeCollection.Add($RD_DNSResolutionDataSourceModuleCompositionNodeType)

	# Creating Regular Detection - [NoDNSResolutionFailure] - for [DNSResolution] Unit Monitor Type.
	$RD_NoDNSResolutionFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_NoDNSResolutionFailure.MonitorTypeStateID = "NoDNSResolutionFailure"
	$RD_NoDNSResolutionFailure.Node               = $RD_NoDNSResolutionFailureModuleCompositionNodeType
	$RD_NoDNSResolutionFailure.Node.NodeCollection.Add($RD_DNSResolutionDataSourceModuleCompositionNodeType)

	# Adding Regular Detection - [DNSResolutionFailure] - to [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolution.RegularDetectionCollection.Add($RD_DNSResolutionFailure)
	
	# Adding Regular Detection - [NoDNSResolutionFailure] - to [DNSResolution] Unit Monitor Type.
	$UnitMonitorTypeDNSResolution.RegularDetectionCollection.Add($RD_NoDNSResolutionFailure)



	# ------------------------------ Creating New Unit Monitor Type [HostUnreachable] ------------------------------ #
	$UnitMonitorTypeHostUnreachable = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorType($MP,($TCPPortCheckCustomClass.ToString()+"_HostUnreachable"),"Public")
	
	# Creating Data Source for [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachableDataSource        = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeHostUnreachable,"DS1")
	$UnitMonitorTypeHostUnreachableDataSource.TypeID = $TCPPortCheckDataSourceModule
	
	# Adding Data Source to [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachable.DataSourceCollection.Add($UnitMonitorTypeHostUnreachableDataSource)
	
	# Creating Monitor Type States for [HostUnreachable] Unit Monitor Type.
	$HostUnreachable_MonitorTypeState_HostUnreachableFailure   = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeHostUnreachable,"HostUnreachableFailure")
	$HostUnreachable_MonitorTypeState_NoHostUnreachableFailure = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeState($UnitMonitorTypeHostUnreachable,"NoHostUnreachableFailure")

	# Adding Monitor Type States to [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachable.MonitorTypeStateCollection.Add($HostUnreachable_MonitorTypeState_HostUnreachableFailure)
	$UnitMonitorTypeHostUnreachable.MonitorTypeStateCollection.Add($HostUnreachable_MonitorTypeState_NoHostUnreachableFailure)
	
	# Creating Condition Detection - [HostUnreachableFailure] - for [HostUnreachable] Unit Monitor Type.
	$CD_HostUnreachableFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeHostUnreachable,"CDHostUnreachableFailure")
	$CD_HostUnreachableFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_HostUnreachableFailure.Configuration = "<Expression>
                						  <SimpleExpression>
                  							<ValueExpression>
                   							  <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							</ValueExpression>
                  							<Operator>Equal</Operator>
                  							<ValueExpression>
                    						  <Value Type=`"UnsignedInteger`">2147952465</Value>
                  							</ValueExpression>
                						  </SimpleExpression>
              							</Expression>"

	# Creating Condition Detection - [NoHostUnreachableFailure] - for [HostUnreachable] Unit Monitor Type.
	$CD_NoHostUnreachableFailure               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleTypeReference($UnitMonitorTypeHostUnreachable,"CDNoHostUnreachableFailure")
	$CD_NoHostUnreachableFailure.TypeID        = $MG.GetMonitoringModuleTypes("System.ExpressionFilter")[0]
	$CD_NoHostUnreachableFailure.Configuration = "<Expression>
                						    <SimpleExpression>
                  							  <ValueExpression>
                   							    <XPathQuery Type=`"UnsignedInteger`">StatusCode</XPathQuery>
                 							  </ValueExpression>
                  							  <Operator>NotEqual</Operator>
                  							  <ValueExpression>
                    						    <Value Type=`"UnsignedInteger`">2147952465</Value>
                  							  </ValueExpression>
                						    </SimpleExpression>
              							  </Expression>"

	# Adding Condition Detection - [HostUnreachableFailure] - to [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachable.ConditionDetectionCollection.Add($CD_HostUnreachableFailure)

	# Adding Condition Detection - [NoHostUnreachableFailure] - to [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachable.ConditionDetectionCollection.Add($CD_NoHostUnreachableFailure)

	# Creating a Module Composition Node Type for Regular Detection [HostUnreachable] Failure.
	$RD_HostUnreachableFailureModuleCompositionNodeType       = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_HostUnreachableFailureModuleCompositionNodeType.ID    = "CDHostUnreachableFailure"

	# Creating a Module Composition Node Type for Regular Detection [NoHostUnreachable] Failure.
	$RD_NoHostUnreachableFailureModuleCompositionNodeType     = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_NoHostUnreachableFailureModuleCompositionNodeType.ID  = "CDNoHostUnreachableFailure"

	# Creating a Module Composition Node Type for Data Source of the [HostUnreachable] Unit Monitor Type
	$RD_HostUnreachableDataSourceModuleCompositionNodeType    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackModuleCompositionNodeType
	$RD_HostUnreachableDataSourceModuleCompositionNodeType.ID = "DS1"

	# Creating Regular Detection - [HostUnreachableFailure] - for [HostUnreachable] Unit Monitor Type.
	$RD_HostUnreachableFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_HostUnreachableFailure.MonitorTypeStateID = "HostUnreachableFailure"
	$RD_HostUnreachableFailure.Node               = $RD_HostUnreachableFailureModuleCompositionNodeType
	$RD_HostUnreachableFailure.Node.NodeCollection.Add($RD_HostUnreachableDataSourceModuleCompositionNodeType)

	# Creating Regular Detection - [NoHostUnreachableFailure] - for [HostUnreachable] Unit Monitor Type.
	$RD_NoHostUnreachableFailure                    = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorTypeDetection
	$RD_NoHostUnreachableFailure.MonitorTypeStateID = "NoHostUnreachableFailure"
	$RD_NoHostUnreachableFailure.Node               = $RD_NoHostUnreachableFailureModuleCompositionNodeType
	$RD_NoHostUnreachableFailure.Node.NodeCollection.Add($RD_HostUnreachableDataSourceModuleCompositionNodeType)

	# Adding Regular Detection - [HostUnreachableFailure] - to [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachable.RegularDetectionCollection.Add($RD_HostUnreachableFailure)
	
	# Adding Regular Detection - [NoHostUnreachableFailure] - to [HostUnreachable] Unit Monitor Type.
	$UnitMonitorTypeHostUnreachable.RegularDetectionCollection.Add($RD_NoHostUnreachableFailure)








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
