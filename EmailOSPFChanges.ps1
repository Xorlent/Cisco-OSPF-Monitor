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

# Set up HTML components for graph output
$StaticHead = @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>OSPF Network Visualizer</title>

    <script
      type="text/javascript"
      src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js">
    </script>

    <style type="text/css">
      #mynetwork {
        width: 100%;
        height: 800px;
        border: 1px solid lightgray;
      }
    </style>
  </head>
  <body>
    <p>OSPF Network Diagram.</p>
    <div>
      <label>
        <input type="checkbox" id="physics" name="physics" value="physics" />
        Physics Off
      </label>
    </div>
    <div id="mynetwork"></div>

    <script type="text/javascript">

'@

$NodeData = '      var nodes = new vis.DataSet([' + "`r`n"
$NodeEntryOpen = '        { id: '
$NodeEntryMid = ', label: "'
$NodeEntryEnd = '" },' + "`r`n"
$NodeClose = '      ]);' + "`r`n"

$EdgeData = '      var edges = new vis.DataSet([' + "`r`n"
$EdgeEntryOpen = '        { from: '
$EdgeEntryMid = ', to: '
$NodeEntryMid2 = ', label: "'
$EdgeEntryEnd = '" , arrows: "to" },' + "`r`n"
$EdgeClose = '      ]);' + "`r`n"

$StaticFoot = @'
      // create a network
      var container = document.getElementById("mynetwork");
      var data = {
        nodes: nodes,
        edges: edges,
      };
      var options = {};
      var network = new vis.Network(container, data, options);

      const physicsCheckbox = document.querySelector("#physics");
      physicsCheckbox.addEventListener("change", () => {
        if (physicsCheckbox.checked) {
          options = { physics: false,
            "edges": {
              "smooth": {
                "type": "curvedCW",
                "roundness": 0.25
              }
            }
          };
          network = new vis.Network(container, data, options);
        }
        else {
          options = { };
          network = new vis.Network(container, data, options);
        }
      });
    </script>
    Note: Nodes (the bubbles) indicate the switch management IP address, edges (the lines) indicate the connecting router IP address. These are usually, but not always the same value.
  </body>
</html>
'@

# Open the config file with the list of switch IPs
$SwitchFile = Get-Content $SwitchList

# Start building the network graph HTML file.
$OSPFHTML = $StaticHead + $NodeData

# Initialize variables for the foreach loop.
$ValidRecord = 0
$SwitchID = 0
$NeighborList = @()
$NodeEntry = ""
$EdgeEntry = $EdgeData
$SwitchDB = @("zero")

# Process each switch within the switch.txt file to build the OSPF neighbor list and graph HTML...
foreach($Switch in $SwitchFile){
    # Router ID file
    $RIDFile = $TodaysBackupFolder + '\' + $Switch + '-RID.txt'
    # Neighbor detail file
    $ConfigFile = $TodaysBackupFolder + '\' + $Switch + '.txt'
    # SwitchID keeps track of the switch numeric index we use to populate the graph HTML.
    $SwitchID++
    # Add this switch to the graph HTML node list
    $NodeEntry = $NodeEntry + $NodeEntryOpen + $SwitchID + $NodeEntryMid + $Switch + $NodeEntryEnd

    foreach($line in Get-Content $RIDFile -Encoding UTF8 ) {
        if($line -match 'OSPF Router with ID '){
            # Add this switch router ID to the list of switches that we then scan to find relationships when processing neighbor data.
            $line = $line.TrimStart(" ")
            $startRID = $line.IndexOf('(')
            $endRID = $line.IndexOf(')')
            $SwitchDB += $line.Substring(($startRID + 1), ($endRID - $startRID - 1))
            # This switch is a OSPF router.  Mark the record so we process the neighbor detail file.
            $ValidRecord = 1
            # No need to process the rest of the file, we already got the router ID.
            break
        }
    }
    if($ValidRecord -eq 1){ # If we found a router ID for this switch, let's process its neighbors.
        foreach($line in Get-Content $ConfigFile -Encoding UTF8 ) {
            if($line -match ", interface address "){ # For each neighbor, grab the IP address and add it to $NeighborList.
                $line = $line.TrimStart(" ")
                $start = $line.IndexOf(" ")
                $end = $line.IndexOf(",")
                $NeighborIP = $line.Substring(($start + 1), ($end - $start - 1))
                $NeighborList += $SwitchID.ToString() + "," + $NeighborIP
            }
        }
    # Reset the $ValidRecord flag in preparation for the next switch files.
    $ValidRecord = 0
    }
    else{
    # Insert a placeholder value so we keep the array index consistent with $SwitchID
        $SwitchDB += "zero"
    }
}

$EdgeLabel = ""
# Process the neighbor list, converting neighbor IP addresses to the ID number of the Node in the HTML JSON.
foreach($Neighbor in $NeighborList){
    # NeighborID will be -1 if we don't find a match -- this could happen if a switch is missing from the switch.txt file.
    $NeighborID = -1
    # NeighborList is CSV containing neighbor relationships: $SwitchID,$NeighborIP(router ID).
    $ParsedNeighbors = $Neighbor.Split(",")
    $RouterID = $ParsedNeighbors[1]
    $ParsedNeighbors[1] = $ParsedNeighbors[1] + '$'
    for($i=0;$i-le $SwitchDB.length-1;$i++){
        # Look for the neighbor IP in the $SwitchDB, which contains all of the router IDs.
        if($SwitchDB[$i] -match $ParsedNeighbors[1]){
            $NeighborID = $i
        }
    }
    if($NeighborID -ne -1){
        # If we found the neighbor in $SwitchDB (router IDs), then create an edge record which connects switches on the graph.
        $EdgeEntry = $EdgeEntry + $EdgeEntryOpen + $ParsedNeighbors[0] + $EdgeEntryMid + $NeighborID + $NodeEntryMid2 + $RouterID + $EdgeEntryEnd
    }
}

# Terminate the JSON for nodes and edges
$NodeEntry = $NodeEntry + $NodeClose
$EdgeEntry = $EdgeEntry + $EdgeClose

# Build the final HTML file
$GraphHTML = $OSPFHTML + $NodeEntry + $EdgeEntry + $StaticFoot

#Write the OSPF visual graph HTML in today's backup folder
$GraphFile = $TodaysBackupFolder + '\OSPFGraph.html'
$GraphHTML | Out-File $GraphFile

# Initialize variables for the foreach loop.
$FailCount = 0
$FailList = "SCRIPT EXECUTION COMPLETED: $CurrentTime`r`nOSPF GRAPH ATTACHED TO THIS EMAIL.`r`n`r`n"

# Parse each OSPF detail statement output and log any transitons within the past 24 hours.
foreach($Switch in $SwitchFile){
    # Neighbor detail file
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

#Write the recent OSPF transition results to a text file in today's backup folder
$FailFile = $TodaysBackupFolder + '\OSPFChanges.txt'
$FailList | Out-File $FailFile

# If OSPF state changed on any switches, generate an email digest with the neighbor details and attach an OSPF graph
if(($SMTPServer -ne "smtp.hostname.here") -and $FailCount -gt 0){
    Send-MailMessage -Attachments $GraphFile -From "Cisco OSPF $FromAddress" -To $ToAddress -Subject 'Recent OSPF State Changes' -Body $FailList -SmtpServer $SMTPServer -Port $SMTPPort
}
