$ConfigFile = '.\CiscoOSPF-Config.xml'
$ConfigParams = [xml](get-content $ConfigFile)

# Initialize configuration variables from config xml file
$WorkingDir = $ConfigParams.configuration.backups.folder.value
$SwitchList = $ConfigParams.configuration.backups.switchlist.value
$PlinkExe = $ConfigParams.configuration.backups.plink.value
$SaveHostKey = $ConfigParams.configuration.backups.savehostkeycmd.value
$AuthUser = $ConfigParams.configuration.auth.user.value
$AuthPass = $ConfigParams.configuration.auth.password.value

$Today = (Get-Date).ToString("yy-MM-dd")
$TodaysBackupFolder = $WorkingDir + '\' + $Today

# If the OSPF output directory ($WorkingDir) does not exist, create it
if (-not(Test-Path -Path $WorkingDir -PathType Container)){New-Item -Path $WorkingDir -ItemType Directory}

# Create today's OSPF results sub-folder
if (-not(Test-Path -Path $TodaysBackupFolder -PathType Container)){New-Item -Path $TodaysBackupFolder -ItemType Directory}

# Open the switches.txt file
$SwitchFile = Get-Content $SwitchList

# Process each line (IP) in the switches.txt file 
foreach($Switch in $SwitchFile){
    $ConfigFile = $TodaysBackupFolder + '\' + $Switch + '.txt'
    if (Test-Path -Path $ConfigFile -PathType Leaf){
        Write-Host "SKIPPING: Today's backup already exists for $Switch in $ConfigFile" -ForegroundColor Yellow
        # OSPF neighbor detail file already exists, skip.  Could be a duplicate IP in the switch list.
    }
    else{ # No existing OSPF neighbor detail file in backup path.  Proceed.
        # Ensure the SSH host key has been saved/trusted
        & $SaveHostKey $PlinkExe $Switch *> $null
        $PlinkArgs = '-ssh -batch -l ' + $AuthUser + ' -pw ' + $AuthPass + ' ' + $Switch + ' show ip ospf neighbor detail'
        Write-Host "SAVING: $Switch to $ConfigFile" -ForegroundColor Green
        # Execute the OSPF neighbor detail command, saving a date stamped configuration backup file
        Start-Process -FilePath $PlinkExe -WorkingDirectory $WorkingDir -ArgumentList $PlinkArgs -PassThru -Wait -RedirectStandardOutput $ConfigFile
    }
}
& .\EmailOSPFChanges.ps1