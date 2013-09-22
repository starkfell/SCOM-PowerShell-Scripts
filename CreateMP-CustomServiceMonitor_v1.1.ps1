#  --- [CreateMP-CustomServiceMonitor_v1.1] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        08.18.2013
# Last Modified:    09.22.2013
#
# Description:      This Script provides an automated method of creating Service Monitors in SCOM that are discovered
#                   by using Filtered Registry Key Discoveries.
#
#
# Changes:          08.20.2013 - [R. Irujo]
#                   - Parameterized Script and added logic to verify that Parameters are provided.
#                   - Added function to replace all '$' with '_' for the Service Name in the $CustomClass and $Monitor variables to
#                     support custom SQL Instances.
#	            08.21.2013 - [R. Irujo]
#		    - Removed Importing of the PowerShell OperationsManager Module and instead import the SDK DLL Files.
#		    - Replaced most of the Where-Object filters with .NET Function calls to speed up the Script.
#                   08.22.2013 - [R. Irujo]
#                   - Added Check to Script to see if the Management Pack ID Provided already exists in SCOM.
#                   08.23.2013 - [R. Irujo]
#                   - Added Try-Catch Wrapper around entire Script to display better troubleshooting data when Errors occur.
#                   09.03.2013 - [R. Irujo]
#                   - Changed the AlertMessage variable to generate a unique GUID for itself while being declared. This was necessary
#                     to ensure that any additional monitors added later on we're not forced to use the same Alert Message settings.
#                   - Modified the GetUnitMonitorTypes Query when creating a new Service Monitor to use the ManagementPackUnitMonitorTypeCritiera 
#                     with a String Query to improve the performance of the script.
#                   09.22.2013 - [R. Irujo]
#                   - Cleaned up previously commented out Code.
#                   - Output results have been cleaned up to include all relevant items in Brackets.
#                   - Cleaned up Try-Catch Block during Management Pack ID check.
#
#
#
# Additional Notes: Mind the BACKTICKS throughout the Script! In particular, any XML changes that you may decide to add/remove/change
#                   will require use of them to escape special characters that are commonly used.
#
#
# Syntax:          ./CreateMP-CustomServiceMonitor_v1.1 <Management_Pack_ID> <Management_Pack_Name> <Management_Pack_Display_Name> <Service_Name> <Service_Display_Name> <Check_Startup_Type_Value> <Registry_Key>
#
# Example:         ./CreateMP-CustomServiceMonitor_v1.1 SCOMMS01.fabrikam.local custom.service.monitor.mp01 custom.service.monitor.mp01 "Windows Update Service Monitor" wuauserv "Windows Update" True CSMWindowsUpdate

