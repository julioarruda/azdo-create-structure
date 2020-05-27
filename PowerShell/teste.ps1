$currentDir = $PSScriptRoot
$rootFolder = $PSScriptRoot.Replace('/PowerShell','').Replace('\PowerShell','')
$gitignore = "$($rootFolder)\.gitignore"

Write-Host $currentDir
Write-Host $rootFolder
Write-Host $gitignore