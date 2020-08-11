Function AvadaKedavra {
    <#
    .SYNOPSIS
        Remove email alias that matches a domain and replace the primary email address with the new domain
    .DESCRIPTION
        Remove email alias that matches a domain and replace with a new domain.
        If run in -TestMode $false, the changes will be applied.
    .PARAMETER InputObject
        The Object containing the recipient objects, such as the result of Get-Recipient cmdlet.
        eg. Get-Recipient <recipient>, or Get-Recipient -ResultSize Unlimited
    .PARAMETER OldDomain
        The email domain that the function will look for and remove.
    .PARAMETER NewDomain
        The email domain that the function will set as the new primary smtp address domain.
    .PARAMETER DomainController
        The address of the domain controller where the changes will be targeted.
        It is important to send the changes to one domain controller to avoid issues that may arise due to replication latency.
    .PARAMETER TestMode
        If this is set to $TRUE (default), the function will run in test mode only. This means that no changes will be made to the recipient objects.
        If you're ready to make changes, make sure to set this to $FALSE
    .EXAMPLE
        PS C:\> AvadaKedavra `
        -InputObject (Get-RemoteMailbox <Mailbox>) `
        -OldDomain <oldDomain.com> `
        -NewDomain <newDomain.com> `
        -DomainController <DomainController> `
        -TestMode $false

        Replace the email alias that matches the old domain and set the new domain as the default
    .INPUTS

    .OUTPUTS

    .NOTES
        Connect to Exchange PowerShell first before running this.
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
    #>
    [cmdletbinding()]
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OldDomain,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewDomain,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainController,

        [parameter()]
        [boolean]$testMode = $true
    )

    $remotemailbox = $InputObject | Where-Object {$_.RecipientTypeDetails.ToString() -eq "RemoteUserMailbox"}
    $groups = $InputObject | Where-Object {$_.RecipientTypeDetails.ToString() -like "*group"}
    Write-Output "Found $($groups.count) groups and $($remotemailbox.count) remote mailbox"

    $backupFilename = "backup_$(Get-Date -format 'yyyy_MMM_dd-HH-mm-ss-tt').xml"

    if (!$testMode) {
        Write-Output "Creating XML backup - $backupFilename"
        $InputObject | Export-CliXml -Depth 8 $backupFilename
    }

    ##Region RemoteMailbox
    $remotemailbox | ForEach-Object {
        $currentObject = $_

        ### Change EmailAddressPolicyEnabled to $FALSE
        if ($currentObject.EmailAddressPolicyEnabled -eq $true) {

            if (!$testMode) {
                Write-Output "$($currentObject.DisplayName): Disabling Email Address Policy"
                Set-Mailbox $currentObject.DistinguishedName -EmailAddressPolicyEnabled -eq $false -DomainController $dc
            }
            else {
                Write-Output "[TEST] || $($currentObject.DisplayName): Disabling Email Address Policy"
            }
        }

        ### Set PrimarySMTPAddress domain
        if ($currentObject.PrimarySMTPAddress -notlike "*$($newDomain)") {
            $newPrimaryEmail = ($currentObject.PrimarySMTPAddress -split '@')[0] + "@$newDomain"

            if (!$testMode) {
                Write-Output "$($currentObject.DisplayName): Changing primary email address to $newPrimaryEmail"
                Set-RemoteMailbox $currentObject.DistinguishedName -PrimarySMTPAddress $newPrimaryEmail -DomainController $dc
            }
            else {
                Write-Output "[TEST] || $($currentObject.DisplayName): Changing primary email address to $newPrimaryEmail"
            }
        }

        ### Find all email alias matching the old domain
        $emailAddressesToRemove = [System.Array]::Findall(@($currentObject.EmailAddresses.AddressString), [predicate[string]] { $args -match $oldDomain })

        ### Remove all email alias matching the old domain
        if ($emailAddressesToRemove.count -gt 0) {

            if (!$testMode) {
                Write-Output ("$($currentObject.DisplayName): Removing addresses -> " + ($emailAddressesToRemove -join ';'))
                Set-RemoteMailbox  $currentObject.DistinguishedName -EmailAddresses @{remove = $emailAddressesToRemove } -DomainController $dc
            }
            else {
                Write-Output ("[TEST] || $($currentObject.DisplayName): Removing addresses -> " + ($emailAddressesToRemove -join ';'))
            }
        }
    }
    ##EndRegion

    ##Region Groups
    $groups | ForEach-Object {
        $currentObject = $_

        ### Change EmailAddressPolicyEnabled to $FALSE
        if ($currentObject.EmailAddressPolicyEnabled -eq $true) {

            if (!$testMode) {
                Write-Output "$($currentObject.DisplayName): Disabling Email Address Policy"
                Set-DistributionGroup $currentObject.DistinguishedName -EmailAddressPolicyEnabled -eq $false -DomainController $dc
            }
            else {
                Write-Output "[TEST] || $($currentObject.DisplayName): Disabling Email Address Policy"
            }
        }

        ### Set PrimarySMTPAddress domain
        if ($currentObject.PrimarySMTPAddress -notlike "*$($newDomain)") {
            $newPrimaryEmail = ($currentObject.PrimarySMTPAddress -split '@')[0] + "@$newDomain"

            if (!$testMode) {
                Write-Output "$($currentObject.DisplayName): Changing primary email address to $newPrimaryEmail"
                Set-DistributionGroup $currentObject.DistinguishedName -PrimarySMTPAddress $newPrimaryEmail -DomainController $dc
            }
            else {
                Write-Output "[TEST] || $($currentObject.DisplayName): Changing primary email address to $newPrimaryEmail"
            }
        }

        ### Find all email alias matching the old domain
        $emailAddressesToRemove = [System.Array]::Findall(@($currentObject.EmailAddresses.AddressString), [predicate[string]] { $args -match $oldDomain })

        ### Remove all email alias matching the old domain
        if ($emailAddressesToRemove.count -gt 0) {
            if (!$testMode) {
                Write-Output ("$($currentObject.DisplayName): Removing addresses -> " + ($emailAddressesToRemove -join ';'))
                Set-DistributionGroup  $currentObject.DistinguishedName -EmailAddresses @{remove = $emailAddressesToRemove } -DomainController $dc
            }
            else {
                Write-Output ("[TEST] || $($currentObject.DisplayName): Removing addresses -> " + ($emailAddressesToRemove -join ';'))
            }
        }
    }
    ##Region
}

Function Rennervate {
    <#
    .SYNOPSIS
        Restore the email alias and primary smtp address of a recipient object from a backup object
    .DESCRIPTION
        Restore the email alias and primary smtp address of a recipient object from a backup object
    .EXAMPLE
        PS C:\> Rennervate `
        -InputObject (Import-CliXml <backupxmlfile>) `
        -DomainController <domaincontroller>

        Restore the email alias and primary SMTP address of the recipient object(s) from an XML backup.
    .PARAMETER InputObject
        The Object containing the recipient objects, such as the result of Get-Recipient cmdlet.
        eg. Get-Recipient <recipient>, or Get-Recipient -ResultSize Unlimited
    .PARAMETER DomainController
        The address of the domain controller where the changes will be targeted.
        It is important to send the changes to one domain controller to avoid issues that may arise due to replication latency.
    .INPUTS

    .OUTPUTS

    .NOTES

    #>
	[cmdletbinding()]
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $InputObject,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainController
	)

	foreach ($currentObject in $InputObject) {
        Write-Output "$($currentObject.DisplayName)"
        if ($currentObject.RecipientTypeDetails.ToString() -eq 'RemoteUserMailbox') {
            Set-RemoteMailbox ($currentObject.DistinguishedName) -PrimarySMTPAddress ($currentObject.PrimarySMTPAddress.ToString()) -DomainController $DomainController
            Set-RemoteMailbox ($currentObject.DistinguishedName) -EmailAddresses @($currentObject.EmailAddresses.ProxyAddressString) -DomainController $DomainController
            (get-remotemailbox ($currentObject.DistinguishedName)  -DomainController $DomainController ).EmailAddresses -join "`n"
        }

        if ($currentObject.RecipientTypeDetails.ToString() -like "*group") {
            Set-DistributionGroup ($currentObject.DistinguishedName) -PrimarySMTPAddress ($currentObject.PrimarySMTPAddress.ToString()) -DomainController $DomainController
            Set-DistributionGroup ($currentObject.DistinguishedName) -EmailAddresses @($currentObject.EmailAddresses.ProxyAddressString) -DomainController $DomainController
            (get-DistributionGroup ($currentObject.DistinguishedName) -DomainController $DomainController ).EmailAddresses -join "`n"
        }
	}
}