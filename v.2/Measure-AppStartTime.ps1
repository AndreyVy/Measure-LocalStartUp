<#
.SYNOPSIS
  Calculate process start time
.DESCRIPTION
  Function monitors changes in a list of processes whith MainWindowTitle and returns startup time intervals,
  Process objects 
.EXAMPLE
  PS C:\> Get-ProgramStartTime -TestObject <InputAppObj>
.INPUTS
  Object with type InputAppObj
.OUTPUTS
  List of process objects
.NOTES
  General notes
#>
function Measure-AppStartTime {
    [CmdletBinding()]
    param ( 
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)]    
    [PSCustomObject]$TestObject )

    $START_SERVICE = "powershell", "pwrgate"

    Write-Verbose "Start time calculating for application"
    # Make first snapshot of applications with MainWindowTitle
    $firstProcessSnapshot = Get-Process | Where-Object MainWindowTitle
    # Start Application
    $StartConditions = @{
        FilePath            = $TestObject.FilePath
        ArgumentList        = $TestObject.Arguments
        WorkingDirectory    = $TestObject.WorkingDirectory
        Wait                = $TestObject.IsScript
    }
    
    $StartTime = Get-Date
    $initProcess = Start-Process @StartConditions -PassThru

    # Initialize StopWatch to limit test time if somthing going wrong
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($StopWatch.Elapsed.TotalSeconds -le $FREEZE_INTERVAL) {
        # Create new snapshot of applications with MainWindowTitle and compare snapshots
        $secondProcessSnapshot = Get-Process | Where-Object MainWindowTitle
        $ProcessListDifference = Compare-Object `
                        -ReferenceObject $firstProcessSnapshot `
                        -DifferenceObject $secondProcessSnapshot `
                        -PassThru
        If ($ProcessListDifference) {
            $StopTime = Get-Date
            break }
        Else { Start-Sleep -Milliseconds $SLEEP_INTERVAL }
    }
    $StopWatch.Stop()

    # Calculate time required for configuration configuration time
    If ($START_SERVICE  -contains $initProcess.Name) {
        $initStartUpTime = ($initProcess.ExitTime - $initProcess.StartTime).TotalSeconds
    }

    Write-Verbose "End time calculating"
    # Return results which include list of new processes and time interval in seconds
    [PSCustomObject]@{
        ProcessName = $ProcessListDifference
        initStartTime = $initStartUpTime
        TotalStartTime = ($StopTime - $StartTime).TotalSeconds
    }
}