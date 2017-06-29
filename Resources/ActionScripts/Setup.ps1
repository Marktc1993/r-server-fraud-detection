<#
.SYNOPSIS
Powershell script for setting up the solution template. 

.DESCRIPTION
This script checks out the solution from github and deploys it to SQL Server on the local Data Science VM (DSVM).

.WARNING: This script is only meant to be run from the solution template deployment process.

.PARAMETER serverName
Name of the server with SQL Server with R Services (this is the DSVM server)

.PARAMETER baseurl
url from which to download data files

.PARAMETER username
login username for the server

.PARAMETER password
login password for the server

.PARAMETER sqlUsername
User to create in SQL Server

.PARAMETER sqlPassword
Password for the SQL User

#>
[CmdletBinding()]
param(
[parameter(Mandatory=$true, Position=1, ParameterSetName = "LCR")]
[ValidateNotNullOrEmpty()] 
[string]$serverName,

[parameter(Mandatory=$true, Position=2, ParameterSetName = "LCR")]
[ValidateNotNullOrEmpty()] 
[string]$baseurl,

[parameter(Mandatory=$true, Position=3, ParameterSetName = "LCR")]
[ValidateNotNullOrEmpty()] 
[string]$username,

[parameter(Mandatory=$true, Position=4, ParameterSetName = "LCR")]
[ValidateNotNullOrEmpty()] 
[string]$password,

[parameter(Mandatory=$true, Position=5, ParameterSetName = "LCR")]
[ValidateNotNullOrEmpty()] 
[string]$sqlUsername,

[parameter(Mandatory=$true, Position=6, ParameterSetName = "LCR")]
[ValidateNotNullOrEmpty()] 
[string]$sqlPassword
)

$startTime= Get-Date
Write-Host "Start time for setup is:" $startTime
$originalLocation = Get-Location
# This is the directory for the data/code download
$solutionTemplateSetupDir = "FraudDetectionSolution"
$solutionTemplateSetupPath = "D:\" + $solutionTemplateSetupDir
$dataDir = "Data"
$dataDirPath = $solutionTemplateSetupPath + "\" + $dataDir
$reportsDir = "Reports"
$reportsDirPath = $solutionTemplateSetupPath + "\" + $reportsDir

New-Item -Path "D:\" -Name $solutionTemplateSetupDir -ItemType directory -force
New-Item -Path $solutionTemplateSetupPath -Name $dataDir -ItemType directory -force
New-Item -Path $solutionTemplateSetupPath -Name $reportsDir -ItemType directory -force

$checkoutDir = "Source"

$setupLog = $solutionTemplateSetupPath + "\setup_log.txt"
Start-Transcript -Path $setupLog -Append

# cd $dataDirPath

# # List of data files to be downloaded
# $dataList = "Loan_Prod", "Borrower_Prod"
# $dataExtn = ".csv"
# # $hashExtn = ".hash"
# foreach ($dataFile in $dataList)
# {
#     $down = $baseurl + '/' + $dataFile + $dataExtn
#     Write-Host -ForeGroundColor 'magenta' "Downloading file $down..."
#     Start-BitsTransfer -Source $down  
# }



#checkout setup scripts/code from github
cd $solutionTemplateSetupPath
if (Test-Path $checkoutDir)
{
    Remove-Item $checkoutDir -Force -Recurse
}

git clone -n https://github.com/Microsoft/r-server-fraud-detection $checkoutDir
cd $checkoutDir
git checkout dev

$sqlsolutionCodePath = $solutionTemplateSetupPath + "\" + $checkoutDir + "\SQLR"
$sqlsolutionResourcePath = $solutionTemplateSetupPath + "\" + $checkoutDir + "\Resources\ActionScripts"
$helpShortCutFilePath = $sqlsolutionResourcePath + "\frauddetection_Help.url"
cd $sqlsolutionResourcePath


$passwords = $password | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$serverName\$username", $passwords)
$command1 = "runDB.ps1"
$command2 ="setupHelp.ps1"

Enable-PSRemoting -Force
Invoke-Command  -Credential $credential -ComputerName $serverName -FilePath $command1 -ArgumentList $dataDirPath, $sqlsolutionCodePath, $sqlUsername, $sqlPassword
Invoke-Command  -Credential $credential -ComputerName $serverName -FilePath $command2 -ArgumentList $helpShortCutFilePath, $solutionTemplateSetupPath
Disable-PSRemoting -Force

Write-Host -ForeGroundColor magenta "Installing latest Power BI..."
# Download PowerBI Desktop installer
Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?LinkId=521662&clcid=0x409" -Destination powerbi-desktop.msi

# Silently install PowerBI Desktop
msiexec.exe /i powerbi-desktop.msi /qn /norestart  ACCEPT_EULA=1

if (!$?)
{
    Write-Host -ForeGroundColor Red "Error installing Power BI Desktop. Please install latest Power BI manually."
}
cd $originalLocation.Path
$endTime= Get-Date
$totalTime = $endTime - $startTime
Write-Host "Finished running setup at " $endTime
Write-Host "Total time for setup:" $totalTime
Stop-Transcript

