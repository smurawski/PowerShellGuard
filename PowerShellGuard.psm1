$script:Guards = @()

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
      [parameter(valuefrompipelinebypropertyname=$true)]
      $Path = $pwd,
      # Monitor recursively?
      [switch]
      $MonitorSubdirectories,
      # Standard path filter syntax
      $PathFilter,
      # Command to execute to run tests.  Defaults to Invoke-Pester.
      $TestCommand = 'Invoke-Pester',
      # File or directory containing the tests to run.
      [parameter(valuefrompipelinebypropertyname=$true)]
      $TestPath,
      # Start monitoring running tests immediately.
      [switch]
      $Wait
  )
  begin
  {
    Set-GuardCommandQueue
  }
  process
  {
    $Path = (resolve-path $Path).ProviderPath
    if (-not $psboundparameters.containskey('TestPath'))
    {
      $TestPath = $Path
    }
    else
    {
      $TestPath = (resolve-path $TestPath).ProviderPath
    }

    $GuardFileSystemWatcherActionParameters = @{
      TestCommand = $TestCommand
      TestPath = $TestPath
    }

    $FileSystemWatcherParameters = @{
      Path = $Path
      Action = New-GuardFileSystemWatcherAction @GuardFileSystemWatcherActionParameters
      IncludeSubdirectories = $MonitorSubdirectories
    }
    if ($psboundparameters.containskey('pathfilter'))
    {
      $FileSystemWatcherParameters.PathFilter = $PathFilter
    }
    elseif (-not (get-item $path).PSIsContainer)
    {
      $FileSystemWatcherParameters.PathFilter = split-path -leaf $path
      $FileSystemWatcherParameters.Path = split-path $path
    }
    New-GuardFileSystemWatcher @FileSystemWatcherParameters
  }
  end
  {
    if ($Wait)
    {
      Wait-Guard
    }
  }
}

function New-GuardFileSystemWatcherAction
{
  [cmdletbinding()]
  param( $TestCommand, $TestPath)

  $action = @"
`$Parameters = @{
  Path = `$eventargs.fullpath
  TestCommandString = '$TestCommand $TestPath'
}

Add-GuardQueueCommand @Parameters
"@
  [scriptblock]::create($action)
}

function New-GuardFileSystemWatcher
{
  [cmdletbinding()]
  param (
    $path,
    $action,
    $PathFilter,
    [switch]$IncludeSubdirectories)

  $file = $null

  Write-Verbose "Creating file system watcher for $path"
  $FileSystemWatcher = new-object IO.FileSystemWatcher $path
  Write-Verbose "`tInclude subdirectories: $IncludeSubdirectories"
  $FileSystemWatcher.IncludeSubdirectories = $IncludeSubdirectories
  if ($psboundparameters.containskey('PathFilter'))
  {
    Write-Verbose "`tPath filter: $PathFilter"
    $FileSystemWatcher.Filter = $PathFilter
  }
  Write-Verbose "`tUsing LastWrite as the notify filter."
  $FileSystemWatcher.NotifyFilter = [IO.NotifyFilters]'LastWrite'
  $script:Guards += Register-ObjectEvent $FileSystemWatcher -EventName 'Changed' -Action $action
}

function Add-GuardQueueCommand
{
  param (
    [string]
    $Path,
    [string]
    $TestCommandString
  )
  if ($Path -notlike '*\.git*')
  {
    Get-GuardQueue
    $array = $script:GuardQueue.ToArray()
    if ($array -notcontains $TestCommandString)
    {
      Write-Verbose "$TestCommandString"
      $script:GuardQueue.enqueue("$TestCommandString")
    }
  }
}



function Wait-Guard
{
  <#
    .SYNOPSIS
      Blocks and checks a queue for new tests to run.
    .DESCRIPTION
      Blocks and checks a queue for new tests to run.
    .EXAMPLE
      Wait-Guard -Seconds 10
      Starts blocking and checks the queue every 10 seconds.
  #>
  [cmdletbinding()]
  param(
    #Number of seconds to wait between queue checks
    [int]
    $Seconds = 5
  )

  Get-GuardQueue
  do
  {
    if ($script:GuardQueue.count -gt 0)
    {
      clear-host
      $Command = $script:GuardQueue.dequeue()
      Write-Verbose $Command
      invoke-expression "$Command"
    }
    start-sleep -seconds $Seconds
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
  foreach ($Guard in $script:Guards)
  {
    Get-EventSubscriber $Guard.Name | Unregister-Event
    $Guard | Remove-Job
  }
  Set-GuardCommandQueue -force
  $script:guards = @()
}

function Get-GuardQueue
{
  $script:GuardQueue = [appdomain]::CurrentDomain.GetData('GuardQueue')
}

function Get-GuardQueuePeek
{
  $script:GuardQueue.peek()
}

function Set-GuardCommandQueue
{
  param ([switch] $force)
  if ((-not (Get-GuardQueue)) -or $force)
  {
    [appdomain]::CurrentDomain.SetData("GuardQueue", (new-object System.Collections.Queue))
  }
}

