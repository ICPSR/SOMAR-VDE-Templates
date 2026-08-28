Param(
    [Parameter(Mandatory=$false)][String]$TagOverride
)

# EC2-PowerState_GUI.ps1

#This script is intended for use in the Precision Health AWS HIPAA enclave to control power state of "worker node" EC2 instances.
#An appropriate set of tagging, IAM, machine policies, network and filtering configurations is required in addition to staging the
#script and AWS PowerShell modules on an appropriate bastion host to be executed from.  Reference project documentation for specifics.

# ########## ########## ########## ########## ########## ########## ########## ########## ########## ########## ########## ########## 

$ErrorActionPreference = "SilentlyContinue"

Function Get-MyEC2s {
#This function queries AWS for EC2 instances in the calling machine's region which match an 'mcomm' or alternately specified EC2 tag

    Param(
        [Parameter(Mandatory=$True)][String]$Region,
        [Parameter(Mandatory=$True)][String]$TagValue
    )

    #if alternate tage was supplied use that, otherwise default to mcomm
    if ($global:AlternateTag) {
        $Tag = $global:AlternateTag.split(":")[0]
    }
    else {
        $Tag="mcomm"
    }

    #Query EC2 instances
    #$EC2instances = (get-ec2instance -filter @{name="tag:$($Tag)"; values="$TagValue"} -region $Region).instances |select-object Tags,InstanceId,Platform,PrivateIpAddress,State,InstanceType
    $EC2instances = (get-ec2instance -filter @{name="tag:$($Tag)"; values="$TagValue"} -region $Region).instances |select-object Tags,InstanceId,State,LaunchTime,PrivateIpAddress,Platform
    
    #Array to host hashtables
    $EC2Raw = @()

    #For each discoverd EC2 create a hash of attributes and add to the raw array
    $EC2instances | % {

        $TempHash = @{}
        $TempName = ($_.Tags | Where-Object Key -eq 'Name').value
        $TempPlatform = $_.Platform

        if ($TempName.length -lt 1) { $TempName = "no_name" }
        if ($TempPlatform.length -lt 1) { $TempPlatform = "Linux" }

        $TempHash.set_item("Name","$($TempName) [$($_.PrivateIpAddress)] $($TempPlatform)")
        $TempHash.set_item("State",$_.State.Name.value)
        $TempHash.set_item("Id",$_.InstanceID)
        #$TempHash.set_item("InstanceType",$_.InstanceType)
        #$TempHash.set_item("Platform",$_.Platform)
        #$TempHash.set_item("PrivateIpAddress",$_.PrivateIpAddress)
        $TempHash.set_item("LaunchTime",$_.LaunchTime)
        
        #only Windows systems contain the platform attribute, so...
        if ($_.Platform -eq $null) { $_.Platform = "Linux" }
        $TempHash.set_item("Platform",$_.Platform)

        #if an alternate tag was supplied use that in place of the mcomm tag, overload the mcomm attribute with the alternate
        if ($global:AlternateTag) {
            $TempHash.set_item("mcomm",($_.Tags | Where-Object Key -ieq $AltTag).value)
        }      
        else {
            $TempHash.set_item("mcomm",($_.Tags | Where-Object Key -ieq "mcomm").value)
        }

        #if this host does not have a tag of "power_protect:true" add it to the list
        if (!($(($_.tags | where-object key -ieq "power_protect").value) -ieq "true")) {
            $EC2Raw += $TempHash
        }
    }

return $EC2Raw

}

