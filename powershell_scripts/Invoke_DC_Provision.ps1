function Invoke-DCProvision {
<#
.SYNOPSIS
  Promotes one or more servers to Domain Controllers (new forest or additional DC).

.DESCRIPTION
  Advanced function demonstrating CmdletBinding, parameter sets, ShouldProcess, Verbose/Debug,
  validation attributes, pipeline input, error handling, and Begin/Process/End structure.

.PARAMETER ComputerName
  Target server(s). Defaults to the current computer name. Accepts pipeline input by value and by property name.

.PARAMETER Credential
  Credentials used for remote operations (if remoting is used later).

.PARAMETER NewForestDomainName
  FQDN for the new forest (ParameterSet: NewForest).

.PARAMETER NewForestNetBIOS
  NetBIOS name for the new forest (ParameterSet: NewForest).

.PARAMETER ExistingDomainName
  FQDN of the existing domain (ParameterSet: AdditionalDC).

.PARAMETER SiteName
  Optional AD site name (ParameterSet: AdditionalDC).

.PARAMETER SafeModeAdministratorPassword
  DSRM password as SecureString. If omitted, you’ll be prompted.

.PARAMETER InstallDNS
  Whether to install DNS on the DC (default: $true).

.EXAMPLE
  # Joining existing domain on the CURRENT machine:
  Invoke-DCProvision -ExistingDomainName corp.example -SiteName 'HQ' -InstallDNS:$true -Confirm

.EXAMPLE
  # Creating a NEW forest on the CURRENT machine:
  Invoke-DCProvision -NewForestDomainName corp.example -NewForestNetBIOS CORP -Verbose -Confirm

.EXAMPLE
  # Still supports explicit or piped names if you want:
  'DC01','DC02' | Invoke-DCProvision -NewForestDomainName corp.example -NewForestNetBIOS CORP -Verbose -WhatIf

.NOTES
  Demo-quality wrapper for educational purposes. In production, add WinRM/Copy/Invoke steps if provisioning remotely.
#>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High',
        DefaultParameterSetName = 'AdditionalDC'
    )]
    param(
        # Common
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('Name','CN')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = @($env:COMPUTERNAME),

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [bool]$InstallDNS = $true,

        # New Forest set
        [Parameter(Mandatory, ParameterSetName='NewForest')]
        [ValidatePattern('^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$NewForestDomainName,

        [Parameter(Mandatory, ParameterSetName='NewForest')]
        [ValidatePattern('^[A-Za-z0-9]{1,15}$')]
        [string]$NewForestNetBIOS,

        # Additional DC set
        [Parameter(Mandatory, ParameterSetName='AdditionalDC')]
        [ValidatePattern('^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$ExistingDomainName,

        [Parameter(ParameterSetName='AdditionalDC')]
        [string]$SiteName,

        # DSRM password (both sets)
        [Parameter()]
        [SecureString]$SafeModeAdministratorPassword
    )

    begin {
        Write-Verbose "ParameterSetName = $($PSCmdlet.ParameterSetName)"
        if (-not $SafeModeAdministratorPassword) {
            $SafeModeAdministratorPassword = Read-Host -Prompt "Enter DSRM (Safe Mode) password" -AsSecureString
        }

        # Helper: ensure AD DS binaries exist
        function Ensure-AdDsBinaries {
            $feat = Get-WindowsFeature AD-Domain-Services
            if (-not $feat.Installed) {
                Write-Verbose "Installing AD-Domain-Services binaries..."
                Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -ErrorAction Stop | Out-Null
            } else {
                Write-Verbose "AD-Domain-Services already installed."
            }
        }
        Ensure-AdDsBinaries
    }

    process {
        foreach ($comp in $ComputerName) {
            $target = $comp

            $action = if ($PSCmdlet.ParameterSetName -eq 'NewForest') {
                "Promote $target to NEW FOREST DC ($NewForestDomainName / $NewForestNetBIOS)"
            } else {
                "Promote $target as ADDITIONAL DC to $ExistingDomainName (Site: $SiteName)"
            }

            if ($PSCmdlet.ShouldProcess($target, $action)) {
                try {
                    if ($PSCmdlet.ParameterSetName -eq 'NewForest') {
                        Write-Verbose "Calling Install-ADDSForest for $target..."

                        $forestParams = @{
                            DomainName                    = $NewForestDomainName
                            DomainNetbiosName             = $NewForestNetBIOS
                            InstallDNS                    = $InstallDNS
                            SafeModeAdministratorPassword = $SafeModeAdministratorPassword
                            NoRebootOnCompletion          = $true
                            Force                         = $true
                            ErrorAction                   = 'Stop'
                        }
                        Install-ADDSForest @forestParams
                    }
                    else {
                        Write-Verbose "Calling Install-ADDSDomainController for $target..."

                        $dcParams = @{
                            DomainName                    = $ExistingDomainName
                            SafeModeAdministratorPassword = $SafeModeAdministratorPassword
                            InstallDNS                    = $InstallDNS
                            NoGlobalCatalog               = $false
                            NoRebootOnCompletion          = $true
                            Force                         = $true
                            ErrorAction                   = 'Stop'
                        }
                        if ($PSBoundParameters.ContainsKey('Credential')) { $dcParams.Credential = $Credential }
                        if ($PSBoundParameters.ContainsKey('SiteName') -and $SiteName) { $dcParams.SiteName = $SiteName }

                        Install-ADDSDomainController @dcParams
                    }

                    Write-Verbose "Promotion complete on $target. Rebooting..."
                    if ($target -ieq $env:COMPUTERNAME -or $target -eq 'localhost') {
                        Restart-Computer -Force -ErrorAction Stop
                    } else {
                        Restart-Computer -ComputerName $target -Force -ErrorAction Stop
                    }

                    [pscustomobject]@{
                        ComputerName = $target
                        Action       = $PSCmdlet.ParameterSetName
                        InstallDNS   = $InstallDNS
                        Rebooted     = $true
                        Timestamp    = Get-Date
                    }
                }
                catch {
                    $msg = "Failed to promote $($target): $($_.Exception.Message)"
                    Write-Error -Message $msg -Category OperationStopped -ErrorAction Stop
                }
            }
            else {
                Write-Verbose "ShouldProcess declined for $target."
            }
        }
    }

    end {
        Write-Verbose "Invoke-DCProvision finished."
    }
}