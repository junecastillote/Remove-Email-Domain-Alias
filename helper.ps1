. .\Functions.ps1

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

# Domain to replace (eg. olddomain.com)
$oldDomain = ''
# Domain to use as primary address (eg. olddomain.com)
$newDomain = ''
# Domain Controller hostname or FQDN
$domainController = ''

# Get your recipient object collection.
# eg. To get a single recipient object -
#   $InputObject = Get-Recipient <recipient>
# eg. To get a all recipient object -
#   $InputObject = Get-Recipient -ResultSize Unlimited
# eg. To get all recipient object that has the old domain in their alias, excluding mail contact objects
#   $InputObject = @(Get-Recipient -Filter "EmailAddresses -like '*$oldDomain' -and RecipientTypeDetails -ne 'MailContact'" -ResultSize unlimited -DomainController $domainController)
$InputObject = Get-Recipient ''

# TEST MODE: remove old domain aliases - NO CHANGES
AvadaKedavra -InputObject $InputObject `
-OldDomain $oldDomain `
-NewDomain $newDomain `
-DomainController $domainController

# EXECUTE MODE: remove old domain aliases
AvadaKedavra -InputObject $InputObject `
-OldDomain $oldDomain `
-NewDomain $newDomain `
-DomainController $domainController `
-testMode $false

# Restore aliases from the same object
Rennervate -InputObject $InputObject -DomainController $domainController

# Restore aliases from the same object using backup XML file
Rennervate -InputObject (Import-Clixml "XMLFILE") -DomainController $domainController

(get-RemoteMailbox $InputObject.DistinguishedName -DomainController $DomainController ).EmailAddresses -join "`n"
(get-distributiongroup ($InputObject.DistinguishedName)  -DomainController $DomainController ).EmailAddresses -join "`n"
