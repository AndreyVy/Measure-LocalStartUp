[CmdletBinding()]
param 
(
    [Parameter(ParameterSetName="SingleApp",
    Mandatory=$True,
    ValueFromPipeline=$True)]
    [string]$FilePath,

    [Parameter(ParameterSetName="SingleApp")]
    [string]$ArgumentList,

    [Parameter(ParameterSetName="SingleApp")]
    [string]$WorkingDirectory,

    [int]$NumberOfTests = 1
)
function Start-MeasureStartup {
    [CmdletBinding()]
    param()
    $TestedObjects += [StartProperties]::new($FilePath, $Arguments, $WorkingDirectory)
    $TestedObjects |Measure-Startup -InputAppObj $InputAppObj -NumberOfTests $NumberOfTests
        }
        catch {
            Write-Log $InputAppObj.Name -ErrorMessage
            Write-Log $_.Exception.Message -ErrorMessage
            continue
        }
    }
}

class StartProperties{
    [string]$Name
    [string]$FilePath
    [string]$Arguments
    [string]$WorkingDirectory
    StartProperties( $_file, $_arg, $_wkdir ) {
        $this.Name = (Get-Item ([System.Environment]::ExpandEnvironmentVariables($_file))).Name
        $this.FilePath = (Get-Item ([System.Environment]::ExpandEnvironmentVariables($_file))).FullName
        $this.Arguments = [System.Environment]::ExpandEnvironmentVariables($_arg)
        $this.WorkingDirectory = [System.Environment]::ExpandEnvironmentVariables($_wkdir)
    }
}

class TestResult {
    [string]$ComputerName
    [string]$TestDateTime
    [int]$NumberOfTests
    [string]$Application
    [double]$AverageConfigTime
    [double]$MinimumStartTime
    [double]$MaximumStartTime
    [double]$AverageStartTime
    [string]$Discrepancy
    TestResult( $_cn, $_tdt, $_not, $_app, $_config_avr, $_min, $_max, $_avr, $_dscr ) {
        $this.ComputerName = $_cn
        $this.TestDateTime = $_tdt
        $this.NumberOfTests = $_not
        $this.Application = $_app
        $this.AverageConfigTime = $_config_avr
        $this.MinimumStartTime = $_min
        $this.MaximumStartTime = $_max
        $this.AverageStartTime = $_avr
        $this.Discrepancy = $_dscr
    }
}
# ----------------------------------------Start main function------------------------------------------------------
Start-MeasureStartup