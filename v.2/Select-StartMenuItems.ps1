<#
.SYNOPSIS
  Return selected element in DOS-like menu
.DESCRIPTION
  Function collects elements in Users Start Menu and return selected shortcut
.EXAMPLE
  PS C:\> Select-StartMenuItem -$InputItem <PathToDirecoryWithShortcuts>
  Explanation of what the example does
.INPUTS
  [string] Path to Directory
.OUTPUTS
  File as PSObject
.NOTES
  General notes
#>
function Select-StartMenuItem {
    param (
        $InputItem
    )
    Clear-Host
    $InputItem = Get-Item $InputItem
    $CurrentDirectory = [System.Collections.ArrayList]::new()
  
    If (!$InputItem.PSIsContainer) {
        return $InputItem
    }

    $CurrentDirectory.Add("[...]") | Out-Null
    Get-ChildItem $InputItem | Sort-Object -Property Name| ForEach-Object {$CurrentDirectory.Add($_.Name) | Out-Null}

    $UserChoice = Show-Menu -menuTitle $InputItem.Name  -menuItems $CurrentDirectory
    If ($UserChoice -eq '[...]') {
        $UpperLimit = (Get-Item $CurentUserPrograms).Parent.FullName
        If ($UpperLimit -eq $InputItem.Parent.FullName) {
            $Result = $InputItem
        }
        else {
            $Result = $InputItem.Parent.FullName
        }
    }
    else {
        $Result = Join-Path $InputItem.FullName $UserChoice
    }
 
    Select-StartMenuItem $Result
}