# Remove Email Address Alias Matching a Domain
This script can help you prepare the removal of a domain from Office 365 in a Hybrid environment.

The function `AvadaKedavra` can remove email addresses that match the domain you speficy. While the function and `Rennervate` can be used to restore the email addresses from backup.

These functions are found inside the ***Functions.ps1*** file. You could import the functions by [Dot-Sourcing](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scripts?view=powershell-7#script-scope-and-dot-sourcing) the script or copy-paste the whole thing in your PowerShell session.

> **NOTE**: *This script is to be run in the On-Prem Exchange PowerShell only. It is expected that changes to your recipient objects are replicated to Office 365 via Azure AD Connect.*

## AvadaKedavra

```PowerShell
AvadaKedavra [-InputObject] <Object> [-OldDomain] <string> [-NewDomain] <string> [-DomainController] <string> [[-testMode] <bool>] [<CommonParameters>]
```

This function will:

1. Remove all proxy email address that matches a domain you specify.
2. Set a new primary SMTP address using another domain that you specify.

> **Note**: *Although this function creates a backup of the input objects (to XML) before making changes, it is strongly recommended to manually take a backup of the properties before running this in real mode.*

### Example 1 : Delete all proxy email address with *olddomain.com* and use *newdomain.com* as primary smtp email address.

```PowerShell
# Domain to replace (eg. olddomain.com)
$oldDomain = 'olddomain.com'
# Domain to use as primary address (eg. newdomain.com)
$newDomain = 'newdomain.com'
# Domain Controller hostname or FQDN
$domainController = 'domaincontroller'

# eg. To get all recipient object that has the old domain in their alias, excluding mail contact objects
$InputObject = @(Get-Recipient -Filter "EmailAddresses -like '*$oldDomain' -and RecipientTypeDetails -ne 'MailContact'" -ResultSize unlimited -DomainController $domainController)

# Create a backup of your objects first
$InputObject | Export-Clixml .\backup.xml

# TEST MODE: NO CHANGES, simulation only
AvadaKedavra -InputObject $InputObject `
-OldDomain $oldDomain `
-NewDomain $newDomain `
-DomainController $domainController

# EXECUTE MODE: remove old domain aliases in real-time
AvadaKedavra -InputObject $InputObject `
-OldDomain $oldDomain `
-NewDomain $newDomain `
-DomainController $domainController `
-testMode $false

```

## Rennervate

```PowerShell
Rennervate [-InputObject] <Object> [-DomainController] <string> [<CommonParameters>]
```

This function can help you restore the email addresses of the recipient object from backup.

### Example 1: Restore Email Addresses from XML Backup

```PowerShell
Rennervate -InputObject (Import-Clixml .\backup.xml) -DomainController 'domaincontroller'
```