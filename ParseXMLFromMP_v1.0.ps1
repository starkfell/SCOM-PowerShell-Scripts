#  --- [ParseXMLFromMP_v1.0] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        04.21.2014
# Last Modified:    04.21.2014
#
# Description:      This Script parses through an Exported SCOM Monitoring Management Pack and returns the results in text format.
#                   These results can then be imported into an Excel Spreadsheet using the Data --> From Text Import utility in Excel.
#
#
# Syntax:          ./ParseXMLFromMP_v1.0 <Path_To_XML_File> <Path_To_Output>
#
# Example:         ./ParseXMLFromMP_v1.0 "D:\XML\Microsoft.Windows.Server.2012.Monitoring.xml" "D:\XML\Parsed\"

param($PathToXMLFile,$ExportFilePath)

Clear-Host

# Checking Parameter Values.
if (!$PathToXMLFile) {
	Write-Host "The Path to the XML File must be provided, i.e. - 'D:\XML\Exported.SCOM.MP.xml'"
	exit 2;
	}

if (!$ExportFilePath) {
	Write-Host "The Path where you want to results to be saved must be provided, i.e. - 'D:\XML\Parsed\'"
	exit 2;
	}


# Making sure the ExportToExcel Variable is empty.
$ExportToExcel = @()

# Retrieving the Current Date and Time to append to the end of the Results File.
$DateTimeStamp = Get-Date -Format MM.dd.yyyy.hh.mm.ss


# Retriving the Contents of the XML File.
[xml]$Monitoring = Get-Content $PathToXMLFile

# Retrieving the Management Pack ID (.NET Name Notation) of the Management Pack being Parsed.
$ManagementPackID = $Monitoring.ManagementPack.Manifest.Identity.ID

# Retrieving all of the Unit Monitors in the Management Pack.
$UnitMonitors = $Monitoring.ManagementPack.Monitoring.Monitors.UnitMonitor


# Adding the First Line of text to the 'ExportToExcel' Variable which will act as the Column Name(s) in the Exported File.
$ExportToExcel = "ID,Counter,Object,Frequency,Threshold,Direction,Number Of Samples`n"

# Parsing through each individual Unit Monitor and retrieving the Monitoring Configuration(s) of each.
ForEach ($UnitMonitor in $UnitMonitors) {

	$UnitMonitorID         = $UnitMonitor.ID
	$UnitMonitorCounter    = $UnitMonitor.Configuration.CounterName
	$UnitMonitorObject     = $UnitMonitor.Configuration.ObjectName
	$UnitMonitorFrequency  = $UnitMonitor.Configuration.Frequency
	$UnitMonitorThreshold  = $UnitMonitor.Configuration.Threshold
	$UnitMonitorDirection  = $UnitMonitor.Configuration.Direction
	$UnitMonitorNumSamples = $UnitMonitor.Configuration.NumSamples
	
	# The Configuration of each Unit Monitor is added as a new line to the 'ExportedToExcel' Variable.
	$ExportToExcel += "$UnitMonitorID,$UnitMonitorCounter,$UnitMonitorObject,$UnitMonitorFrequency,$UnitMonitorThreshold,$UnitMonitorDirection,$UnitMonitorNumSamples`n"
	
	}

# Creating the Path and File Name of where the Exported Results will be saved. 
$ParsedResultsFile = "$($ExportFilePath)\$($ManagementPackID).UnitMonitors_$($DateTimeStamp).txt"

# Exporting The Final Results out to a Text File.
$ExportToExcel | Out-File $ParsedResultsFile

Write-Host "Unit Monitors from the MP [$($ManagementPackID)] - have been Parsed and Exported Successfully."
Write-Host "Exported Results have been saved in: [$($ParsedResultsFile)]"