Function Create-EC2List {
#This function creates a list of EC2 instances for a text based selection menu and handles user selected power control actions

    #pull some info from the calling machine's metadata
    $InstanceID = (Invoke-WebRequest "http://169.254.169.254/latest/meta-data/instance-id").content
    $Region = (Invoke-WebRequest "http://169.254.169.254/latest/meta-data/placement/region").content

    #if alternate tag was supplied handle it
    if ($global:AlternateTag) {
        $Tag = $global:AlternateTag.split(":")[0]
        $TagValue = $global:AlternateTag.split(":")[1]

        if ($TagValue -eq $null) {
            #write-host "Error: no value specified for supplied alternate tag '$Tag', exiting."
            #write-host "Instance id: $($InstanceID)"
            #[console]::cursorvisible = $true
            #exit 1
        }
    }
    else {
        #Get the calling machine's mcomm tag value, we'll use this as the default EC2 searching filter 
        $TagValue = ((get-ec2instance $InstanceID -region $Region).instances.tags | where-object Key -eq "mcomm").value

       if ($TagValue -eq $null) {
            #write-host "Error: No 'mcomm' tag applied to this instance id, exiting."
            #write-host "Instance id: $($InstanceID)"
            #[console]::cursorvisible = $true
            #exit 1
        }
    }

    #Get the raw EC2 data & prune the null results from the data set
    $EC2List = Get-MyEC2s $Region $TagValue | sort-object -Property {$_.name}
    $EC2List = $EC2List.where({$null -ne $_})

    #format the list so it looks nicer
    $EC2ListFormatted = @()
    $EC2List | % {
        $EC2ListFormatted += "[$($_.get_item('State'))]`t$($_.get_item('Id'))`t$($_.get_item('Name'))`t$($_.get_item('LaunchTime'))"
    }
    return $EC2ListFormatted
}

# ########## ########## ########## ########## ########## ########## ########## ########## ########## ########## ########## ########## 
#The script begins here

write-host "Importing AWS modules -- this may take some time..."

#Import requried AWS modules.  Edit according to documentation if this code is to run from a non-internet control machine
Import-module aws.tools.common #-verbose
Import-Module aws.tools.ec2 #-verbose

#create an event log source for this script
new-eventlog -logname "Application" -Source "EC2 Powerstate Script" -ErrorAction SilentlyContinue

#If instantiated with a tag override stash that in a global var so functions have access to it
if ($TagOverride) {
    $global:AlternateTag = $TagOverride
    $TitleBar = "AWS EC2 Power State Control -- alternate tag '$Tag' target: $($TagOverride)"
}
else {
    $InstanceID = (Invoke-WebRequest "http://169.254.169.254/latest/meta-data/instance-id").content
    $TagValue = ((get-ec2instance $InstanceID -region $Region).instances.tags | where-object Key -eq "mcomm").value
    $TitleBar = "AWS EC2 Power State Control -- mcomm tag target: $($TagValue)"
}

#get a list of filtered EC2 instances matching our tags
$EC2List = Create-EC2List

# Set up the gui form ===========================================================
 
#[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
#[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

$Form = New-Object System.Windows.Forms.Form
$Form.Text = $TitleBar
$Form.size = New-Object System.Drawing.size(792,389)
$Form.StartPosition = "CenterScreen"
$Form.MinimizeBox = $false
$Form.MaximizeBox = $false
#$Form.Font = New-Object System.Drawing.Font("Consolas",11,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$Form.FormBorderStyle = "FixedDialog"

$ListBox = New-Object System.Windows.Forms.ListBox
$ListBox.Location = New-Object System.Drawing.size(3,3)
$ListBox.size = New-Object System.Drawing.size(680,350)
$ListBox.Font = New-Object System.Drawing.Font("Consolas",11,[System.Drawing.FontStyle]::Regular)
$ListBox.TabStop = $true
$ListBox.TabIndex = 1
$Form.Controls.Add($ListBox)

