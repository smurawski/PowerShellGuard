Import-Module $PSScriptRoot/../PowerShellGuard.psm1 -Force

Describe 'PowerShellGuard' {
  InModuleScope 'PowerShellGuard' {
    context 'New-Guard' {
      mock Set-GuardCommandQueue -MockWith {} -Verifiable
      mock Resolve-Path -MockWith {[pscustomobject]@{ProviderPath = 'c:\test\test.ps1'}} -Verifiable
      mock Get-Item -ParameterFilter {$Path -like 'c:\test\test.ps1'} -MockWith {[pscustomobject]@{PSIsContainer=$false}}
      mock New-GuardFileSystemWatcherAction -MockWith {} -Verifiable
      mock New-GuardFileSystemWatcher -MockWith {} -Verifiable
      mock Wait-Guard -MockWith {}

      new-guard
      it 'calls Resolve-Path' {
        Assert-MockCalled -CommandName 'Resolve-Path'
      }
      it 'calls New-GuardFileSystemWatcherAction with default values' {
        Assert-MockCalled -CommandName New-GuardFileSystemWatcherAction -ParameterFilter {$TestCommand -eq 'Invoke-Pester' -and $TestPath -eq 'c:\test\test.ps1' }
      }
      it 'calls New-GuardFileSystemWatcherAction and sets up a file system watcher with the right path and filter' {
        Assert-MockCalled -CommandName 'New-GuardFileSystemWatcher' -ParameterFilter {
          $Path -eq 'c:\test' -and
          $PathFilter -eq 'test.ps1' -and
          $IncludeSubdirectories -eq $false
        }
      }
    }
  }
}