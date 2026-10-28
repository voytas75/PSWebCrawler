[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'Use Windows PowerShell 5.1.' }
Import-Module Pester -RequiredVersion 3.4.0
$result = Invoke-Pester -Script (Join-Path $PSScriptRoot 'Site.Contract.Tests.ps1') -PassThru
$result | Select-Object TotalCount,PassedCount,FailedCount,PendingCount,SkippedCount | Format-List
# Expected RED is still a nonzero exit, never acceptance.
if ($result.FailedCount -gt 0 -or $result.PendingCount -gt 0 -or $result.SkippedCount -gt 0 -or $result.TotalCount -ne 5) { exit 1 }
exit 0
