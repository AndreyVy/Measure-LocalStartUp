<#
.SYNOPSIS
   Measure application startup
.DESCRIPTION
   Measure time from application start to a moment of text appearence in main window title
   Measure total time of script execution 
.EXAMPLE
   PS C:\>.\AppTimer.ps1
   Run script with DOS-like menu to select required options
.EXAMPLE
   PS C:\>.\Apptimer.ps1 -FilePath <Path> [-Arguments <ArgumentList>] [-WorkingDirectory <WorkingDirectory>]
   [-CSVOutput <PathToCSVFile>] [-NumberOfTests <Digit>]
   Run time-test for Path (.exe, .ps1, .cmd, .vbs, .lnk) with ArgumentList in WorkingDirectory.
   By default resluts are saved in csv-file in the same directory, where script is stored.
   Location of csv-file can be changed with argument -CSVOutput
   By default, script execute 3 tests for each application. This value can be changed with argument -NumberOfTests
   .lnk doesn't need optional arguments, their value will be taken from shortcut properties
.EXAMPLE
   PS C:\>.\Apptimer.ps1 -CSVInput <PathToCsv>
   Run time-tests for applications listed in PathToCsv File
.EXAMPLE
   PS C:\>.\Apptimer.ps1 -CustomStartMenuItems item1.lnk, item2.lnk, ... , itemN.lnk
   Run time-tests for specific application in All Users Start Menu
.EXAMPLE
   PS C:\>.\Apptimer.ps1 -StartMenu
   Run time-tests for all shortucts in All Users Start Menu. Custom filter will be applied to exclude default
   Windows applications (such as notepad, WordPad etc).
.INPUTS
   FilePath             - Specify path to application, script or shortcut
   Arguments            - Specify argument list for the application or script
   WorkingDirectory     - Specify working directory for applicatio or script
   CSVInput             - Specify path to csv-file, which contains list of application for testing. Csv SHOULD
                          include FilePath property and MAY include Arguments and Working Directory
                          All other values in the file are ignored.
   CSVOutput            - Specify path to csv-file, where output results should be saved (File is stored in script
                          parent directory, if not specified)
   CustomStartMenuItems - Specify list of StartMenu shortcuts for time-testing
   StartMenu            - Start tests for all application from All Users Start Menu
   Verbose              - Detailed log of executed actions
   Silent               - Silent mode, no Onscreen messages. Results will be written to output csv and err files
   ShowErrors           - Display errors on the Screen
   NumberOfTests        - Set number of tests for each application (if not specified, default value is 3)
.OUTPUTS
   Shows progress and results in console and store test-results to csv-file
.NOTES
  See ChangeLog.txt
#>
param 
(
    [string]$FilePath,
    [string]$Arguments,
    [string]$WorkingDirectory,
    [string]$CSVInput,
    [string]$CSVOutput,
    [string]$StartMenuItem,
    [switch]$StartMenu = $false,
    [switch]$Verbose = $false,
    [switch]$Silent = $false,
    [switch]$ShowErrors = $false,
    [int]$NumberOfTests = 1
)
# -----------------------------------------------------------------------------------------------------------------
# Initial variables block
# -----------------------------------------------------------------------------------------------------------------
# Time intervals:
$SLEEP_INTERVAL = 2000    # milliseconds, time interval after actions like close app and so on
$FREEZE_INTERVAL = 120    # seconds, max time interval allowed to 1 application startup,
# otherwise it is assumed as freezed
$STEP_INTERVAL = 300      # milliseconds time interval between looping actions

# Current User StartMenu Directory
$CurentUserPrograms = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)

[PSCustomObject]$InputAppObjs = @()

# List of ignored process
$ExclusionList = @(
    "CMD",
    "POWERSHELL",
    "WSCRIPT",
    "CSCRIPT",
    "PFWSMGR",
    "EXPLORER"
)

class InputAppObj {
    [string]$Name
    [string]$FilePath
    [string]$Arguments
    [string]$WorkingDirectory
    [bool]$IsScript