$EC2List | % {
    #vars so we don't have to calculate this twice
    $EC2State = $_.split("`t")[0]
    $EC2Id = $_.split("`t")[1]
    $Ec2Name = $_.split("`t")[2]
    
    if ($EC2State -eq "[running]") {
        $Ec2LaunchTime = $_.split("`t")[3]
        $Uptime = new-timespan $Ec2LaunchTime $(get-date)
        $Ec2LaunchTime = "Up $(([string]($Uptime.Days)).PadLeft(4,'0')):$(([string]($Uptime.Hours)).PadLeft(2,'0')):$(([string]($Uptime.Minutes)).PadLeft(2,'0')):$(([string]($Uptime.Seconds)).PadLeft(2,'0'))"
        $null
    }
    else {
        $Ec2LaunchTime = "-               "
        #$Ec2LaunchTime = "Up dddd:hh:mm:ss"
    }

    $EC2Hash.Add($Ec2Name,$EC2Id)
    $EC2HashID.Add($EC2Id,$Ec2Name)

    $ListBox.Items.Add("$($EC2State)`t$($EC2LaunchTime)`t$($EC2Name)`t`t`t`t`t`t`t$($EC2Id)")| out-null
}

$ListBox.Add_SelectedIndexChanged({
    $PowerButton.Enabled = $true

    #$IsWindows = ($ListBox.SelectedItem).split("`t")[2] -replace '.*\[(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)\] (.*)','$2' -match "Windows"
    $IsRunning = ($ListBox.SelectedItem).split("`t")[0] -eq "[running]"

    #if running & windows, enable rdp button
    #if ($IsRunning -and $IsWindows) {
    if ($IsRunning) {
        $RDPButton.Enabled = $true
    }
    else {
        $RDPButton.Enabled = $false
    }

    $global:PreviouslySelectedID = ($ListBox.SelectedItem).split("`t")[-1]
})

#add buttons   ===============================================
#power state button
$PowerButton = New-Object System.Windows.Forms.Button
$PowerButton.Location = New-Object System.Drawing.size(689,5)
$PowerButton.size = New-Object System.Drawing.size(80,20)
$PowerButton.Text = "Power"
$PowerButton.Enabled = $false
$PowerButton.TabStop = $true
$PowerButton.TabIndex = 2

