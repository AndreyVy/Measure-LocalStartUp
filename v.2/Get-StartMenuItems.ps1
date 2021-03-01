<#
.SYNOPSIS
  Get list of shortcuts from Startmenu
.DESCRIPTION
  Get list of shortcuts from Current User StartMenu and return it as array
.EXAMPLE
  PS C:\> Get-StartMenuItems
.INPUTS
  No
.OUTPUTS
  List of shortcuts in Current User StartMenu
.NOTES
  General notes
#>
function Get-StartMenuItems {
    [CmdletBinding()]
    param (
    )
  
    begin {
        $_InpAppObjs = @()
        Write-Log "Get StartMenu items for current user from`n${CurentUserPrograms}`n" -OnScreen
    }
  
    process {
        $ShortcutList = (Get-ChildItem $CurentUserPrograms -Recurse -File -Include "*lnk").FullName
        forEach ($Shortcut in $ShortcutList) {
            $_InpAppObjs += [InputAppObj]::new($Shortcut, "", "")
        }
    }
  
    end { 
        $_InpAppObjs
    }
}