param($ManagementServer,$ManagementPackID,$ManagementPackName,$ManagementPackDisplayName,$ServiceName,$ServiceDisplayName,$CheckStartupType,$RegistryKey)

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

	if (!$ManagementPackID) {
		Write-Host "A Management Pack ID must be provided, i.e. - custom.service.monitor.mp01. The Management Pack ID can be the same as the Management Pack Name."
		exit 2;
		}

	if (!$ManagementPackName) {
		Write-Host "A Management Pack Name must be provided, i.e. - custom.service.monitor.mp01. The Management Pack Name can be the same as the Management Pack ID."
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
		
	if (!$RegistryKey) {
		Write-Host "A Registry Key for the Discovery must be provided, i.e. - CustomServiceMonitorWindowsUpdate."
		exit 2;
		}		
			

	Write-Host "ManagementServer: "          $ManagementServer
	Write-Host "ManagementPackID: "          $ManagementPackID
	Write-Host "ManagementPackName: "        $ManagementPackName
	Write-Host "ManagementPackDisplayName: " $ManagementPackDisplayName


	Write-Host "Connecting to the SCOM Management Group"
	$MG = New-Object Microsoft.EnterpriseManagement.ManagementGroup($ManagementServer)

	# Making sure that the Management Pack ID provided doesn't already exist in SCOM.
	Write-Host "Determining if Management Pack ID [$($ManagementPackID)] already exists"
	try {
		$CheckManagementPackName = $MG.GetManagementPacks($ManagementPackID)[0]
		If ($CheckManagementPackName.ToString().Length -gt "0") {
			Write-Host "Management Pack ID [$($ManagementPackID)] was found in SCOM. Script will now exit."
			exit 2;
			}
		}
	catch [System.Management.Automation.MethodInvocationException]
		{
			Write-Host "Management Pack ID [$($ManagementPackID)] was not found in SCOM. Script will continue."
		}


	# Starting the Process of Creating a New Management Pack.
	Write-Host "Creating new [Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore] object"
	$MPStore = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore

	Write-Host "Creating new [Microsoft.EnterpriseManagement.Configuration.ManagementPack] object"
	$MP = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPack($ManagementPackID, $ManagementPackName, (New-Object Version(1, 0, 0)), $MPStore)

	Write-Host "Importing New Management Pack"
	$MG.ImportManagementPack($MP)

	Write-Host "Retrieving Newly Created Management Pack"
	$MP = $MG.GetManagementPacks($ManagementPackID)[0]
		
	Write-Host "Setting Management Pack Display Name."
	$MP.DisplayName = $ManagementPackDisplayName

	Write-Host "Setting Management Pack Description."
	$MP.Description = "Auto Generated Management Pack via PowerShell"


	# Getting System Library Reference
	$SystemLibrary = "System.Library"
	$MPToAdd = $MG.GetManagementPacks($SystemLibrary)[0]
	$MPAlias = "System"


	# Adding References to Management Pack
	$MPReference = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($MPToAdd)
	$MP.References.Add($MPAlias, $MPReference)

	Write-Host "New References Added to Management Pack [$($MP.DisplayName)]."


	# Creating Custom Class
	$CustomClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackClass($MP,("CustomServiceMonitor_"+$ServiceName.ToString().Replace("$","_")+"_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")
	$CustomClassBase         = $MG.EntityTypes.GetClasses("Name='Microsoft.Windows.ComputerRole'")[0]
	$CustomClass.Base        = $CustomClassBase
	$CustomClass.Hosted      = $true
	$CustomClass.DisplayName = "$($ManagementPackDisplayName), Registry Key - $($RegistryKey)"
	
	Write-Host "Custom Class - [$($CustomClass.DisplayName)] Added to Management Pack - [$($MP.DisplayName)]."


	# Create Discoveries - <Discoveries> - XML Portion
	$Discovery                = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscovery($MP,"RegKeyDiscovery")
	$Discovery.Category       = "Discovery"
	$Discovery.DisplayName    = "Discovery by Registry Key"
	$Discovery.Description    = "Applies Custom Service Monitoring to a host if it contains a specific Registry Key Entry"


	# Create Discovery <Discovery> - XML Portion and Setting 'Target' Value
	$DiscoveryTarget          = $MG.EntityTypes.GetClasses("Name='Microsoft.Windows.OperatingSystem'")[0]
	$Discovery.Target         = $DiscoveryTarget


	# Create Discovery Class <DiscoveryClass> - XML Portion and Setting 'TypeID' Value.
	$DiscoveryClass           = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryClass
	$DiscoveryClass.set_TypeID($CustomClass)
	$Discovery.DiscoveryClassCollection.Add($DiscoveryClass)


	# Create DataSource for Discovery
	$DSModuleType             = $MG.GetMonitoringModuleTypes("Microsoft.Windows.FilteredRegistryDiscoveryProvider")[0]
	$DSModule                 = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModule($Discovery, "DS")
	$DSModule.TypeID          = [Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModuleType]$DSModuleType
	$DataSourceConfiguration  = "<ComputerName>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$</ComputerName>
						          <RegistryAttributeDefinitions>
						            <RegistryAttributeDefinition>
						              <AttributeName>$($RegistryKey)</AttributeName>
						              <Path>SOFTWARE\SCOM\$($RegistryKey)</Path>
						              <PathType>0</PathType>
						              <AttributeType>0</AttributeType>
						            </RegistryAttributeDefinition>
						          </RegistryAttributeDefinitions>
						          <Frequency>300</Frequency>
						          <ClassId>`$MPElement[Name=`"$($CustomClass)`"]$</ClassId>
						          <InstanceSettings>
						            <Settings>
						              <Setting>
						                <Name>`$MPElement[Name=`"Windows!Microsoft.Windows.Computer`"]/PrincipalName$</Name>
						                <Value>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/PrincipalName$</Value>
						              </Setting>
						              <Setting>
						                <Name>`$MPElement[Name=`"System!System.Entity`"]/DisplayName$</Name>
						                <Value>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/PrincipalName$</Value>
						              </Setting>
						            </Settings>
						          </InstanceSettings>
						          <Expression>
						            <SimpleExpression>
						              <ValueExpression>
						                <XPathQuery Type=`"String`">Values/$($RegistryKey)</XPathQuery>
						              </ValueExpression>
						              <Operator>Equal</Operator>
						              <ValueExpression>
						                <Value Type=`"String`">True</Value>
						              </ValueExpression>
						            </SimpleExpression>
						          </Expression>"
								  
	# Adding DataSource and DataSource Configuration to Discovery.
	$DSModule.Configuration   = $DataSourceConfiguration
	$Discovery.DataSource     = $DSModule

	Write-Host "Discovery Configuration for Registry Key: [$($RegistryKey)] was successfully deployed to Management Pack - [$($MP.DisplayName)]"


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


	Write-Host "[$($Monitor.DisplayName)] - Service Monitor was successfully deployed to Management Pack - [$($MP.DisplayName)]"


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

Write-Host "Deployment of Custom Service Monitor for [$($ServiceDisplayName)] and New Management Pack - [$($ManagementPackDisplayName)] Completed Successfully!"
