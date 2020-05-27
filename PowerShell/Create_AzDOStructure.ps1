Param
(
    [string]$Organization,
    [string]$Project,
    [string]$RepoName,
    [ValidateSet("DotNetCoreMVC")]
    [string]$ProjectType,
    [string]$BuildConfiguration,
    [string]$SonarCloudAccount,
    [string]$SonarCloudOrganization,
    [string]$SonarProjectKey,
    [string]$SonarProjectName,
    [string]$ReviewersDefault,
	[string]$ReviewersTeam,
    [string]$PAT
)


Function Check-RepositoryExist ($repository) {
    
        try{
            $ErrorActionPreference = 'Stop'
           $teste= az repos show --r $repository  #| ConvertFrom-Json# -ErrorAction:SilentlyContinue
           
            return $true
     
        }
        catch [System.Management.Automation.RemoteException] {
            Write-Host "Exception"
             return $false
        }
        catch{
            Write-Host "erro generico"
        }
    }

Function Add-GitRepo
{
    Param
    (
        [string] $repoName
    )
    Write-Host '===Criando repositório no Azure Repos'
 
    
    $createRepo = az repos create --name $repoName | ConvertFrom-Json

    Write-Host '======Remote URL: ' $createRepo.sshUrl
    Write-Host '======Repo ID: ' $createRepo.id
    return $createRepo
    return $createRepo
}

Function Set-GitPush
{
    Param
    (
        [string] $remoteUrl
    )
    Write-Host '===Push inicial de aplicaçãoo exemplo'
    git add .
    git commit -m 'Commit Inicial'
    git remote add origin $remoteUrl
    git push --set-upstream origin master --quiet
}

Function Set-Gitignore 
{
    Copy-Item -Path $gitignore -Destination $currentDir\$RepoName'\.gitignore'
    git add .
    git commit -m 'Primeiro commit no novo repositório e Inclusão do gitignore'
}


Function Add-ProjectTypeSolution
{
    Param
    (
        [string] $ProjectType,
        [string] $RepoName
    )

    Write-Host '===Criação do tipo de aplicação' $ProjectType


    switch ( $ProjectType )
    {
        'DotNetCoreMVC' 
        {
            dotnet new sln --name $RepoName
            dotnet new mvc --name $RepoName
            if($IsWindows)
            {
                dotnet sln add .\$RepoName\$RepoName.csproj
            }
            else
            {
              dotnet sln add ./$RepoName/$RepoName.csproj
            }

        }
    }
}

Function Set-BranchPolicy
{
    Param
    (
        [string] $repoId,
        [string] $pipelineId,
        [string] $pipeline,
        [string] $ReviewersTeam,
        [string] $ReviewersDefault
    )
    Write-Host '===Estabelecendo as policies da branch master'

    Write-Host '======Policy: Require a minimum number of reviewers'
    $policyApproverCount = az repos policy approver-count create --allow-downvotes false --blocking true --branch master --creator-vote-counts false --enabled true --minimum-approver-count 2 --repository-id $repoId --reset-on-source-push true | ConvertFrom-Json
    Write-Host '======' $policyApproverCount.createdDate
    
    Write-Host '======Policy: Checked for linked work items'
    $policyWorkItemLinking = az repos policy work-item-linking create --blocking true --branch master --enabled true --repository-id $repoId | ConvertFrom-Json
    Write-Host '======' $policyWorkItemLinking.createdDate 

    Write-Host '======Policy: Checked for comment resolution'
    $policyCommentRequired = az repos policy comment-required create --blocking true --branch master --enabled true --repository-id $repoId | ConvertFrom-Json
    Write-Host '======' $policyCommentRequired.createdDate

    Write-Host '======Policy: Automatically include code reviewers'
    $policyRequiredReviewerTeam = az repos policy required-reviewer create --blocking true --branch master --enabled true --message 'Including Code Reviewers' --repository-id $repoId --required-reviewer-ids $ReviewersTeam  | ConvertFrom-Json
    Write-Host '======' $policyRequiredReviewerTeam.createdDate
    $policyRequiredReviewerDevOps = az repos policy required-reviewer create --blocking true --branch master --enabled true --message 'Including Default Reviewers' --repository-id $repoId --required-reviewer-ids $ReviewersDefault  | ConvertFrom-Json
    Write-Host '======' $policyRequiredReviewerDevOps.createdDate

    Write-Host '======Policy: Build Validation'
    $policyBuildValidation = az repos policy build create --blocking true --branch master --build-definition-id $pipelineId --display-name $pipeline --enabled true --manual-queue-only false --queue-on-source-update-only false --repository-id $repoId --valid-duration 0 | ConvertFrom-Json
    Write-Host '======' $policyBuildValidation.createdDate
}

