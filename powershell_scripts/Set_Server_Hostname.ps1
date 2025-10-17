# USAGE: Set-ServerHostname -NewName 'DC01' -Restart

function Set-ServerHostname {
<#
.SYNOPSIS
  Renames the local computer. Optionally reboots immediately.

.PARAMETER NewName
  The new computer name (1–15 chars, NetBIOS-compliant).

.PARAMETER Restart
  If specified, the computer will reboot after renaming.

.EXAMPLE
  Set-ServerHostname -NewName 'DC01' -Restart
#>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9-]{1,15}$')][string]$NewName,
    [switch]$Restart
  )

  $current = (Get-ComputerInfo -Property CsName).CsName
  if ($current -ieq $NewName) {
    Write-Verbose "Hostname already '$NewName'. Nothing to do."
    return
  }

  if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename-Computer to '$NewName'")) {
    try {
      Rename-Computer -NewName $NewName -Force -ErrorAction Stop
      Write-Verbose "Queued rename from '$current' to '$NewName'."
      if ($Restart) {
        Write-Verbose "Rebooting to apply hostname change..."
        Restart-Computer -Force
      } else {
        Write-Warning "Hostname change pending. Please reboot to apply '$NewName' before DC promotion."
      }
    } catch {
      throw "Failed to rename computer to '$NewName': $($_.Exception.Message)"
    }
  }
}