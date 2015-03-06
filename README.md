# PowerShellGuard
A Guard implementation for PowerShell

Examples:

```powershell
New-Guard -wait
```
Watch the current directory for changes and run Pester on any changes.

```powershell
New-Guard -Path .\lib\chef\knife\ -PathFilter '*.rb' -MonitorSubdirectories -TestCommand rspec -TestPath .\spec\unit\knife\
Wait-Guard
```
Watch all .rb files under .\lib\chef\knife and when they change, run the unit tests

```powershell
dir *.ps1 | New-Guard -TestPath {"./Tests/$($_.basename).Tests.ps1"}
Wait-Guard
```
Enumerate a directory and set up a test runner for each ps1 file based on its file name.  For example hello.p1 would have the test ./Tests/hello.Tests.ps1
