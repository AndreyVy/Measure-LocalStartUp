<#
.SYNOPSIS
  Draw DOS-like menu
.DESCRIPTION
  Function create UI elements in powershell console
.EXAMPLE
  PS C:\> Draw-Menu -CursorStart <StartPosition> -menuItems <MenuItems> -menuPosition <Menuposition> -menuTitle <TitleText>
.INPUTS
  CursorStart - initial cursor position
  menuItems - List of items for menu
  menuPosition - Menu location in console
  menuTitle - menu title text
.OUTPUTS
  DOS-like menu
.NOTES
  General notes
#>
Function Draw-Menu ($CursorStart, [array]$menuItems, [int]$menuPosition, [string]$menuTitle) {
    $host.UI.RawUI.CursorPosition = $CursorStart
    ForEach ($item In $menuItems.Count) { Write-Host ''.PadRight(80, ' ') }
    $host.UI.RawUI.CursorPosition = $CursorStart

    [ConsoleColor]$fc = [System.ConsoleColor]::White
    [ConsoleColor]$bc = (Get-Host).UI.RawUI.BackgroundColor
    [int]  $l = $menuItems.length - 1
    [int]  $max = (($menuItems | Measure-Object -Maximum -Property Length).Maximum) + 4

    Write-host "  $menuTitle`n" -ForegroundColor White
    For ($i = 0; $i -le $l; $i++) {
        Write-Host '   ' -NoNewLine
        If ($i -eq $menuPosition)
        { Write-Host "  $($menuItems[$i])  ".PadRight($max) -ForegroundColor $bc -BackgroundColor $fc } Else
        { Write-Host "  $($menuItems[$i])  ".PadRight($max) -ForegroundColor $fc -BackgroundColor $bc }
    }
}
<#
.SYNOPSIS
  Return selected element in DOS-like menu
.DESCRIPTION
  Function creates DOS-like menu, and return selected object. Arrow keys (up and down) are used to change selection
.EXAMPLE
  PS C:\> Show-Menu -menuItems <ListOfMenuItems> -menuTitle <MenuHeaderText>
.INPUTS
  menuItems - List of menu items
  menuTitle - Header text of Menu
.OUTPUTS
  Selected menu item
.NOTES
  General notes
#>
Function Show-Menu ([array]$menuItems, [string]$menuTitle) {
    [int]$vkeycode = 0
    [int]$pos = 0
    $origpos = $host.UI.RawUI.CursorPosition

    Draw-Menu -CursorStart $origpos -menuItems $menuItems -menuPosition $pos -menuTitle $menuTitle
    Write-Host ''

    While ($vkeycode -ne 13) {
        $press = $host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
        $vkeycode = $press.VirtualKeyCode

        If ($vkeycode -eq 38) { $pos-- }    # Up
        If ($vkeycode -eq 40) { $pos++ }    # Down

        If ($pos -lt 0) { $pos = $menuItems.Length - 1 }    # Loop up and over
        If ($pos -ge $menuItems.length) { $pos = 0 }        # Loop down and around

        Draw-Menu -CursorStart $origpos -menuItems $menuItems -menuPosition $pos -menuTitle $menuTitle
        Write-Host ''
    }
    Return $($menuItems[$pos])
}