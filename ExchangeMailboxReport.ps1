# Essential information about user mailboxes, in a CSV. This can take a while to generate.
# Author: Marty Lichtel
#
# Connect to Exchange PowerShell endpoint first. 
# Swap other Recipient Types to gather that data instead of user mailboxes:
#  { $_.recipienttypedetails -eq "sharedmailbox" }
#  { $_.recipienttypedetails -eq "roommailbox" }

$mailboxes = get-mailbox -ResultSize Unlimited | where { $_.recipienttypedetails -eq "usermailbox" }
$result = foreach ($mailbox in $mailboxes)
{
  $Hash = @{
     Name = $mailbox.DisplayName
     Logon = $mailbox.samaccountname
     UPN = $mailbox.UserPrincipalName
     LastLogon = (Get-MailboxStatistics $mailbox).LastLogonTime
     ItemCount = (Get-MailboxStatistics $mailbox).ItemCount
     TotalSize = (Get-MailboxStatistics $mailbox).TotalItemSize
     TotalDeletedItems = (Get-MailboxStatistics $mailbox).TotalDeletedItemSize
     DB = (Get-MailboxStatistics $mailbox).Database
     SendQuota = $mailbox.ProhibitSendQuota
     SendReceiveQuota = $mailbox.ProhibitSendReceiveQuota
  }

New-Object PsObject -Property $Hash | Select-Object Name,Logon,UPN,LastLogon,ItemCount,TotalSize,TotalDeletedItems,DB,SendQuota,SendReceiveQuota

}

$result | Export-Csv -Path $env:userprofile\desktop\UserMailboxReport.csv -NoTypeInformation