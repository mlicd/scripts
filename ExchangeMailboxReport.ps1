# Essential information about user mailboxes, in a CSV. This can take a while to generate.
# Author: Marty Lichtel
#
# Run from an Exchange server, or connect to Exchange PowerShell endpoint first. 
# You also need the Active Directory PowerShell module installed.
# Swap other Recipient Types to gather that data instead of user mailboxes:
#  { $_.recipienttypedetails -eq "sharedmailbox" }
#  { $_.recipienttypedetails -eq "roommailbox" }
#
# Report tip: If you import this data into Excel, you can create a handy TotalSizeBytes column based on the TotalSize that
#             strips out the extra alpha characters and parentheses. 
#             Use this formating formula, assuming your new column is Column G and TotalSize is Column F: 
#             =VALUE(MID(F2,SEARCH("(",F2)+1,SEARCH(")",F2) - SEARCH("(",F2)-6))
#             23.66 GB (25,407,949,615 bytes) --> becomes --> 25,407,949,615   now you can sort on this column in correct numerical order

$mailboxes = get-mailbox -ResultSize Unlimited | where { $_.recipienttypedetails -eq "usermailbox" }
$result = foreach ($mailbox in $mailboxes)
{
  $Hash = @{
     Name = $mailbox.DisplayName
     Logon = $mailbox.samaccountname
     UPN = $mailbox.UserPrincipalName
     AccountEnabled = (get-aduser -identity $mailbox.samaccountname).enabled
     MailboxEnabled = $mailbox.IsMailboxEnabled
     LastLogon = (Get-MailboxStatistics $mailbox.identity).LastLogonTime
     ItemCount = (Get-MailboxStatistics $mailbox.identity).ItemCount
     TotalSize = (Get-MailboxStatistics $mailbox.identity).TotalItemSize
     TotalDeletedItems = (Get-MailboxStatistics $mailbox.identity).TotalDeletedItemSize
     DB = (Get-MailboxStatistics $mailbox.identity).Database
     SendQuota = $mailbox.ProhibitSendQuota
     SendReceiveQuota = $mailbox.ProhibitSendReceiveQuota
  }

New-Object PsObject -Property $Hash | Select-Object Name,Logon,UPN,AccountEnabled,MailboxEnabled,LastLogon,ItemCount,TotalSize,TotalDeletedItems,DB,SendQuota,SendReceiveQuota

}

$result | Export-Csv -Path $env:userprofile\desktop\UserMailboxReport.csv -NoTypeInformation
