<#
.SYNOPSIS
  Measure application startup time
.DESCRIPTION
  Measure time from process start to main windows appearence. Allow to perform test several times,
  start application with different command lines and in different working directories
.EXAMPLE
  PS C:\> Measure-Startup -InputAppObj <AppCustomObject> -NumberOfTests <Number>
  Performs Start-Up test <Number> times for <AppCustomObject>
.INPUTS
  Custom objects with the next properties:
  1) FilePath         - Complete path to application which should be tested [REQUIRED]
  2) Arguments        - Command-line arguments for tested application [OPTIONAL]
  3) WorkingDirectory - Path to application working directory [OPTIONAL]
  
  NumberOfTests      - Specify how many times test should be done. It is equal to 1 by default [OPTIONAL]
.OUTPUTS
  Returns custom object: Path to exe, minimum, maximum, average start times
.NOTES
#>
function Measure-Startup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [StartProperties]$InputAppObj
    )
    
        $StartupTimes = @()
        $ResDelay = @()
        If (-Not (Test-Path $InputAppObj.FilePath)) {
            $AppPath = $InputAppObj.FilePath
            Write-Log "${AppPath} was not found`n" -ErrorMessage
            break
        }
        Write-Log $InputAppObj.Name -Header

        for ($i = 1; $i -le $NumberOfTests; $i++) {

            Write-Log "Round #${i}..." -OnScreen
      
            If ($InputAppObj.IsScript) {
                $Results = Get-ScriptStartTime -TestObject $InputAppObj #return  test obj, 0, $StopWatch.Elapsed.TotalSeconds
            }
            else {
                $Results = Get-ProgramStartTime -TestObject $InputAppObj #return $ResStartTime.TotalSeconds, $TotalStartTime.TotalSeconds
        
                ForEach ($Process in $Results[0]) {
                    $isClosed = Close-Application -Process $Process
                    If ($isClosed -ne $True) {
                        throw "Process was not terminated`n"
                    }
                }
            }
            # END EXE TEST BLOCK
            $ResDelay += [double]$Results[1]
            $StartupTimes += [double]$Results[2]

            Write-Log "Test execution was completed`n" -OnScreen
    }
    
    end {
        If ($StartupTimes.Length) {
            $MeasuredResults = $StartupTimes | Measure-Object -Minimum -Maximum -Average
            $AvrResDelay = $ResDelay | Measure-Object -Average

            return [OutputTestObj]::new(
                ${env:COMPUTERNAME}.ToString(),
                (Get-Date -UFormat "%Y.%m.%d %H:%M").ToString(),
                $NumberOfTests,
                $InputAppObj.Name,
                [math]::Round($AvrResDelay.Average, 1),
                [math]::Round($MeasuredResults.Minimum, 1),
                [math]::Round($MeasuredResults.Maximum, 1),
                [math]::Round($MeasuredResults.Average, 1),
                "N\A"
            )
        }
        else {
            throw "Execution failed: There are no test results`n"
        }
    }
}