<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function New-CSVFile {
    [CmdletBinding()]
    param 
    (
        [string]$OutputPath,
        [PSCustomObject]$InputObject
    )
    begin {
        Write-Log "Write results to CSV-File to ${OutputPath}`n" -OnScreen
    }
    
    process {
        $InputObject | Export-Csv -Path $OutputPath -Append -NoTypeInformation -Delimiter ";"
    }
    
    end {
        Test-Path $OutputPath
    }
}