<#
.SYNOPSIS
    Read application list from csv-file.
.DESCRIPTION
    Read application list from csv-file. The file should contains entries "FilePath" (mandatory), Arguments (optional)
    and WorkingDirectory(optional). All other entries are ignored. Function returns collection of objects, which
    has custom type InputAppobj
.EXAMPLE
    PS C:\> Get-CSVFile -InputPath <PathToCSVFile>
.INPUTS
    Path to CSV File
.OUTPUTS
    InputAppObj
.NOTES
    General notes
#>
function Get-CSVFile {
    [CmdletBinding()]
    param 
    (
        [string]$InputPath
    )
  
    begin {
        $InputAppObjs = @()
    }
  
    process {
        try {
            $InputObjs = Import-Csv -LiteralPath $InputPath -Delimiter ";"
            $str_count = 1
            ForEach ($InputObj in $InputObjs) {
                If ($null -eq $InputObj.FilePath) {
                    Write-Log "Property FilePath is not definded in ${str_count} line of ${InputPath}" -ErrorMessage
                    continue
                }
                else { $_path = $InputObj.FilePath }
        
                If ($null -eq $InputObj.Arguments) { $_args = "" }
                else { $_args = $InputObj.Arguments }

                If ($null -eq $InputObj.WorkingDirectory) { $_wrkd = "" }
                else { $_wrkd = $InputObj.WorkingDirectory }

                $InputAppObjs += [InputAppObj]::new($_path, $_args, $_wrkd)
                $str_count++
            }
        }
        catch {
            Write-Log $_.Exception.Message -ErrorMessage
        }
    }
  
    end {
        $InputAppObjs
    }
}