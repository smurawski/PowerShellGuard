[![Build status](https://ci.appveyor.com/api/projects/status/e81t3vdaml1gxa9t/branch/master?svg=true)](https://ci.appveyor.com/project/smurawski/powershellguard/branch/master)

# PowerShellGuard
A Guard implementation for PowerShell

## Why PowerShellGuard?

### Streamlined workflow.
In conemu, I can dedicate a portion of my console window to just run tests.  Using PowerShellGuard, I can watch my source code and trigger test runs of as much of my test harness as I want.  This gives me fast feedback with minimal effort, making sure any changes that break existing behavior are noticed near when the changes are made.

# Examples:

```powershell
New-Guard -wait
```
Watch the files in the current directory for changes and run Pester on any changes.

```powershell
New-Guard -Path .\lib\chef\knife\ -PathFilter '*.rb' -Recurse -TestCommand rspec -TestPath .\spec\unit\knife\
Wait-Guard
```
Watch all .rb files under .\lib\chef\knife and when they change, run the unit tests using RSpec.

```powershell
dir *.ps1 | New-Guard -TestPath {"./Tests/$($_.basename).Tests.ps1"} -wait
```
Enumerate a directory and set up a test runner for each ps1 file based on its file name.  For example hello.ps1 would have the test ./Tests/hello.Tests.ps1

## Installing PowerShellGuard

You can install PowerShellGuard via PowerShellGet from the PowerShellGallery.

```powershell
Install-Module PowerShellGuard
```

If you want the development feed (built from master),

```powershell
Register-PSRepository -Name PowerShellGuard_current -SourceLocation 'https://ci.appveyor.com/nuget/PowerShellGuard/'
```

```powershell
Install-Module PowerShellGuard -Source PowerShellGuard_current
```

 
# Contributing

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
