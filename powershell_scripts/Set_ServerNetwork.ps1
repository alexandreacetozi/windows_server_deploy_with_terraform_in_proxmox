# USAGE:
#  Set-ServerNetwork -InterfaceAlias "Ethernet" `
#    -IPv4Address 192.168.1.100 -PrefixLength 24 -DefaultGateway 192.168.1.100 `
#    -DnsServers 192.168.1.100,1.1.1.1

function Set-ServerNetwork {
<#
.SYNOPSIS
  Configure a static IPv4 address, default gateway, and DNS servers.

.DESCRIPTION
  Applies settings on the local computer's specified interface.
  Uses safe, idempotent logic: clears existing IPv4 addresses on
  the interface, sets the new address/gateway, and DNS servers.

.PARAMETER InterfaceAlias
  NIC alias (e.g., "Ethernet"). Use Get-NetAdapter to list.

.PARAMETER IPv4Address
  IPv4 address for the server (e.g., 10.10.10.10).

.PARAMETER PrefixLength
  CIDR prefix length (1..32), e.g., 24.

.PARAMETER DefaultGateway
  Default IPv4 gateway (e.g., 10.10.10.1).

.PARAMETER DnsServers
  One or more DNS server IPv4 addresses (first is primary).

.EXAMPLE
  Set-ServerNetwork -InterfaceAlias "Ethernet" `
    -IPv4Address 10.10.10.10 -PrefixLength 24 -DefaultGateway 10.10.10.1 `
    -DnsServers 10.10.10.10,1.1.1.1

  New forest (local host):
    . .\Invoke-DCProvision.ps1

  'DC01' | Invoke-DCProvision `
    -InterfaceAlias "Ethernet" `
    -IPv4Address 10.10.10.10 -PrefixLength 24 `
    -DefaultGateway 10.10.10.1 -DnsServers 10.10.10.10,1.1.1.1 `
    -NewForestDomainName corp.example -NewForestNetBIOS CORP `
    -Verbose -WhatIf

    'DC01' | Invoke-DCProvision `
    -InterfaceAlias "Ethernet" `
    -IPv4Address 10.10.10.10 -PrefixLength 24 `
    -DefaultGateway 10.10.10.1 -DnsServers 10.10.10.10,1.1.1.1 `
    -NewForestDomainName corp.example -NewForestNetBIOS CORP `
    -Verbose -Confirm  

  Additional DC (local host):
  . .\Invoke-DCProvision.ps1

  Invoke-DCProvision -ComputerName 'SRV10' `
  -InterfaceAlias "Ethernet" `
  -IPv4Address 10.20.30.40 -PrefixLength 24 `
  -DefaultGateway 10.20.30.1 -DnsServers 10.10.10.10,10.10.10.11 `
  -ExistingDomainName corp.example -SiteName "HQ" `
  -Verbose -WhatIf
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InterfaceAlias,
        [Parameter(Mandatory)][System.Net.IPAddress]$IPv4Address,
        [Parameter(Mandatory)][ValidateRange(1,32)][int]$PrefixLength,
        [Parameter(Mandatory)][System.Net.IPAddress]$DefaultGateway,
        [Parameter(Mandatory)][ValidateCount(1,10)][System.Net.IPAddress[]]$DnsServers
    )

    if ($PSCmdlet.ShouldProcess($InterfaceAlias, "Configure static IP, gateway and DNS")) {
        # Make the NIC discoverable (helpful for DCs)
        Set-NetConnectionProfile -InterfaceAlias $InterfaceAlias -NetworkCategory Private -ErrorAction Stop

        # Remove existing IPv4 addresses on the interface (keeps IPv6)
        Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        # Apply new IPv4 and default gateway
        New-NetIPAddress -InterfaceAlias $InterfaceAlias `
            -IPAddress $IPv4Address.IPAddressToString `
            -PrefixLength $PrefixLength `
            -DefaultGateway $DefaultGateway.IPAddressToString `
            -ErrorAction Stop | Out-Null

        # Set DNS (primary = first in list)
        $dnsStrings = $DnsServers | ForEach-Object { $_.IPAddressToString }
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $dnsStrings -ErrorAction Stop

        Write-Verbose "[Net] Applied static IP $($IPv4Address.IPAddressToString)/$PrefixLength, GW $($DefaultGateway.IPAddressToString), DNS $($dnsStrings -join ', ') on '$InterfaceAlias'."
    }
}