$PowerButton.Add_Click({
    #stop the refrsh timer
    $Timer.stop()
    $ActionTaken = $false

    #set some vars
    $SelectedServer = ($ListBox.SelectedItem).split("`t")[2]
    #$ServerID = $EC2Hash.$SelectedServer
    $ServerID = ($ListBox.SelectedItem).split("`t")[-1]
    $ServerState = ($ListBox.SelectedItem).split("`t")[0] -replace "\W"
    
    #Depending on current EC2 state offer actions
    switch ($ServerState) {
        "running"    {$ReturnCode = [System.Windows.Forms.MessageBox]::Show("Power OFF host $($SelectedServer) ($($ServerID))?","Confirm Power OFF","okcancel","stop")
                        if ($ReturnCode -eq [System.Windows.Forms.DialogResult]::OK) {
                            try {
                                Stop-EC2Instance -InstanceId $ServerID
                                Write-EventLog -LogName "Application" -source "EC2 PowerState Script" -EventId 100 -EntryType Information -Message "User $($env:UserName) sucessfully issued an EC2 stop command for host $($SelectedServer) ($($ServerID))"
                                $ActionTaken = $true
                            }
                            catch {
                                if ($error -match "not authorized") {
                                    #write-host "ERROR: Not authorized to perform this stop operation, please review instance tags and/or IAM roles."
                                    $ReturnCode = [System.Windows.Forms.MessageBox]::Show("ERROR: Not authorized to perform this stop operation, please review instance tags and/or IAM roles.","ERROR","ok","error")
                                    Write-EventLog -LogName "Application" -source "EC2 PowerState Script" -EventId 101 -EntryType Error -Message "User $($env:UserName) failed to issue an EC2 stop command for host $($SelectedServer) ($($ServerID))"
                                }
                                else {
                                    $ReturnCode = [System.Windows.Forms.MessageBox]::Show("An error occured: $($Error[0] -split '\n')","ERROR","ok","error")
                                    Write-EventLog -LogName "Application" -source "EC2 PowerState Script" -EventId 102 -EntryType Error -Message "User $($env:UserName) failed to issue an EC2 stop command for host $($SelectedServer)r ($($ServerID))"
                                }

                                $error.clear()
                            }
                        }
                    }
        "stopped"    {$ReturnCode = [System.Windows.Forms.MessageBox]::Show("Power ON host $($SelectedServer) ($($ServerID))?","Confirm Power ON","okcancel","information")
                         if ($ReturnCode -eq [System.Windows.Forms.DialogResult]::OK) {
                            try {
                                Start-EC2Instance -InstanceId $ServerID
                                Write-EventLog -LogName "Application" -source "EC2 PowerState Script" -EventId 200 -EntryType Information -Message "User $($env:UserName) sucessfully issued an EC2 start command for host $($SelectedServer) ($($ServerID))"
                                $ActionTaken = $true
                            }
                            catch {
                                if ($error -match "not authorized") {
                                    #write-host "ERROR: Not authorized to perform this stop operation, please review instance tags and/or IAM roles."
                                    $ReturnCode = [System.Windows.Forms.MessageBox]::Show("ERROR: Not authorized to perform this stop operation, please review instance tags and/or IAM roles.","ERROR","ok","error")
                                    Write-EventLog -LogName "Application" -source "EC2 PowerState Script" -EventId 201 -EntryType Error -Message "User $($env:UserName) failed to issue an EC2 start command for host $($SelectedServer) ($($ServerID))"
                                }
                                else {
                                    $ReturnCode = [System.Windows.Forms.MessageBox]::Show("An error occured: $($Error[0] -split '\n')","ERROR","ok","error")
                                    Write-EventLog -LogName "Application" -source "EC2 PowerState Script" -EventId 202 -EntryType Error -Message "User $($env:UserName) failed to issue an EC2 start command for host $($SelectedServer) ($($ServerID))"
                                }

                                $error.clear()
                            }
                        }
                    }
        "stopping"     {$ReturnCode = [System.Windows.Forms.MessageBox]::Show("No power operations are possible for host $($SelectedServer) in the present state.","Warning","ok","warning")}    
        "pending"      {$ReturnCode = [System.Windows.Forms.MessageBox]::Show("No power operations are possible for host $($SelectedServer) in the present state.","Warning","ok","warning")}
        "shutting-down" {$ReturnCode = [System.Windows.Forms.MessageBox]::Show("No power operations are possible for host $($SelectedServer) in the present state.","Warning","ok","warning")}
        "terminated"     {$ReturnCode = [System.Windows.Forms.MessageBox]::Show("No power operations are possible for host $($SelectedServer) in the present state.","Warning","ok","warning")}
     }
    
    #if an action was taken sleep for a little bit to wait for the AWS command to commit
    if ($ActionTaken) {
        start-sleep -s 2
    }
    $RefreshButton.PerformClick()

    #start the refresh timer back up if the auto refresh checkbox is ticked
    if ($AutoRefreshCheck.Checked -eq $true) {
        $Timer.start()
    }
})

$Form.Controls.Add($PowerButton)

#exit button
$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Location = New-Object System.Drawing.size(689,325)
$ExitButton.size = New-Object System.Drawing.size(80,20)
$ExitButton.Text = "Exit"
$ExitButton.TabStop = $true
$ExitButton.TabIndex = 6

$ExitButton.Add_Click({
    #$Form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $Timer.Dispose()
    $Form.close()
    Remove-Variable -Name * -ErrorAction SilentlyContinue
})

$Form.Controls.Add($ExitButton)

#RDP button
$RDPButton = New-Object System.Windows.Forms.Button
$RDPButton.Location = New-Object System.Drawing.size(689,120)
$RDPButton.size = New-Object System.Drawing.size(80,20)
$RDPButton.Text = "Launch RDC"
$RDPButton.Enabled = $false
$RDPButton.TabStop = $true
$RDPButton.TabIndex = 5

$RDPButton.Add_Click({
    $RDPIP = ($ListBox.SelectedItem).split("`t")[2] -replace '.*\[(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)\].*','$1'
    start-process -filepath "mstsc" -ArgumentList "/v:$RDPIP"
})

$Form.Controls.Add($RDPButton)

