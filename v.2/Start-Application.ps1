<#
.SYNOPSIS
  Start the application
.DESCRIPTION
  Start the application with arguments (if any) in specified Working Directory (if any)
.EXAMPLE
  PS C:\> Start-Application -InputAppObject <InputAppObj>
.INPUTS InputAppObj
  Object which has type InputAppObj
.OUTPUTS
  Nothing
.NOTES
  General notes
#>
function Start-Application {
    [CmdletBinding()]
    param ( $InputAppObject )
    # Set process start conditions
    $StartConditions = @{
        FilePath = $InputAppObject.FilePath
        ArgumentList = $InputAppObject.Arguments
        WorkingDirectory = $InputAppObject.WorkingDirectory
        Wait = $InputAppObject.IsScript
    }
    Start-Process @StartConditions -PassThru
}