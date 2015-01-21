<#  --- [EnableSCOMNotificationSubscriptions] PowerShell Script  ---

Author(s):        Ryan Irujo
Inception:        01.21.2015
Last Modified:    01.21.2015

Description:      This Script provides an automated method of enabling Notification Subscriptions in SCOM.
                  The list of Notification Subsciptions to Enable are read from a text file called 'notification.txt' which
                  needs to be located in the same directory as this Script. Additionally, the first line of the text file
                  must have the entry 'Notification'.
                  
                  Example 'notification.txt' file:
                  
                  Notification
                  __Notification Subscription - AD Admins
                  __Notification Subscription - Exchange Admins
                  __Notification Subscription - Windows Admins
                  __Notification Subscription - UNIX Admins


Additional Notes: After the Notification Subscription is Enabled, the Notification Timer is reset to ensure Subscribers 
                  are not flooded with Alerts.


Changes:          01.21.2013 - [R. Irujo]
                  - Inception.


Syntax:          ./EnableSCOMNotificationSubscriptions.ps1

Example:         ./EnableSCOMNotificationSubscriptions.ps1
#>

Clear-Host

# Importing the Names of Notification Subscriptions from a Text File. Note that the Text File must have 'Notification' as the First Line.
[array]$NotificationsList = Import-Csv .\notifications.txt


# Iterating through each Notification Subscription Name.
Foreach ($Entry in $NotificationsList)
{
    # Retriving the Matching Notification Subscription from SCOM.
    $Subscription = Get-SCOMNotificationSubscription | Where-Object {$_.DisplayName -eq $Entry.Notification}

    # If the Notification Subscripton is already enabled, it is skipped and the Script Continues.
    if ($Subscription.Enabled -eq $true)
    {
        echo "$($Subscription) is already enabled."
    }

    # If the Notification Subscription is not enabled, it is enabled and has its Notification Timer is reset to ensure Subscribers are not flooded with Alerts.
    if ($Subscription.Enabled -eq $false)
    {
        Enable-SCOMNotificationSubscription $Subscription
        echo "$($Subscription) has been enabled."

        $Subscription.Update($true)
        echo "$($Subscription) Notification Timer has been reset to lessen the number of alerts."
    }
}
