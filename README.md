# Cisco OSPF Monitor
### A simple Cisco IOS OSPF monitoring tool, with OSPF state transition email notifications and network graph visualization, including physics.
![Cisco OSPF Monitor Network Graph](https://github.com/Xorlent/Cisco-OSPF-Monitor/blob/main/OSPFGraph-Example.png)
Notes: Nodes (the bubbles) indicate the switch management IP address, edges (the lines) indicate the connecting router IP address.  These are usually, but not always the same value.  

### Background
As networks grow in size and complexity, overseeing the health of all links becomes increasingly challenging without specialized products.  This tool collects OSPF stats for every switch being monitored and emails a daily report of any OSPF neighbors that have had a state change since the last check, making it easy to see which links are problematic and in need of attention.  Beyond a Windows machine with PowerShell, this tool needs only one thing: plink.exe, a free, standalone executable utility by the creator of PuTTY.  No installs, no paid PowerShell modules, no TFTP server to set up and secure.

### Prerequisites
  - SSH support only.  If you have Telnet enabled on your switches, please address that.

### Installation
  - Download the latest Cisco-OSPF-Monitor release.
  - Right-click the downloaded ZIP, select Properties, click Unblock" and Ok.
  - Extract the ZIP to a secure folder of your choice.  I recommend C:\Scripts\OSPF\ -- the default configuration file entries are set to this path.
    - Only admins and the service account you plan to use if scheduling OSPF monitoring should have access to this location.
  - Read and understand the PuTTY/plink.exe license and usage restrictions, found here [https://www.chiark.greenend.org.uk/~sgtatham/putty/](https://www.chiark.greenend.org.uk/~sgtatham/putty/)

### Usage
  - Edit switches.txt so it includes the management IP of each switch to back up, one per line.
  - Edit CiscoOSPF-Config.xml
    - Set file paths as appropriate
    - Set authentication credentials for a switch user with "show ip ospf" permissions
    - Configure SMTP server and from/to email address settings
  - Open a PowerShell window.
  - Run FetchOSPFStats.ps1
    - Note, this script is intended to be run **once per day**
    - Create a daily scheduled task to run this script for hassle-free config backup/change management
  - Thank Simon Tatham!

> [!IMPORTANT]
> For the sake of convenience, the script will auto-trust/save the SSH key presented by the connected device.  
  > This could allow for a device to assume the IP of a switch and steal authentication credentials.
  > If you would rather not have the tool auto-trust SSH keys, just comment out the line below the following comment within FetchOSPFStats.ps1:  
    ```# Ensure the SSH host key has been saved/trusted```
