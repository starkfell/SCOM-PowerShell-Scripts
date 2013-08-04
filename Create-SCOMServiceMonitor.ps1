#--- Create-SCOMServiceMonitor - v1.0 ---#

Clear-Host


# Import Operations Module if it isn't already imported.
If (!(Get-Module OperationsManager)) {
  Import-Module "D:\Program Files\System Center 2012\Operations Manager\Powershell\OperationsManager\OperationsManager.psd1"
	}
	
  
$ManagementServer = "<Management_Server_Name>"



# Connect to SCOM Management Group.
$MG = Get-SCOMManagementGroup
$ServiceMonitorType   = $MG.GetUnitMonitorTypes() | Where-Object {$_.Name -eq "Microsoft.Windows.CheckNTServiceStateMonitorType"}
$MonitorClassCriteria = $MG.GetMonitoringClasses() | Where-Object {$_.DisplayName -eq "Windows Server 2008 R2 Full Operating System"}



# Retrieving SCOM Management Pack to work with.
$MP        = Get-SCOMManagementPack | Where-Object {$_.DisplayName -like "*second*"}
$MPApublic = [Microsoft.EnterpriseManagement.Configuration.ManagementPackAccessibility]::Public



# Creating New Service Monitor
$Monitor = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitor($MP,($MP.Name+[Guid]::NewGuid().ToString().Replace("-","")),$MPApublic)



# Setting new New Monitor Up as a Service Monitor and targeting the Hosts of the Group in the MP.
$Monitor.set_DisplayName("Windows Update Service")
$Monitor.set_TypeID($ServiceMonitorType)
$Monitor.set_Target($MonitorClassCriteria)



# Configure Monitor Alert Settings
$Monitor.AlertSettings = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorAlertSettings
$Monitor.AlertSettings.set_AlertOnState("Error")
$Monitor.AlertSettings.set_AutoResolve($true)
$Monitor.AlertSettings.set_AlertPriority("Normal")
$Monitor.AlertSettings.set_AlertSeverity("Error")
$Monitor.AlertSettings.set_AlertParameter1("$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$")
$Monitor.AlertSettings.AlertMessage



# Configure Alert Settings - Alert Message
$AlertMessage = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackStringResource($MP, "SampleAlertMessage")
$AlertMessage.set_DisplayName("The Service has Stopped")
$AlertMessage.set_Description("The Service has Stopped on {0}")
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
$MonitorConfig = "<ComputerName>$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$</ComputerName>
                  <ServiceName>wuauserv</ServiceName>"

$Monitor.set_Configuration($MonitorConfig)



# Specify Parent Monitor by ID
$MonitorCriteria         = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorCriteria("Name='System.Health.AvailabilityState'")
$ParentMonitor           = $MG.GetMonitors($MonitorCriteria)[0]
$Monitor.ParentMonitorID = [Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackAggregateMonitor]]::op_implicit($ParentMonitor)



#Verify and Add Changes to the Management Pack. 
$MP.Verify()
$MP.AcceptChanges()