    InputAppObj() {}
    InputAppObj(
        [string]$_file,
        [string]$_arg,
        [string]$_wkdir
    ) {
        # location of Windows in-box interpretators:
        [string]$CMD = "${env:COMSPEC}"
        [string]$CSCRIPT = "${env:windir}\system32\cscript.exe"
        [string]$POWERSHELL = "${env:windir}\system32\WindowsPowerShell\v1.0\powershell.exe"
      
        $this.Name = $_file.Substring($_file.LastIndexOf("\") + 1)
        $_ext = $_file.Substring($_file.LastIndexOf(".") + 1).ToUpper()

        $_file = [Environment]::ExpandEnvironmentVariables($_file)
        $_arg = [Environment]::ExpandEnvironmentVariables($_arg)
        $_wkdir = [Environment]::ExpandEnvironmentVariables($_wkdir)
    
        switch -Regex ($_ext) {
            "EXE" {
                $this.FilePath = [Environment]::ExpandEnvironmentVariables($_file)
                $this.Arguments = [Environment]::ExpandEnvironmentVariables($_arg)
                $this.WorkingDirectory = [Environment]::ExpandEnvironmentVariables($_wkdir)
                $this.IsScript = $false
            }
            "LNK" {
                $WsShellObj = New-Object -ComObject Wscript.Shell
                $ShortcutObj = $WsShellObj.CreateShortcut($_file)
                $this.FilePath = [Environment]::ExpandEnvironmentVariables($ShortcutObj.TargetPath)
                $this.Arguments = [Environment]::ExpandEnvironmentVariables($ShortcutObj.Arguments)
                $this.WorkingDirectory = [Environment]::ExpandEnvironmentVariables($ShortcutObj.WorkingDirectory)
                $this.IsScript = $false
            }
            "BAT|CMD" {
                $this.FilePath = $CMD

                If ($_arg) {$_arg = " ${_arg}"}

                $this.Arguments = " /c `"${_file}`"${_arg}"
                $this.WorkingDirectory = $_wkdir
                $this.IsScript = $true
            }
            "VBS" {
                $this.FilePath = $CSCRIPT
                If ($_arg) {$_arg = " ${_arg}"}
                $this.Arguments = "`"${_file}`"${_arg}"
                $this.WorkingDirectory = $_wkdir
                $this.IsScript = $true
            }
            "PS1" {
                $this.FilePath = $POWERSHELL
                If ($_arg) {$_arg = " ${_arg}"}
                $this.Arguments = "-executionpolicy bypass -file `"${_file}`"${_arg}"
                $this.WorkingDirectory = $_wkdir
                $this.IsScript = $true
            }
            default {
                throw "Execution fails: FilePath format is not acceptable. Should be: EXE, LNK, BAT, CMD, VBS, PS1"
            }
        }
    }
}

class OutputTestObj {
    [string]$ComputerName
    [string]$TestDateTime
    [int]$NumberOfTests
    [string]$Application
    [double]$AverageRESTime
    [double]$MinimumStartTime
    [double]$MaximumStartTime
    [double]$AverageStartTime
    [string]$Discrepancy

    OutputTestObj() {}
    OutputTestObj(
        [string]$_cn,
        [string]$_tdt,
        [int]$_not,
        [string]$_app,
        [double]$_res_avr,
        [double]$_min,
        [double]$_max,
        [double]$_avr,
        [string]$_dscr
    ) {
        $this.ComputerName = $_cn
        $this.TestDateTime = $_tdt
        $this.NumberOfTests = $_not
        $this.Application = $_app
        $this.AverageRESTime = $_res_avr
        $this.MinimumStartTime = $_min
        $this.MaximumStartTime = $_max
        $this.AverageStartTime = $_avr
        $this.Discrepancy = $_dscr
    }
}
<#
.SYNOPSIS
  Write logging information
.DESCRIPTION
  Write logging information to powershell console. Include steps and errors. Errors also are written to Result.err
  file. One of theavailable  message types should be set.
.EXAMPLE
  PS C:\> Write-Log -message <MessageText> [-ErrorMessage -OnScreen -Header -SimpleText]
.INPUTS
  message
  message type
.OUTPUTS
  Write steps and/or erros on the screen
  Create Result.err file with all errors
.NOTES
  General notes
#>
function Write-Log {
    [CmdletBinding()]
    param (
        [string]$message,
        [switch]$ErrorMessage = $false,
        [switch]$OnScreen = $false,
        [switch]$Header = $false,
        [switch]$SimpleText = $false
    )
    $ScreenText = "[$(Get-Date -format "yyyy/MM/dd HH:mm:ss")] STEP: ${message}"
    $ErrorText = "[$(Get-Date -format "yyyy/MM/dd HH:mm:ss")] ERROR: ${message}"

    If ($Verbose) {
        If ($OnScreen) { Write-Host $ScreenText -ForegroundColor Gray }
        If ($Header) {
            Write-Host
            Write-Host $message -ForegroundColor Yellow
            Write-Host
        }
        If ($SimpleText) { Write-Host $message -ForegroundColor Yellow }
    }

    If ($ErrorMessage) {
        Add-Content -Value $ErrorText -Path "${ScriptCurentDirectory}\Results.err" -Encoding Unicode
        If ($ShowErrors) { Write-Host $ErrorText -ForegroundColor Red }
    }
}
## BEGIN
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

<#
.SYNOPSIS
  Start the application
.DESCRIPTION
  Start the application with arguments (if any) in specified Working Directory (if any)
.EXAMPLE
  PS C:\> Start-Applicatio -InputAppObject <InputAppObj>
.INPUTS
  Object which has type InputAppObj
.OUTPUTS
  Nothing
.NOTES
  General notes
#>
function Start-Application {
    [CmdletBinding()]
    param (
        $InputAppObject
    )
    begin {
        # Set process start conditions
        $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $StartInfo.FileName = $InputAppObject.FilePath
    
        If ($InputAppObject.Arguments) {
            $StartInfo.Arguments = $InputAppObject.Arguments
        }
    
        If ($InputAppObject.WorkingDirectory) {
            $StartInfo.WorkingDirectory = $InputAppObject.WorkingDirectory
        }
    }
  
    process {
        # Start process
        $ProcObj = [System.Diagnostics.Process]::new()
        $ProcObj.StartInfo = $StartInfo
        $ProcObj.Start() | Out-Null
        If ($InputAppObject.IsScript) {
            $ProcObj.WaitForExit()
        }
    }
}
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
        Write-Log "Closing application..." -OnScreen
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
function Get-ProgramStartTime {
  
    [CmdletBinding()]
    param (
        $TestObject
    )
    begin {
        [string]$PWRGATE = "PWRGATE"
        [bool]$TestFail = $true     # default condition for test results
        $ResStartTime = 0   # default value for RES start time
        Write-Log "Start time calculating for application..." -OnScreen
    }
  
    process {
        # Make first snapshot of applications with MainWindowTitle
        $InitVisibleProcesses = Get-Process | Where-Object {$_.MainWindowTitle}

        # Start Application
        $StartTime = Get-Date
        Start-Application -InputAppObject $TestObject
    
        # Initialize StopWatch to limit test time if somthing going wrong
        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    
        while ($StopWatch.Elapsed.TotalSeconds -le $FREEZE_INTERVAL) {
      
            # Create new snapshot of applications with MainWindowTitle and compare snapshots
            $newVisibleProcesses = Get-Process | Where-Object {$_.MainWindowTitle}
            $ProcessListDifference = Compare-Object $InitVisibleProcesses $newVisibleProcesses -PassThru
            If ($ProcessListDifference) {
                If ($ExclusionList -contains $ProcessListDifference.Name.ToUpper()) { continue }
                $StopTime = Get-Date
                $TestFail = $false
                break
            }
            Else {
                [System.Threading.Thread]::Sleep($STEP_INTERVAL)
            }
        }
        $StopWatch.Stop()
    
        # Generate an error if test pasts more then FREEZE_INTERVAL
        If ($TestFail) {
            throw "Test failed. Operation time exceeded maximum allowed time ${FREEZE_INTERVAL} seconds`n"
        }

        # Calculate RES start time if input object is RES
        If ($TestObject.FilePath.ToUpper() -match $PWRGATE ) {
            $ResStartTime = $StopTime - $ProcessListDifference.StartTime
        }
    
        $TotalStartTime = $StopTime - $StartTime
    }
  
    end {
        Write-Log "End time calculating" -OnScreen
        # Return results which include list of new processes and time interval in seconds
        $ProcessListDifference, $ResStartTime.TotalSeconds, $TotalStartTime.TotalSeconds
    }
}
<#
.SYNOPSIS
  Calculate script life-time
.DESCRIPTION
  Calculate script life-time using StopWatch object
.EXAMPLE
  PS C:\> Get-ScriptStartTime -TestObject <InputAppObj>
.INPUTS
  Object with type InputAppObj
.OUTPUTS
  Startup time intervals
.NOTES
  General notes
#>
function Get-ScriptStartTime {
    [CmdletBinding()]
    param (
        $TestObject
    )
  
    begin {
        Write-Log "Start time calculating for for script..." -OnScreen
        $ResStartTime = 0
        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
  
    process {
        Start-Application -InputAppObject $TestObject
        $StopWatch.Stop()
    }
  
    end {
        Write-Log "End time calculating" -OnScreen
        $TestObject, $ResStartTime, $StopWatch.Elapsed.TotalSeconds
    }
}
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
        [PSCustomObject]$InputAppObj,
        [int]$NumberOfTests
    )
    
    begin {
        $StartupTimes = @()
        $ResDelay = @()
        If (-Not (Test-Path $InputAppObj.FilePath)) {
            $AppPath = $InputAppObj.FilePath
            Write-Log "${AppPath} was not found`n" -ErrorMessage
            break
        }
    }
    process {
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

## Control OnScreenlog
If ($Silent) {$Verbose = $false}

## Script parent directory
$ScriptCurentDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
If (-not (Test-Path $ScriptCurentDirectory)) {
    Write-Log "Execution fail: Something was wrong and script parent folder was not extracted" -ErrorMessage
    exit
}

## Specify path to CSV if it was not set in command line
If (-Not ($CSVOutput)) {
    $CSVOutput = "${ScriptCurentDirectory}\Results.csv"
}

# Validate Mandatory arguments, if they are missing enable DOS-Like menu
If ($FilePath) {
    $InputAppObjs += [InputAppObj]::new($FilePath, $Arguments, $WorkingDirectory)
}
ElseIf ($CSVInput) {
    $InputAppObjs = Get-CSVFile $CSVInput
}
ElseIf ($StartMenuItem) {
    $Shortcut = Select-StartMenuItem $CurentUserPrograms
    $InputAppObjs += [InputAppObj]::new($Shortcut.FullName, "", "")  
}
ElseIf ($StartMenu) {
    $InputAppObjs = Get-StartMenuItems
}
Else {
    $AppAnswer = Show-Menu -menuTitle "Choose test area" -menuItems @(
        "Single Application",
        "CSV File",
        "Complete System Start menu",
        "Specific StartMenu item"
    )
    switch ($AppAnswer) {
        "Single Application" {
            $FilePath = (Read-Host -Prompt "File").Trim("`"")
            $Arguments = Read-Host -Prompt "Arguments"
            $WorkingDirectory = Read-Host -Prompt "Working Directory"

            $InputAppObjs += [InputAppObj]::new($FilePath, $Arguments, $WorkingDirectory)
        }
        "CSV File" {
            $CSVInput = (Read-Host -Prompt "File").Trim("`"")

            $InputAppObjs = Get-CSVFile $CSVInput
        }
        "Complete System Start menu" {
            $InputAppObjs = Get-StartMenuItems
        }
        "Specific StartMenu item" {
            Clear-Host
            $Shortcut = Select-StartMenuItem $CurentUserPrograms
            $InputAppObjs += [InputAppObj]::new($Shortcut.FullName, "", "")  
        }
    }
    do {
        try {
            $NumberOfTests = Read-Host("Have many times test should be done? (0 - Exit script)")
            If ($NumberOfTests -eq "") {
                throw "Operation fail: No entry where provided.`n"
            }
            $NumberOfTests = [int]$NumberOfTests
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Log $ErrorMessage -ErrorMessage
        }
    } while ($NumberOfTests.GetType() -ne [int])
    If ($NumberOfTests -eq 0) {exit}
}
## PROCESS
ForEach ($InputAppObj in $InputAppObjs) {
    try {
        $TestResult = Measure-Startup -InputAppObj $InputAppObj -NumberOfTests $NumberOfTests
        If (!$Silent) { $TestResult | Format-List}
        New-CSVFile -Outputpath $CSVOutput -InputObject $TestResult | Out-Null
    }
    catch {
        Write-Log $InputAppObj.Name -ErrorMessage
        Write-Log $_.Exception.Message -ErrorMessage
        continue
    }
}
##  END
Exit