function New-Guard
{
  <#
    .SYNOPSIS
      Sets up a file system watcher to monitor files for changes, then run tests to verify things still work.
    .DESCRIPTION
      Sets up a file system watcher to monitor files for changes, then run tests to verify things still work.  The default test running is Pester, but any test runner can be supplied.
    .EXAMPLE
      New-Guard
      Watch the current directory for changes and run Pester on any changes.
    .EXAMPLE
      New-Guard -Path .\lib\chef\knife\ -PathFilter '*.rb' -MonitorSubdirectories -TestCommand rspec -TestPath .\spec\unit\knife\
      Watch all .rb files under .\lib\chef\knife and when they change, run the unit tests
    .EXAMPLE
      dir *.ps1 | New-Guard -TestPath {"./Tests/$($_.basename).Tests.ps1"}
      Enumerate a directory and set up a test runner for each ps1 file based on its file name.  For example hello.p1 would have the test ./Tests/hello.Tests.ps1
  #>
  [cmdletbinding()]
  param (
      # File or directory to monitor for changes
      [parameter(valuefrompipelinebypropertyname)]
      $Path = $pwd,
      # Monitor recursively?
      [switch]
      $MonitorSubdirectories,
      # Standard path filter syntax
      $PathFilter = '*.*',
      # Command to execute to run tests.  Defaults to Invoke-Pester.
      $TestCommand = 'Invoke-Pester',
      #File or directory containing the tests to run.
      [parameter(valuefrompipelinebypropertyname)]
      $TestPath,
      # Start monitoring running tests immediately.
      [switch]
      $Wait
  )
  begin
  {
    Set-GuardTestCommandQueue
  }
  process
  {
    $Path = (resolve-path $Path).path
    if (-not $psboundparameters.containskey('TestPath'))
    {
      $TestPath = $Path
    }
    else
    {
      $TestPath = (resolve-path $TestPath).Path
    }

    $Action = New-GuardFileSystemWatcherAction -TestCommand $TestCommand -TestPath $TestPath -PathFilter $PathFilter -IncludeSubdirectories:$MonitorSubdirectories
    New-GuardFileSystemWatcher -path $Path -action $Action
  }
  end
  {
    if ($Wait)
    {
      Wait-Guard
    }
  }
}

function Set-GuardTestCommandQueue
{
  if (-not ([appdomain]::CurrentDomain.GetData("GuardQueue")))
  {
    [appdomain]::CurrentDomain.SetData("GuardQueue", (new-object System.Collections.Queue))
  }
}


function New-GuardFileSystemWatcher
{
  param ($path, $action, [switch]$IncludeSubdirectories)

  $file = $null
  if ( -not (get-item $path).PSIsContainer )
  {
    $file = split-path -leaf $path
    $path = split-path $path
  }
  $FileSystemWatcher = new-object IO.FileSystemWatcher $path
  $FileSystemWatcher.IncludeSubdirectories = $IncludeSubdirectories

  if (-not [string]::isNullorempty($file))
  {
    $FileSystemWatcher.Filter = $File
  }

  $FileSystemWatcher.NotifyFilter = [IO.NotifyFilters]'LastWrite'
  if (-not $global:Guards)
  {
    $global:Guards = @()
  }
  $global:Guards += Register-ObjectEvent $FileSystemWatcher -EventName 'Changed' -Action $action
}

function New-GuardFileSystemWatcherAction
{
  param( $TestCommand, $TestPath, $PathFilter)

  $action = @"
`$Queue = [appdomain]::CurrentDomain.GetData('GuardQueue')
if ( (`$eventargs.fullname -notlike '*\.git') -and
  (`$eventargs.name -like '$PathFilter')   )
{
  `$TestCommandString = '$TestCommand $TestPath'
  `$array = `$queue.ToArray()
  if (`$array -notcontains `$TestCommandString)
  {
    `$queue.enqueue("`$TestCommandString")
  }
}
"@
  [scriptblock]::create($action)
}

function Wait-Guard
{
  <#
    .SYNOPSIS
      Blocks and checks a queue for new tests to run.
    .DESCRIPTION
      Blocks and checks a queue for new tests to run.
    .EXAMPLE
      Wait-Guard -SecondsToDelay 10
  #>
  [cmdletbinding()]
  param(
    #Number of seconds to wait between queue checks
    [int]
    $SecondsToDelay = 5
  )

  $Queue = [appdomain]::CurrentDomain.GetData('GuardQueue')
  do {
    if ($Queue.count -gt 0)
    {
      invoke-expression "$($Queue.dequeue())"
    }
    start-sleep -seconds $SecondsToDelay
  } while ($true)
}

function Remove-Guard
{
  <#
    .SYNOPSIS
      Removes all the existing guards from a PowerShell session.
    .DESCRIPTION
      Removes all the existing guards from a PowerShell session.
    .EXAMPLE
      Remove-Guard
  #>
  [cmdletbinding()]
  param()
  foreach ($Guard in $global:Guards)
  {
    Get-EventSubscriber $Guard.Name | Unregister-Event
    $Guard | Remove-Job
  }
  [appdomain]::CurrentDomain.SetData("GuardQueue", $null)
}

export-modulemember -function 'New-Guard', 'Wait-Guard', 'Remove-Guard'

