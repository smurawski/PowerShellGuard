param (
    [switch]$Syntax,
    [switch]$Unit,
    [switch]$Publish,
    [switch]$Version,
    [switch]$Promote,
    [string]$GalleryUri,
    [string]$NugetApiKey,
    [int]$Build
)
function CreateModuleDir ($ModuleDir) {
    mkdir $ModuleDir -Force | Out-Null
}

if ($Syntax) {
    Install-Module -Name PSScriptAnalyzer -F -Scope CurrentUser
    Invoke-ScriptAnalyzer -Path . -Recurse | 
        Where-Object severity -eq \"Warning\" | 
        ForEach-Object {
        Write-Host "##vso[task.logissue type=$($_.Severity);sourcepath=$($_.ScriptPath);linenumber=$($_.Line);columnnumber=$($_.Column);]$($_.Message)"
    }
}

if ($Unit) {
    Invoke-Pester ./test -EnableExit -Strict -OutputFile test-results.xml -OutputFormat NUnitXml -passthru
}

if ($Version) {
    $ModuleDir = "$pwd/Release/PowerShellGuard"
    CreateModuleDir $ModuleDir    
    get-content '.\PowerShellGuard.psd1' | 
        ForEach-Object { $_ -replace '{BUILDNUMBER}', $Build} |
        set-content -Encoding UTF8 -Path $ModuleDir/PowerShellGuard.psd1
}

if ($Publish) {
    $ModuleDir = "$pwd/Release/PowerShellGuard"
    CreateModuleDir $ModuleDir    
    Copy-Item './PowerShellGuard.psm1', './LICENSE', './README.md' -Destination $ModuleDir 

    $PublishParameters = @{
        Path        = $ModuleDir
        NugetApiKey = $NugetApiKey
        Force       = $true
    }
    if (-not [string]::IsNullOrEmpty($GalleryUri)) {
        Register-PSRepository -Name CustomFeed -SourceLocation $GalleryUri -PublishLocation "$($GalleryUri.trim('/'))/package"
        $PublishParameters.Repository = 'CustomFeed'
    }
    Install-PackageProvider -Name NuGet -Force -ForceBootstrap -scope CurrentUser
    Publish-Module @PublishParameters
}

if ($Promote) {
    $ModuleDir = "$pwd/Release/PowerShellGuard"
    CreateModuleDir $ModuleDir 

    if (-not [string]::IsNullOrEmpty($GalleryUri)) {
        Register-PSRepository -Name CustomFeed -SourceLocation $GalleryUri -PublishLocation "$($GalleryUri.trim('/'))/package"
        Save-Module PowershellGuard -Repository CustomFeed -Path $pwd/Release
    }
    $PublishParameters = @{
        Path        = $ModuleDir
        NugetApiKey = $NugetApiKey
        Force       = $true
        Repository  = 'PSGallery'
    }
    
    Install-PackageProvider -Name NuGet -Force -ForceBootstrap -scope CurrentUser
    Publish-Module @PublishParameters
}
