<#
.SYNOPSIS
  Calculate script life-time
.DESCRIPTION
  Calculate script life-time using StopWatch object
.EXAMPLE
  PS C:\> Get-ScriptStartTime -TestObject <InputAppObj>
.INPUTS
  Object with type InputAppObj
.OUTPUTS
  Startup time intervals
.NOTES
  General notes
#>
function Get-ScriptStartTime {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        $TestObject
    )
    Write-Verbose "Start time calculating for for script..."
    $ResStartTime = 0
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Application -InputAppObject $TestObject
    $StopWatch.Stop()
    Write-Log "End time calculating" -OnScreen
    $TestObject, $ResStartTime, $StopWatch.Elapsed.TotalSeconds
}