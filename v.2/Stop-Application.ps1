<#
.SYNOPSIS
  Clos the specified application
.DESCRIPTION
  Function send close signal to application and check if it was success. If it was not, close the application
  forsibly
.EXAMPLE
  PS C:\> Close-Application -Process ProcessName
.INPUTS
  ProcessName
.OUTPUTS
  Bolean value: TRUE if the application was closed and FALSE if it wasn't
.NOTES
  General notes
#>
function Close-Application {
    [CmdletBinding()]
    param (
        $Process
    )

    begin {
        Write-Verbose "Closing application..."
    }

    process {
        # Try to close application gently
        $Process.CloseMainWindow()
        [System.Threading.Thread]::Sleep($SLEEP_INTERVAL)
        $isExit = $Process.HasExited
        If ($isExit) {
            $Process.Close()
            Write-Log "Application was closed gracefully" -OnScreen
        }
        # Close it forsibly
        Else {
            Start-Process "taskkill" -ArgumentList "/PID", $Process.Id, "/T /F" -WindowStyle Hidden -Wait
            Write-Log "Force close was applied" -OnScreen
            for ($numTry = 0; $numTry -le 10 ; $numTry++) {
                $isExit = $Process.HasExited
                If ($isExit) {
                    break
                }
                [System.Threading.Thread]::Sleep($SLEEP_INTERVAL * 2)
            }
        }
    }

    end {
        $Process.HasExited  
    }
}