Function Add-Pipelines 
{
    Param
    (
        [string] $pipelinePrincipal,
        [string] $remoteUrl
    )
    Write-Host '===Criação de Pipeline Definitions'
    Write-Host '======Criação da Pipeline Definition Principal' $pipelinePrincipal
    $createPipelinePrincipal = az pipelines create --name $pipelinePrincipal --branch master --description 'Pipeline Principal' --repository $remoteUrl --repository-type 'tfsgit' --skip-first-run true --yaml-path '\esteiras\build-principal.yml' | ConvertFrom-Json
    Write-Host '======' $createPipelinePrincipal.createdDate
    Write-Host '======Enfileiramento da Pipeline Principal' $pipelinePrincipal
    $queuePipelinePrincipal = az pipelines build queue --definition-id $createPipelinePrincipal.id | ConvertFrom-Json
    Write-Host '======' $queuePipelinePrincipal.buildNumber

    
    return $createPipelinePrincipal.id
}

$urlConcat = "https://dev.azure.com/$($Organization)"

git config --global user.name "Automated Process"
git config --global user.email "automated@outlook.com"
Set-Location $PSScriptRoot
Write-Host $PSScriptRoot

$env:AZURE_DEVOPS_EXT_PAT = $PAT
Write-Host $urlConcat
#az devops login --org $urlConcat
echo $PAT | az devops login --org $urlConcat

Write-Host '===Configurando conexão com a organization e o Team Project'
az devops configure --defaults organization=$urlConcat project=$Project

#cria repo
$createRepo = Add-GitRepo -repoName $RepoName
$currentDir = $PSScriptRoot
$rootFolder = $PSScriptRoot.Replace('/PowerShell','').Replace('\PowerShell','')
$gitignore = "$($rootFolder)\.gitignore"

New-Item -Path $RepoName -ItemType Directory
Set-Location $currentDir\$RepoName



$FolderExists = Get-ChildItem $rootFolder -Filter $ProjectType -Recurse -Directory 


if($ProjectType -eq "DotNetCoreMVC"){
    $FolderProjectType = $FolderExists.FullName
    
}

#inicializa git repo
git init

#Inclui Gitignore
Set-Gitignore

New-Item -Path 'esteiras' -ItemType Directory
Copy-Item -Path "$FolderProjectType\*.yml" -Destination $currentDir\$RepoName'\esteiras' -Recurse


(Get-Content $currentDir\$RepoName'\esteiras\variables.yml') | Foreach-Object {
    $_ -replace '__BuildConfiguration__', $BuildConfiguration `
        -replace '__SonarCloudAccount__', $SonarCloudAccount `
        -replace '__SonarCloudOrganization__', $SonarCloudOrganization `
        -replace '__SonarProjectKey__', $SonarProjectKey `
        -replace '__SonarProjectName__', $SonarProjectName `
    } | Set-Content $currentDir\$RepoName'\esteiras\variables.yml'




Add-ProjectTypeSolution -ProjectType $ProjectType -RepoName $RepoName

#push no repositorio
Set-GitPush -remoteUrl $createRepo.sshUrl

#inclui o pipeline
$pipelinePrincipal = $RepoName 
$pipelineId = Add-Pipelines -pipelinePrincipal $pipelinePrincipal -remoteUrl $createRepo.remoteUrl

#aplica politicas de branch
Set-BranchPolicy -repoId $createRepo.id -ReviewersTeam $ReviewersTeam -ReviewersDefault $ReviewersDefault -pipelineId $pipelineId -pipeline $pipelinePrincipal