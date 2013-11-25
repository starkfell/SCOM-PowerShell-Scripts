#  --- [CreateMPandCustomGroup_v1.0] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        11.23.2013
# Last Modified:    11.25.2013
#
# Description:      Code is in progress....
#
#
# Syntax:          ./CreateMPandCustomGroup_v1.0 <Management_Server> <MP_ID> <MP_Name> <MP_DisplayName> <Monitored_Hosts>
#
# Example:         ./CreateMPandCustomGroup_v1.0 SCOMMS01.fabrikam.local "Test.Custom.Group.101" "Test.Custom.Group.101" "Test Custom Group 101" ("TestServer101",TestServer102")

param($ManagementServer,$ManagementPackID,$ManagementPackName,$ManagementPackDisplayName,[array]$MonitoredHosts)

$ManagementServer           = "SCOMMS223.scom.local"
$ManagementPackID           = "Test.Custom.Group.101"
$ManagementPackName         = "Test.Custom.Group.101"
$ManagementPackDisplayName  = "Test Custom Group - 101"
[array]$MonitoredHosts      = ("SCORCH224.scom.local","SCOMDC221.scom.local")
$HostGUIDs                  = $null

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

	if (!$MonitoredHosts) {
		Write-Host "The Name of the Hosts (NetBIOS or FQDN) you want to add to the Custom Group must be provided , i.e. - (`"TestServer101`",`"TestServer102`")."
		exit 2;
		}


	Write-Host "Management Server:                    $($ManagementServer)"
	Write-Host "Management Pack ID:                   $($ManagementPackID)"
	Write-Host "Management Pack Name:                 $($ManagementPackName)"
	Write-Host "Management Pack Display Name:         $($ManagementPackDisplayName)"
	Write-Host "Monitored Hosts:                       $($MonitoredHosts)"

	# Connecting to the SCOM Management Group
	Write-Host "Connecting to the SCOM Management Group"
	$MG = New-Object Microsoft.EnterpriseManagement.ManagementGroup($ManagementServer)

	
	# Determining the GUID of the Monitored Hosts in SCOM.
	Foreach ($MonitoredHost in $MonitoredHosts) {
			 echo "$($MonitoredHost)"
			 $ObjectCriteria = New-Object Microsoft.EnterpriseManagement.Monitoring.MonitoringObjectGenericCriteria("FullName='Microsoft.Windows.Computer:$($MonitoredHost)'")
			 $HostGUID  = ($MG.GetMonitoringObjects($ObjectCriteria)).Id.ToString()
			 $HostGUIDs += "<MonitoringObjectId>$HostGUID</MonitoringObjectId>`n"
			 }


	# Determining if the Management Pack exists based upon its Display Name using a String Query.
	Write-Host "Determining if Management Pack - [$($ManagementPackDisplayName)] already exists."
	
	$MPQuery            = "DisplayName = '$($ManagementPackDisplayName)'"
	$MPCriteria         = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackCriteria($MPQuery)
	$MP                 = $MG.GetManagementPacks($MPCriteria)[0]
	
	If ($MP.Count -eq "0") {
		Write-Host "Management Pack - [$($ManagementPackDisplayName)] was NOT found in SCOM. Starting to Add Script now..."
	}
	Else {
	Write-Host "Management Pack - [$($ManagementPackDisplayName)] was found in SCOM. Script is now exiting."
	exit 2;
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
	$SystemLibraryRef = $MG.GetManagementPacks($SystemLibrary)[0]
	$SystemLibraryAlias = "System"
	
	# Getting Group Library Reference
	$GroupLibrary  = "Microsoft.SystemCenter.InstanceGroup.Library"
	$GroupLibraryRef = $MG.GetManagementPacks($GroupLibrary)[0]
	$GroupLibraryAlias = "MicrosoftSystemCenterInstanceGroupLibrary7585010"
	
	# Getting Windows Server 2008 Discovery Library Reference
	$WindowsServer2008DiscoveryLibrary  = "Microsoft.Windows.Server.2008.Discovery"
	$WindowsServer2008DiscoveryLibraryRef = $MG.GetManagementPacks($WindowsServer2008DiscoveryLibrary)[0]
	$WindowsServer2008DiscoveryLibraryAlias = "MicrosoftWindowsServer2008Discovery6069890"
	
	
	# Adding System Library Reference to Management Pack
	$MPRefSystemLibrary = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($SystemLibraryRef)
	$MP.References.Add($SystemLibraryAlias, $MPRefSystemLibrary)

	# Adding Group Library Reference to Management Pack
	$MPRefGroupLibrary = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($GroupLibraryRef)
	$MP.References.Add($GroupLibraryAlias, $MPRefGroupLibrary)

	# Adding Windows Server 2008 Discovery Library Reference to Management Pack
	$MPRefWindowsServer2008DiscoveryLibrary = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($WindowsServer2008DiscoveryLibraryRef)
	$MP.References.Add($WindowsServer2008DiscoveryLibraryAlias, $MPRefWindowsServer2008DiscoveryLibrary)	

	Write-Host "New References Added to Management Pack - [$($MP.DisplayName)]."


	# Creating Custom Group Class - Microsoft.SystemCenter.InstanceGroup
	$CustomComputerGroupClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackClass($MP,("CustomComputerGroup_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")
	$CustomComputerGroupBase              = $MG.EntityTypes.GetClasses("Name='Microsoft.SystemCenter.InstanceGroup'")[0]
	$CustomComputerGroupClass.Base        = $CustomComputerGroupBase
	$CustomComputerGroupClass.Singleton   = $true
	$CustomComputerGroupClass.Hosted      = $false
	$CustomComputerGroupClass.DisplayName = "$($ManagementPackDisplayName), Custom Computer Group"


	# Creating a New Discovery Rule for the Custom Group Class - Microsoft.SystemCenter.ComputerGroup
	$CustomComputerGroupClassDiscovery             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscovery($MP,($CustomComputerGroupClass.ToString()+"_Discovery_Rule"))
	$CustomComputerGroupClassDiscovery.Category    = "Discovery"
	$CustomComputerGroupClassDiscovery.DisplayName = "$($ManagementPackDisplayName) - Discovery"
	$CustomComputerGroupClassDiscovery.Description = "Discovery Rule for $($ManagementPackDisplayName)"

	# Creating and Adding the Discovery Target for the CustomComputerGroupClass
	$CustomComputerGroupClassDiscovery.Target = $CustomComputerGroupClass	

	# Creating and Adding the Discovery Relationship using the CustomComputerGroupClass
	$CustomComputerGroupClass_DiscoveryRelationship        = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryRelationship
	$CustomComputerGroupClass_DiscoveryRelationship_TypeID = $MG.EntityTypes.GetRelationshipClasses("Name='Microsoft.SystemCenter.InstanceGroupContainsEntities'")[0]
	$CustomComputerGroupClass_DiscoveryRelationship.set_TypeID($CustomComputerGroupClass_DiscoveryRelationship_TypeID)
	$CustomComputerGroupClassDiscovery.DiscoveryRelationshipCollection.Add($CustomComputerGroupClass_DiscoveryRelationship)

	# Creating and Adding the DataSource for the Discovery Rule of the CustomComputerGroupClass
	$CustomComputerGroupClassDiscovery_DS               = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModule($CustomComputerGroupClassDiscovery,"GroupPopulationDataSource")
	$CustomComputerGroupClassDiscovery_DS_ModuleType    = $MG.GetMonitoringModuleTypes("Microsoft.SystemCenter.GroupPopulator")[0]
	$CustomComputerGroupClassDiscovery_DS.TypeID        = [Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModuleType]$CustomComputerGroupClassDiscovery_DS_ModuleType
	$CustomComputerGroupClassDiscovery_DS.Configuration = "<RuleId>`$MPElement$</RuleId>
          						       <GroupInstanceId>`$MPElement[Name=`"$($CustomComputerGroupClass)`"]$</GroupInstanceId>
         							<MembershipRules>
           							  <MembershipRule>
              							     <MonitoringClass>`$MPElement[Name=`"$($WindowsServer2008DiscoveryLibraryAlias)!Microsoft.Windows.Server.2008.R2.Full.Computer`"]$</MonitoringClass>
              							     <RelationshipClass>`$MPElement[Name=`"$($GroupLibraryAlias)!Microsoft.SystemCenter.InstanceGroupContainsEntities`"]$</RelationshipClass>
             							     <IncludeList>
               							       <MonitoringObjectId></MonitoringObjectId>
            							     </IncludeList>
           							 </MembershipRule>
         						        </MembershipRules>"
	
	# Adding the Host GUIDs into the DataSource of the Discovery Rule for the CustomComputerGroupClass
	$Discovery_DS_Updated_Configuration = $CustomComputerGroupClassDiscovery_DS.Configuration.Replace("<MonitoringObjectId></MonitoringObjectId>","$HostGUIDs")

	# Applying the Host GUIDs into the DataSource of the Discovery Rule for the CustomComputerGroupClass
	$CustomComputerGroupClassDiscovery_DS.Configuration = $Discovery_DS_Updated_Configuration

	
	# Adding the DataSource to the Discovery Rule for the CustomComputerGroupClass
	$CustomComputerGroupClassDiscovery.DataSource = $CustomComputerGroupClassDiscovery_DS


	# Applying changes to the Management Pack in the SCOM Database.	
	try {
		Write-Host "Attempting to Add all changes on SCOM Management Server - [$($ManagementServer)] to Management Pack - [$($MP.DisplayName)]"
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

Write-Host "Deployment of Custom Group Management Pack - [$($ManagementPackDisplayName)] was Successful!"
