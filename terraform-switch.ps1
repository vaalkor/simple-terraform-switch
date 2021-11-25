param(
    [string]$Version,
    [string]$InstallDirectory="C:\Program Files\terraform",
    [switch]$ListVersions,
    [switch]$AdminCopy
)

$ErrorActionPreference = "Stop"

function Get-Versions {
    $html = (Invoke-WebRequest "https://releases.hashicorp.com/terraform/").Content
    (Select-String "(?<=>terraform_).*(?=<\/)" -input $html -AllMatches).Matches | ForEach-Object{$_.Value} | Sort-Object {(--$script:i)}
}

if($AdminCopy){
    mkdir -Force $InstallDirectory
    Copy-Item "~/.terraform-version-cache/terraform.exe" $InstallDirectory -Force
    exit 0
}

if($ListVersions){
    "============================="
    "Available terraform versions:"
    "============================="
    Get-Versions
    exit 0
}

if(-not $Version){
    "No `$Version parameter provided! Quitting."
    exit 1
}

$versions = Get-Versions

if(-not ($versions -contains $Version)){
    "`nVersion '$Version' not found. Run script with parameter -ListVersions to see available versions!.
(They are pulled from https://releases.hashicorp.com/terraform/)`n"
    exit 1
}

if(-not (Get-ChildItem "~/.terraform-version-cache" -Filter "terraform_$($Version)_windows_amd64.zip")){
    Invoke-WebRequest "https://releases.hashicorp.com/terraform/$($Version)/terraform_$($Version)_windows_amd64.zip" `
        -OutFile "~/.terraform-version-cache/terraform_$($Version)_windows_amd64.zip"
}

Expand-Archive "~/.terraform-version-cache/terraform_$($Version)_windows_amd64.zip" -DestinationPath "~/.terraform-version-cache" -Force

try{
    mkdir -Force $InstallDirectory
    Copy-Item "~/.terraform-version-cache/terraform.exe" $InstallDirectory
    "Copied terraform version $Version to $InstallDirectory"
}catch{
    if(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        throw
    }
    if($_.Exception.GetType() -ne [System.UnauthorizedAccessException]){
        throw
    }
    "We got an access denied exception when trying to copy the file. Relaunching script as admin..."
    
    # Relaunch as an elevated process:
    $process = Start-Process powershell.exe "-File",("$($MyInvocation.MyCommand.Path) --AdminCopy --InstallLocation '$InstallDirectory'") -Verb RunAs -PassThru -Wait
    if($process.ExitCode -eq 0){
        "Copied terraform version $Version to $InstallDirectory"
    }else{
        "Encountered some kind of error while trying to copy terraform version $Version to $InstallDirectory"
    }
}

