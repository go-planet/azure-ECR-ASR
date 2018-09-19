 <#
    .SYNOPSIS
        Creates a report and alerts when VMs are running. This script will be scheduled to run after regular business hours.

    .DESCRIPTION
        Process Flow:
            Create vm.htm template for HTML report
            Connect to Azure
            Select subscription
            Check if VM is running, if so, add to report
            Continue checking all subscriptions
            Create an HTM output (vm.htm)
            Send email and embed report as HTML message
                
    .NOTES
        Author: Travis Moore
        Date: July 2018
        URL: TBD

        Assumptions:
            -Administrator rights to view all subscriptions and VM statuses
#>
  
###Start Script

##Style Sheet Format
$a = "<style>"
$a = $a + "HEAD{font-family:arial;color:white; background-color:#003466;}"
$a = $a + "BODY{font-family:arial;color:white; background-color:#003466;}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: white;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: white;background-color:#003466}"
$a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: white;background-color:#003466}"
$a = $a + "</style>"

#Add Date
$d=get-date

#Reset Notification Count
$i = 0
$results =@()

#Create report body
New-Item .\vm.htm -type file -force
add-content .\vm.htm "$a <H2>Virtual Machine Inventory - $d </H2><table><tr>" 
add-content .\vm.htm "<th>Server Name</th><th>Resource Group</th><th>Status</th><th>Tenant</th><th>Owner</th><th>Email</th><th>Startup Time (GMT)</th></tr>"

#Create File for email contacts
New-Item .\dl.csv -type file -force
add-content .\dl.csv "email" 


cls

##Connect to Azure
#Prompt for Azure credentials
$creds = (get-credential)
Connect-AzureRmAccount -Credential $creds

#Create array of subscriptions for looping through
$subscription = Get-AzureRmSubscription

foreach ($tenant in $subscription)
    {

#Set context and select Azure subscription from array
    write-host "Selecting"$tenant.Name "to inventory." -ForegroundColor Cyan
    $context = Get-AzureRmSubscription -SubscriptionName $tenant.name | Set-AzureRmContext
    Select-AzureRmSubscription -Context $context

##Count servers in tenant. If zero (0), then skip tenant and move to next.
    $servercount = (Get-AzureRmVM).count
    write-host "Server Count:"$servercount -ForeGroundColor Yellow
    Write-Host ""
    if ($servercount -eq 0)
        {
        write-host "No virtual machines have been provisioned in this tenant." -ForegroundColor Magenta
        Write-Host ""
        Write-Host ""
        }
#When server count >0 check if server is running
    else
        {
        write-host "Gathering VM inventory and current running state." -ForegroundColor Cyan
        Write-Host ""
        $RGs = Get-AzureRMResourceGroup
            foreach($RG in $RGs)
                {
                $VMs = Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName
            
##Gather server details
                foreach ($VM in $VMs)
                        {
                            $VMDetail = Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Name $VM.Name -Status
                            $VMName = $VM.Name
                            $GetTime = $VMDetail.Statuses
                            $VMTime = $GetTime.Time
                            $Sub = $tenant.Name
                            $RGN = $VMDetail.ResourceGroupName
                            $CheckOwnerTag = (Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Name $VM.Name).Tags.Owner
                            if ($CheckOwnerTag -eq $Null)
                                {
                                $Owner = "No Owner Tag"
                                }
                                else
                                {
                                $Owner = $CheckOwnerTag
                                }
			    $CheckEmailTag = (Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName -Name $VM.Name).Tags.Email
                            if ($CheckEmailTag -eq $Null)
                                {
                                $Email = "No Email Tag"
                                }
                                else
                                {
                                $Email = $CheckEmailTag
                                }
 ##If server is running, notify on the screen and output to vm.htm report.
 ##Increment the notification counter one to flag email. If notification counter is zero, no email will be sent.                                                           
                            foreach ($VMStatus in $VMDetail.Statuses)
                            {
                            $VMStatusDetail = $VMStatus.DisplayStatus
                                                        }
                            if ($VMStatusDetail -eq "VM running")
                                {
                                add-content .\vm.htm "<tr><td>"
                                Write-Host ("VM Name: " + $VMName) -ForegroundColor Magenta
                                add-content .\vm.htm "$VMName"
                                add-content .\vm.htm "</td><td>"

                                Write-Host "Resource Group: $RGN" -ForegroundColor Yellow
                                add-content .\vm.htm "$RGN"
                                add-content .\vm.htm "</td><td>"
                                
                                Write-Host "Status: $VMStatusDetail" -ForegroundColor Yellow
                                Add-Content .\vm.htm "$VMStatusDetail"
                                add-content .\vm.htm "</td><td>"
                                
                                Write-Host "Tenant Name: $Sub" -ForegroundColor Yellow
                                Add-Content .\vm.htm "$Sub"
                                add-content .\vm.htm "</td><td>"

                                Write-Host "Owner: $Owner" -ForegroundColor Yellow
                                Add-Content .\vm.htm "$Owner"
                                add-content .\vm.htm "</td><td>"

                                Write-Host "Email: $Email" -ForegroundColor Yellow
                                Add-Content .\vm.htm "$Email"
                                add-content .\vm.htm "</td><td>"
				add-content .\dl.csv $Email
                                
                                Write-Host "Startup Time: $VMTime" -ForegroundColor Yellow
                                Add-Content .\vm.htm "$VMTime"
                                add-content .\vm.htm "</td></tr>"
				
				#Increment notification counter
				$i++
                                
                                Write-Host ""
                                
                                }
 ##If server is not running, notify on the screen output only.
                            else
                                {
                                Write-Host "VM:" $VMName -ForegroundColor Magenta
                                Write-Host "Status:" $VMStatusDetail -ForegroundColor Green
                                Write-Host ""
                                }                                                        
                        }
                    }
             }
           }

##Send email notification if notification counter ($i) increments above 0
#Send-MailMessage Reference - https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.utility/send-mailmessage

if ($i -gt 0)

	{
	
	$dl = import-csv .\dl.csv	
	foreach ($a in $dl)
		{
		$SMTP = "smtp.office365.com"
		$From = "<valid mailbox in O365>"
		$To = $a.email


		$Subject = "Running VM Report - $d"
		$Body = get-content .\vm.htm -Raw
		$Attachment =  ".\vm.htm"

		write-host "Sending notification email to"$a.email"." -ForegroundColor Cyan

	if ($a.email -notlike "No Email Tag")
		{
		Send-MailMessage -From $From -To $To -CC "<enter CC recipients manually>" -Subject $Subject -BodyasHTML -Body $Body -SmtpServer $SMTP -Credential $creds -UseSsl -Port 587

		write-host "Notification email sent to"$a.email"." -ForegroundColor Green
		}
	else
		{
		write-host "Email not valid. Update the email tag on the object." -ForeGroundColor Yellow
		}
	}
	}

else
	{

	write-host "No VMs running. Exiting script." -foregroundcolor Cyan

	}

del .\vm.htm
del .\dl.csv

###Script End