#refresh button
$RefreshButton = New-Object System.Windows.Forms.Button
$RefreshButton.Location = New-Object System.Drawing.size(689,40)
$RefreshButton.size = New-Object System.Drawing.size(80,20)
$RefreshButton.Text = "Refresh"
$RefreshButton.TabStop = $true
$RefreshButton.TabIndex = 3

$RefreshButton.Add_Click({
    $EC2List = Create-EC2List
    $PowerButton.Enabled = $false
    $RDPButton.Enabled = $false
    $ListBox.Items.Clear()
    
    #$EC2Hash = @{}
    #$EC2HashID = @{}

    #if no results cleaar out the previous selected value
    if ($EC2List.count -lt 1) {
        $global:PreviouslySelectedID = $null
    }
    
    $EC2List | % {
        #vars so we don't have to calculate this twice
        $EC2State = $_.split("`t")[0]
        $EC2Id = $_.split("`t")[1]
        $Ec2Name = $_.split("`t")[2]

        
        if ($EC2State -eq "[running]") {
            $Ec2LaunchTime = $_.split("`t")[3]
            $Uptime = new-timespan $Ec2LaunchTime $(get-date)
            $Ec2LaunchTime = "Up $(([string]($Uptime.Days)).PadLeft(4,'0')):$(([string]($Uptime.Hours)).PadLeft(2,'0')):$(([string]($Uptime.Minutes)).PadLeft(2,'0')):$(([string]($Uptime.Seconds)).PadLeft(2,'0'))"
        }
        else {
            $Ec2LaunchTime = "-               "
        }


        #$ListBox.Items.Add("$($EC2State)`t$($EC2LaunchTime)`t$($EC2Name)")| out-null
        $ListBox.Items.Add("$($EC2State)`t$($EC2LaunchTime)`t$($EC2Name)`t`t`t`t`t`t`t$($EC2Id)")| out-null

        #re-select previous selection
        $null
        if ($EC2Id -eq $global:PreviouslySelectedID) {
            $ListBoxIndex = $ListBox.Items.count-1
            $Listbox.SetSelected($ListBoxIndex,$true)
        }
    }
    $ProgressBar.value=0
})

$Form.Controls.Add($RefreshButton)

#auto-refresh toggle
$AutoRefreshCheck = New-Object System.Windows.Forms.Checkbox
$AutoRefreshCheck.Location = New-Object System.Drawing.size(689,70)
$AutoRefreshCheck.size = New-Object System.Drawing.size(80,20)
$AutoRefreshCheck.Text = "Auto"
$AutoRefreshCheck.Checked = $true
$AutoRefreshCheck.TabStop = $true
$AutoRefreshCheck.TabIndex = 4
$Form.Controls.Add($AutoRefreshCheck)

$AutoRefreshCheck.Add_Click({
    if ($AutoRefreshCheck.Checked -eq $true) {
        $ProgressBar.value=0
        $Timer.Start()
    }
    else {
        $ProgressBar.value=0
        $Timer.Stop()
    }
})

#progress bar refresh timer
$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.DataBindings.DefaultDataSourceUpdateMode = 0
$ProgressBar.Step = 1
$ProgressBar.Name = 'ProgressBar'
$ProgressBar.Location = New-Object System.Drawing.size(689,50)
$ProgressBar.size = New-Object System.Drawing.size(80,20)
$ProgressBar.Style = 'Continuous'
$ProgressBar.TabStop = $false
$Form.Controls.Add($ProgressBar)

#timer
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 200
$Timer.add_tick({
    $ProgressBar.PerformStep()
    if ($ProgressBar.value -eq 100) {
        $Timer.Stop()
        #write-host "$(get-date)"
        $RefreshButton.PerformClick()
        #$ProgressBar.value=0
        $Timer.Start()
    }
})
$Timer.start()

# Activate the form =========================================================
#Calculate-OutBox-Content
#$Form.Add_Shown({$Form.Activate()})
#$Form.ShowDialog()
[system.windows.forms.application]::run($Form)
