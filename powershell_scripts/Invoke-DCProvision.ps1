function Set-ServerNetwork {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InterfaceAlias,
        [Parameter(Mandatory)][System.Net.IPAddress]$IPv4Address,
        [Parameter(Mandatory)][ValidateRange(1,32)][int]$PrefixLength,
        [Parameter(Mandatory)][System.Net.IPAddress]$DefaultGateway,
        [Parameter(Mandatory)][ValidateCount(1,10)][System.Net.IPAddress[]]$DnsServers
    )

    if ($PSCmdlet.ShouldProcess($InterfaceAlias, "Configure static IP, gateway and DNS")) {
        Set-NetConnectionProfile -InterfaceAlias $InterfaceAlias -NetworkCategory Private -ErrorAction Stop

        Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        New-NetIPAddress -InterfaceAlias $InterfaceAlias `
            -IPAddress $IPv4Address.IPAddressToString `
            -PrefixLength $PrefixLength `
            -DefaultGateway $DefaultGateway.IPAddressToString `
            -ErrorAction Stop | Out-Null

        $dnsStrings = $DnsServers | ForEach-Object { $_.IPAddressToString }
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $dnsStrings -ErrorAction Stop

        Write-Verbose "[Net] Applied $($IPv4Address.IPAddressToString)/$PrefixLength, GW $($DefaultGateway.IPAddressToString), DNS $($dnsStrings -join ', ') on '$InterfaceAlias'."
    }
}

function Invoke-DCProvision {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High', DefaultParameterSetName='AdditionalDC')]
    param(
        # Treat as local run; you can still pass DC01 for logging/consistency
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name','CN')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter()] [System.Management.Automation.PSCredential]$Credential,
        [Parameter()] [bool]$InstallDNS = $true,

        # Network (mandatory)
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InterfaceAlias,
        [Parameter(Mandatory)][System.Net.IPAddress]$IPv4Address,
        [Parameter(Mandatory)][ValidateRange(1,32)][int]$PrefixLength,
        [Parameter(Mandatory)][System.Net.IPAddress]$DefaultGateway,
        [Parameter(Mandatory)][ValidateCount(1,10)][System.Net.IPAddress[]]$DnsServers,

        # Optional rename (queued; no immediate reboot)
        [Parameter()] [ValidatePattern('^[A-Za-z0-9-]{1,15}$')] [string]$RenameTo,

        # New Forest
        [Parameter(Mandatory, ParameterSetName='NewForest')]
        [ValidatePattern('^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$NewForestDomainName,
        [Parameter(Mandatory, ParameterSetName='NewForest')]
        [ValidatePattern('^[A-Za-z0-9]{1,15}$')]
        [string]$NewForestNetBIOS,

        # Additional DC
        [Parameter(Mandatory, ParameterSetName='AdditionalDC')]
        [ValidatePattern('^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]$ExistingDomainName,
        [Parameter(ParameterSetName='AdditionalDC')] [string]$SiteName,

        # DSRM
        [Parameter()] [SecureString]$SafeModeAdministratorPassword
    )

    begin {
        Write-Verbose "ParameterSetName = $($PSCmdlet.ParameterSetName)"
        if (-not $SafeModeAdministratorPassword) {
            $SafeModeAdministratorPassword = Read-Host -Prompt "Enter DSRM (Safe Mode) password" -AsSecureString
        }

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
            $target  = $comp
            $current = $env:COMPUTERNAME
            # We will run everything locally; allow passing DC01 even if current name differs
            $action = if ($PSCmdlet.ParameterSetName -eq 'NewForest') {
                "Configure network, queue optional rename '$RenameTo', promote to NEW FOREST ($NewForestDomainName/$NewForestNetBIOS), single reboot"
            } else {
                "Configure network, queue optional rename '$RenameTo', promote as ADDITIONAL DC to $ExistingDomainName (Site: $SiteName), single reboot"
            }

            if ($PSCmdlet.ShouldProcess($target, $action)) {
                try {
                    # 1) Network first (local)
                    Set-ServerNetwork -InterfaceAlias $InterfaceAlias `
                        -IPv4Address $IPv4Address -PrefixLength $PrefixLength `
                        -DefaultGateway $DefaultGateway -DnsServers $DnsServers

                    # 2) Queue rename (NO immediate reboot)
                    if ($RenameTo -and ($current -ne $RenameTo)) {
                        Write-Verbose "Queuing computer rename from '$current' to '$RenameTo' (will take effect at next reboot)."
                        Rename-Computer -NewName $RenameTo -Force -ErrorAction Stop
                    }

                    # 3) Promotion with NoRebootOnCompletion:$true (so we control a single reboot)
                    if ($PSCmdlet.ParameterSetName -eq 'NewForest') {
                        Write-Verbose "Calling Install-ADDSForest with NoRebootOnCompletion..."
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
                    } else {
                        Write-Verbose "Calling Install-ADDSDomainController with NoRebootOnCompletion..."
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

                    # 4) One reboot to apply both: rename + AD DS finalization
                    Write-Verbose "Promotion staged. Rebooting once to finalize rename and DC promotion..."
                    Restart-Computer -Force -ErrorAction Stop
                }
                catch {
                    $msg = "Failed on $($target): $($_.Exception.Message)"
                    Write-Error -Message $msg -Category OperationStopped -ErrorAction Stop
                }
            } else {
                Write-Verbose "ShouldProcess declined for $target."
            }
        }
    }

    end {
        Write-Verbose "Invoke-DCProvision finished."
    }
}