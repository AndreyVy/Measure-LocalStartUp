<#
.SYNOPSIS
  Write logging information
.DESCRIPTION
  Write logging information to powershell console. Include steps and errors. Errors also are written to Result.err
  file. One of theavailable  message types should be set.
.EXAMPLE
  PS C:\> Write-Log -message <MessageText> [-ErrorMessage -OnScreen -Header -SimpleText]
.INPUTS
  message
  message type
.OUTPUTS
  Write steps and/or erros on the screen
  Create Result.err file with all errors
.NOTES
  General notes
#>
function Write-Log {
    [CmdletBinding()]
    param (
        [string]$message,
        [switch]$ErrorMessage = $false,
        [switch]$OnScreen = $false,
        [switch]$Header = $false,
        [switch]$SimpleText = $false
    )
    $ScreenText = "[$(Get-Date -format "yyyy/MM/dd HH:mm:ss")] STEP: ${message}"
    $ErrorText = "[$(Get-Date -format "yyyy/MM/dd HH:mm:ss")] ERROR: ${message}"

    If ($Verbose) {
        If ($OnScreen) { Write-Host $ScreenText -ForegroundColor Gray }
        If ($Header) {
            Write-Host
            Write-Host $message -ForegroundColor Yellow
            Write-Host
        }
        If ($SimpleText) { Write-Host $message -ForegroundColor Yellow }
    }

    If ($ErrorMessage) {
        Add-Content -Value $ErrorText -Path "${ScriptCurentDirectory}\Results.err" -Encoding Unicode
        If ($ShowErrors) { Write-Host $ErrorText -ForegroundColor Red }
    }
}