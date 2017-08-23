param (
    [switch]$Syntax,
    [switch]$Unit,
    [switch]$Publish,
    [string]$GalleryUri,
    [string]$NugetApiKey
)

if ($Syntax) {
    Install-Module -Name PSScriptAnalyzer -F -Scope CurrentUser
    Invoke-ScriptAnalyzer –Path . –Recurse | 
        Where-Object severity -eq \"Warning\" | 
        ForEach-Object {
        Write-Host "##vso[task.logissue type=$($_.Severity);sourcepath=$($_.ScriptPath);linenumber=$($_.Line);columnnumber=$($_.Column);]$($_.Message)"
    }
}

if ($Unit) {
    Invoke-Pester ./test -EnableExit -Strict -OutputFile test-results.xml -OutputFormat NUnitXml -passthru
}

if ($Publish) {
    $PublishParameters = @{
        Path = "$pwd",
        NugetApiKey = $NugetApiKey,
        Force = $true
    }
    if (-not [string]::IsNullOrEmpty($GalleryUri)) {
        Register-PSRepository -Name CustomFeed -SourceLocation $GalleryUri -PublishLocation "$($GalleryUri.trim('/'))/package"
        $PublishParameters.Repository = 'CustomFeed'
    }
    Install-PackageProvider -Name NuGet -Force -ForceBootstrap -scope CurrentUser
    Publish-Module @PublishParameters
}