#========================================================================
# Created on:   8/16/2013
# Revised on:   6/11/2014
# Created by:   Marty Lichtel
# 
# Filename: ADAccountReport.ps1
#
# Description: Skeleton for running account reports out of Active
#              Directory. Includes basic check of LogonHours which is a 
#              Byte Array. Also provides some decoding for the 
#              useraccountcontrol flags. Requires Active Directory PowerShell 
#              module. CSV file will be written to your desktop.
#
#              6/11/2014 Changes - AD PowerShell provides handy virtual attributes for
#              some hard to translate settings such as:
#              - AccountExpirationDate   
#              - PasswordLastSet         (now using for friendly date output)
#              - PasswordNeverExpires    (now using to see if account flagged to expire or not)
#              - LastLogonDate
#
# Scratch list of attributes I am interested in:
# name,samaccountname,enabled,accountexpirationdate,logonhours,whencreated,whenchanged,pwdlastset,useraccountcontrol,distinguishedname
#========================================================================

Import-Module ActiveDirectory

# Set the DN for the Base OU
# Set output file
# ------------------------------------------------------------------------------------------
$OUName = "DC=DOMAIN,DC=COM"
$OutputFile = "AccountReport.csv"
# ------------------------------------------------------------------------------------------

Write-Host "`nCollecting data from $OUName ..." -ForegroundColor yellow

$ObjectSet = Get-ADUser -LdapFilter "(ObjectCategory=User)" -SearchBase $OUName -properties *
#$ObjectSet = Get-ADGroup -LdapFilter "(ObjectCategory=Group)" -SearchBase $OUName -properties *

Write-Host "`nProcessing data ..." -ForegroundColor yellow

# Per-object processing to extract logonhours and useraccountcontrolflags into meaningful output, assemble interested attributes into hash table
$result = foreach ($accountObject in $ObjectSet) {

	# LogonHours is a byte string, 21 bytes total. The default is null and the account has no logon hour limitations.
	# If you so much as examine the logonhours in the GUI without changing anything, the attribute is written with
	# a "1" for every byte. The effect is the same, there is no logon hours restriction.
	# If the account is denied ALL logon hours, every byte is set to "0." That is what Accounts Admin does as a method to
	# disable accounts (prevents interactive & network logons).
 	If ($accountObject.logonhours -ne $null) {
		
		$byteCheck = 0
		foreach ($byte in $accountObject.logonhours) {
			If ($byte -eq 0) { $byteCheck += 1 }
		}			
		
		If ($byteCheck -eq 21) { $DescLogonHours = "NO HOURS" }
		elseif  (($byteCheck -lt 21) -and ($byteCheck -gt 0)) { $DescLogonHours = "SOME HOURS" }  # Uncommon
		else { $DescLogonHours = "ALL HOURS" }
		
	} # if logonhours
	else { $DescLogonHours = "ALL HOURS" }   # logonHours null (default, never written, allow all hours)
	
	# This section is not needed when using the AD PowerShell PasswordNeverExpires attribute check
	# ------------------------------------------------------------------------------------------------
	# Relevant useraccountcountrolflags commonly found by examining service accounts.
	# These values are a match for an account that at least has the DONT_EXPIRE_PASSWORD flag set.
	# The indivdiual flags sum together, producing a wide range of possible outcomes.
	# $arrUACOptions = 65536,66048,66050,66080,590336,2163200
	# switch ($accountObject.useraccountcontrol) {
	#	{$arrUACOptions -contains $_ } { $DescUAC = "DON'T EXPIRE" }
	#	Default { $DescUAC = "WILL EXPIRE" }	
	#} # switch
	# -------------------------------------------------------------------------------------------------
	
	$AttributesHashTable = @{
  		Name = $accountObject.name
		samAccountName = $accountObject.samaccountname
		EmployeeID = $accountObject.employeeID
		Enabled = $accountObject.enabled
		LastLogonDate = $accountObject.LastLogonDate
		PasswordNeverExpires = $accountObject.PasswordNeverExpires
		PasswordLastSet = $accountObject.PasswordLastSet
		AccountExpiration = $accountObject.accountexpirationdate
		LogonHours = $DescLogonHours
		WhenCreated = $accountObject.whencreated
		WhenChanged = $accountObject.whenchanged
		UserAccountControl = $accountObject.useraccountcontrol
		DistinguishedName = $accountObject.distinguishedname
		extensionAttribute1 = $accountObject.extensionAttribute1
		extensionAttribute2 = $accountObject.extensionAttribute2
		extensionAttribute3 = $accountObject.extensionAttribute3
		extensionAttribute4 = $accountObject.extensionAttribute4
		extensionAttribute5 = $accountObject.extensionAttribute5
		extensionAttribute6 = $accountObject.extensionAttribute6
		extensionAttribute7 = $accountObject.extensionAttribute7
		extensionAttribute8 = $accountObject.extensionAttribute8
		extensionAttribute9 = $accountObject.extensionAttribute9
		extensionAttribute10 = $accountObject.extensionAttribute10
		extensionAttribute11 = $accountObject.extensionAttribute11
		extensionAttribute12 = $accountObject.extensionAttribute12
		extensionAttribute13 = $accountObject.extensionAttribute13
		extensionAttribute14 = $accountObject.extensionAttribute14
		extensionAttribute15 = $accountObject.extensionAttribute15
	}
  	
	# Select-Object is necessary to provide explicit order for output, hash table is not guaranteed to output in any particular order
	New-Object PsObject -Property $AttributesHashTable | Select-Object Name,samAccountName,EmployeeID,Enabled,LastLogonDate,PasswordNeverExpires,AccountExpiration,LogonHours, `
		WhenCreated,WhenChanged,UserAccountControl,DistinguishedName,extensionAttribute1,extensionAttribute2,extensionAttribute3, extensionAttribute4, `
		extensionAttribute5, extensionAttribute6, extensionAttribute7, extensionAttribute8, extensionAttribute9, extensionAttribute10, extensionAttribute11, `
		extensionAttribute12, extensionAttribute13, extensionAttribute14, extensionAttribute15
	
} # foreach	

$result | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "`nDone." -foregroundcolor yellow
Write-Host "`n"

# Common useraccountcontrol flags in use; there are many more - See http://support.microsoft.com/kb/305144/en-us
# $UAC_DISABLED = 2
# $UAC_PW_NOTREQD = 32
# $UAC_NORMAL = 512
# $UAC_DONT_EXPIRE = 65536
# $UAC_TRUST_FOR_DELEG = 524288
# $UAC_USE_DES_ONLY = 2097152

