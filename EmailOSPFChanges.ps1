$ConfigFile = '.\CiscoOSPF-Config.xml'
$ConfigParams = [xml](get-content $ConfigFile)

# Initialize configuration variables from config xml file
$WorkingDir = $ConfigParams.configuration.backups.folder.value
$SwitchList = $ConfigParams.configuration.backups.switchlist.value
$SMTPServer = $ConfigParams.configuration.smtp.fqdn.value
$SMTPPort = $ConfigParams.configuration.smtp.port.value
$FromAddress = $ConfigParams.configuration.smtp.fromemail.value
$ToAddress = $ConfigParams.configuration.smtp.toemail.value

$Today = (Get-Date).ToString("yy-MM-dd")
$TodaysBackupFolder = $WorkingDir + '\' + $Today

$CurrentTime = (Get-Date).ToString()

# Verify existence of today's OSPF logs sub-folder
if (-not(Test-Path -Path $TodaysBackupFolder -PathType Container)){
    Write-Output "Backup has not yet been performed today.  Exiting."
    exit
}

# Open the config file with the list of switch IPs
$SwitchFile = Get-Content $SwitchList
$FailCount = 0
$FailList = "SCRIPT EXECUTION COMPLETED: $CurrentTime`r`n`r`n"

# Parse each OSPF detail statement output and log any transitons within the past 24 hours.
foreach($Switch in $SwitchFile){
    $ConfigFile = $TodaysBackupFolder + '\' + $Switch + '.txt'

    $RecordMarker = 0
    $OSPFTransitioned = 0
    $CurrentRecord = ""

    foreach($line in Get-Content $ConfigFile -Encoding UTF8 ) {
        if($line -match ", interface address "){
            $CurrentRecord = $line + "`r`n"
            $RecordMarker = 1
        }
        else{
            if($RecordMarker -gt 0){
                if($line -notmatch "Last retransmission scan time is "){
                    $CurrentRecord = $CurrentRecord + $line + "`r`n"
                    if($line -match "Neighbor is up for [0-2][0-9]:[0-5][0-9]:[0-5][0-9]"){$OSPFTransitioned = 1}
                }
                else{
                    $CurrentRecord = $CurrentRecord + $line + "`r`n"
                    $RecordMarker = 0
                    if($OSPFTransitioned -eq 1){
                        $FailList = $FailList + "!!!!!!!!!!!!!!!!!!!!!! BEGIN OSPF DETAIL FOR SWITCH " + $Switch + " !!!!!!!!!!!!!!!!!!!!!!`r`n"
                        $FailList = $FailList + $CurrentRecord
                        $FailList = $FailList + "!!!!!!!!!!!!!!!!!!!!!!  END OSPF DETAIL FOR SWITCH " + $Switch + "  !!!!!!!!!!!!!!!!!!!!!!`r`n`r`n`r`n"
                        $FailCount++
                        $OSPFTransitioned = 0
                        }
                }
            }
        }
    }
}

#Write the OSPF results to a text file in today's backup folder
$FailFile = $TodaysBackupFolder + '\OSPFChanges.txt'
$FailList | Out-File $FailFile

# If OSPF state changed on any switches, generate an email digest with the neighbor details
if(($SMTPServer -ne "smtp.hostname.here") -and $FailCount -gt 0){
    Send-MailMessage -From "Cisco OSPF $FromAddress" -To $ToAddress -Subject 'Recent OSPF State Changes' -Body $FailList -SmtpServer $SMTPServer -Port $SMTPPort
}