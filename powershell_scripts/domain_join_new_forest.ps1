# Objectives: 
# 1. Set fixed IP
# 2. Set Primary DNS to point to itself
# 3. Install AD DS
# 4. Domain Join
# 5. Reboot

# Variables
$InterfaceAlias = "Ethernet"
$IPv4Address = "192.168.1.100"
$PrefixLength = 24
$DefaultGateway = "192.168.1.1"
$DnsServers = @("192.168.1.100", "1.1.1.1")
$NewComputerName = "DC01"
$DomainName = "corp.example"
$DomainNetBIOS = "CORP"
$InstallDNS = "$true"


# Ensure we are elevated
function Test-IsElevated {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated)) {
  throw "Please run this script in an elevated PowerShell session."
}


# Clear any previous DHCP settings
If((Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue)) {
    Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
}
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPv4Address -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway

# Set DNS to itself first
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServers

# Quick Check
Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4
Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4


#Renaming Computer
Rename-Computer -NewName $NewComputerName -Force -Restart

# Creating a New Forest and adding DC to domain

## Installing AD DS + RSAT
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Set DSRM (Directory Service Restore Mode) password
$DsrmPass = Read-Host -Prompt "Enter DSRM Password" -AsSecureString

# Promote to first DC in the Forest
Install-ADDSForest `
  -DomainName $DomainName `
  -DomainNetbiosName $DomainNetBIOS `
  -InstallDNS:($InstallDNS) `
  -SafeModeAdministratorPassword $DsrmPass `
  -NoRebootOnCompletion:$true `
  -Force

Restart-Computer

# Checking After Reboot

Get-ADDDomain
Get-ADForest
dcdiag /v