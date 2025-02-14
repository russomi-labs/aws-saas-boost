#  Copyright (c) 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this
#  software and associated documentation files (the "Software"), to deal in the Software
#  without restriction, including without limitation the rights to use, copy, modify,
#  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
#  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#

$CURRENT_DIR = Split-Path $script:MyInvocation.MyCommand.Path

#Write-host "Current directory is $CURRENT_DIR"

# Check for installer
if (-not (Test-Path -Path ${CURRENT_DIR}\installer -PathType Container)) {

 Write-Host "Directory ${CURRENT_DIR}\installer not found"
 Exit 2
}

# Check for client\web
if (-not (Test-Path -Path ${CURRENT_DIR}\client\web -PathType Container)) {

 Write-Host "Directory ${CURRENT_DIR}\client\web not found"
 Exit 2
}

Function Test-CommandExists
{

 Param ($command)

 $oldPreference = $ErrorActionPreference

 $ErrorActionPreference = 'stop'

 try {if(Get-Command $command){RETURN $true}}

 Catch {Write-Host "$command does not exist"; RETURN $false}

 Finally {$ErrorActionPreference=$oldPreference}

} #end function test-CommandExists

Function Ensure-ExecutableExists
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [string]
        $Executable,

        [string]
        $MinimumVersion = ""
    )

    $CurrentVersion = (Get-Command -Name $Executable -ErrorAction Stop).Version
    #Write-Host "$($Executable) version $($CurrentVersion)"
    If ($MinimumVersion)
    {
        $RequiredVersion = [version]$MinimumVersion

        If ($CurrentVersion -lt $RequiredVersion)
        {
            Write-Host "$($Executable) version $($CurrentVersion) does not meet requirements"
	    RETURN $false
        }
	RETURN $true
    }
}


# check for java
If (-not (Ensure-ExecutableExists -Executable "java" -MinimumVersion "11.0.8")) {
  Write-host "java version 11 or higher must be installed"
  Exit 2
}

# check for yarn
If (-not (Test-CommandExists -command "yarn")) {
  Write-host "yarn version 1.22 or higher must be installed"
  Exit 2
}

# check for maven
If (-not (Test-CommandExists -command "mvn")) {
  Write-host "maven must be installed"
  Exit 2
}

# check for node
If (-not (Test-CommandExists -command "node")) {
  Write-host "node version 14 must be installed"
  Exit 2
}

 
$AWS_REGION = (((aws configure list | Select-String -Pattern "region") -split "\s+")[2])
Write-host "AWS Region = $AWS_REGION"
if ("X$AWS_REGION" -eq "X" ) {
  echo "AWS_REGION not set, check your aws profile or set AWS_DEFAULT_REGION"
  Exit 2
}


cd installer
Write-host "Building Java Installer with maven"
mvn 2>&1 | out-null
if ( -not $? ) {
 Write-host "Error with build of Java installer for SaaS Boost"
 Exit 2
}
Write-host "Java Installer build completed"


cd ${CURRENT_DIR}\client\web
Write-host "Downloading dependencies for React Web App, please be patient"
yarn *>&1 | out-null
if ( -not $? ) {
  Write-host "Error with yarn build for dependencies of React Web App. Check node version per documentation."
  Exit 2
 }
Write-host "Download dependencies completed for React Web App"

cd $CURRENT_DIR
Write-host "Launch Java Installer for SaaS Boost"

$env:AWS_REGION = $AWS_REGION

java "-Djava.util.logging.config.file=logging.properties" -jar ${CURRENT_DIR}\installer\target\SaaSBoostInstall-1.0.0-shaded.jar
