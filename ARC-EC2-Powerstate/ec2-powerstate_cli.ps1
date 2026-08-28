Param(
    [Parameter(Mandatory=$false)][String]$TagOverride
)

# EC2-PowerState_cli.ps1

#This script is intended for use in the Precision Health AWS HIPAA enclave to control power state of "worker node" EC2 instances.
#An appropriate set of tagging, IAM, machine policies, network and filtering configurations is required in addition to staging the
#script and AWS PowerShell modules on an appropriate bastion host to be executed from.  Reference project documentation for specifics.


Function Create-Menu (){
#This function controls a text based selection menu
#code seeded from ref:
#https://community.spiceworks.com/scripts/show/4656-powershell-create-menu-easily-add-arrow-key-driven-menu-to-scripts
 
    Param(
        [Parameter(Mandatory=$True)][String]$MenuTitle,
        [Parameter(Mandatory=$True)][array]$MenuOptions
    )

    #menu controls
    [console]::cursorvisible = $false
    $MaxValue = $MenuOptions.count-1
    $Selection = 0
    $EnterPressed = $False
    $MenuUpdated = $false

    #timer controls
    $timeoutseconds = 10
    $timeout = New-TimeSpan -seconds $timeoutseconds
    $stopwatch = [diagnostics.stopwatch]::StartNew()
   
    Clear-Host

    While(($EnterPressed -eq $False) -and ($stopwatch.Elapsed -lt $timeout)){

        #If the menu has not been updated, do so as a change is necessary
        if ($MenuUpdated -eq $false) {
            Write-Host "$MenuTitle" -ForegroundColor Green -BackgroundColor Black

            For ($i=0; $i -le $MaxValue; $i++){
           
                If ($i -eq $Selection){
                    Write-Host -BackgroundColor Cyan -ForegroundColor Black "$($MenuOptions[$i])"
                } Else {
                    Write-Host "$($MenuOptions[$i])"
                }
            }

            $MenuUpdated = $True
        }

        #only execute if a key has been pressed
        if ([console]::KeyAvailable) {

            $KeyInput = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").virtualkeycode
            Switch($KeyInput){
                13 {
                        $stopwatch.stop()
                        $MenuUpdated = $false
                        $EnterPressed = $True
                        Return $Selection
                        Clear-Host
                        break
                    }

                38 {
                        If ($Selection -eq 0){
                            $Selection = $MaxValue
                        } Else {
                            $Selection -= 1
                        }
                        $stopwatch.stop()
                        $MenuUpdated = $false
                        Clear-Host
                        break
                    }
                
                40 {
                        If ($Selection -eq $MaxValue){
                            $Selection = 0
                        } Else {
                            $Selection +=1
                        }
                        $stopwatch.stop()
                        $MenuUpdated = $false
                        Clear-Host
                        break
                    }
                
                Default{ Clear-Host }
            }
        }

        #display a refresh countdown if no key has been pressed
        if ($stopwatch.IsRunning -eq $true) {
            write-host -NoNewline "`r[Refresh in $($timeoutseconds - $stopwatch.elapsed.seconds) seconds] "
            start-sleep -Milliseconds 100
        }
    }

    #Time to refresh, grab the state of EC2 instances and redraw
    New-Menu
}

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
    $EC2instances = (get-ec2instance -filter @{name="tag:$($Tag)"; values="$TagValue"} -region $Region).instances |select-object Tags,InstanceId,Platform,PrivateIpAddress,State,InstanceType
    
    #Array to host hashtables
    $EC2Raw = @()

    #For each discoverd EC2 create a hash of attributes and add to the raw array
    $EC2instances | % {

        $TempHash = @{}
        $TempHash.set_item("Name",($_.Tags | Where-Object Key -eq "Name").value)
        $TempHash.set_item("State",$_.State.Name.value)
        $TempHash.set_item("Id",$_.InstanceID)
        $TempHash.set_item("InstanceType",$_.InstanceType)
        $TempHash.set_item("Platform",$_.Platform)
        $TempHash.set_item("PrivateIpAddress",$_.PrivateIpAddress)
        
        #only Windows systems contain the platform attribute, so...
        if ($_.Platform -eq $null) { $_.Platform = "Linux" }
        $TempHash.set_item("Platform",$_.Platform)

        #if an alternate tag was supplied use that in place of the mcomm tag, overload the mcomm attribute with the alternate
        if ($global:AlternateTag) {
            $TempHash.set_item("mcomm",($_.Tags | Where-Object Key -eq $AltTag).value)
        }      
        else {
            $TempHash.set_item("mcomm",($_.Tags | Where-Object Key -eq "mcomm").value)
        }

        $EC2Raw += $TempHash

    }

return $EC2Raw

}

Function New-Menu {
#This function creates a list of EC2 instances for a text based selection menu and handles user selected power control actions

    #pull some info from the calling machine's metadata
    $MyInstanceID = (Invoke-WebRequest "http://169.254.169.254/latest/meta-data/instance-id").content
    $MyRegion = (Invoke-WebRequest "http://169.254.169.254/latest/meta-data/placement/region").content

    #if alternate tag was supplied handle it
    if ($global:AlternateTag) {
        $Tag = $global:AlternateTag.split(":")[0]
        $TagValue = $global:AlternateTag.split(":")[1]

        if ($TagValue -eq $null) {
            write-host "Error: no value specified for supplied alternate tag '$Tag', exiting."
            write-host "Instance id: $($MyInstanceID)"
            [console]::cursorvisible = $true
            exit 1
        }
    }
    else {
        #Get the calling machine's mcomm tag value, we'll use this as the default EC2 searching filter 
        $TagValue = ((get-ec2instance $MyInstanceID -region $MyRegion).instances.tags | where-object Key -eq "mcomm").value

       if ($TagValue -eq $null) {
            write-host "Error: No 'mcomm' tag applied to this instance id, exiting."
            write-host "Instance id: $($MyInstanceID)"
            [console]::cursorvisible = $true
            exit 1
        }
    }

    #Get the raw EC2 data & prune the null results from the data set
    $MenuSelectRaw = Get-MyEC2s $MyRegion $TagValue | sort-object -Property {$_.name}
    $MenuSelectRaw = $MenuSelectRaw.where({$null -ne $_})

    # Prepare the text menu headers and default refresh/exit options
    if ($global:AlternateTag) {
        $MenuTitle = "AWS EC2 Power State Control [alternate tag '$Tag' target: $($TagValue)]`r`n`r`nName`t`t`tState`t`tId`t`t`tPrivateIp`tPlatform`tInstanceType"
    }
    else {
        $MenuTitle = "AWS EC2 Power State Control [mcomm tag target: $($TagValue)]`r`n`r`nName`t`t`tState`t`tId`t`t`tPrivateIp`tPlatform`tInstanceType"
    }

    $MenuOptions = @("[Refresh / Auto-Refresh]")
    $MenuOptions += "[Exit]"

    #Pad menu options with tabs to keep the output lined up
    $MenuSelectRaw | % {
        switch ($_.get_item('Name').length) {     
            {0..8 -contains $_}    {$NamePad = "`t`t`t"}
            {9..16 -contains $_}    {$NamePad = "`t`t"}
            default    {$NamePad = "`t"}
        }
        switch ($_.get_item('State').length) {     
            {8..15 -contains $_}    {$StatePad = "`t"}
            default    {$StatePad = "`t`t"}
        }
        switch (($_.get_item('PrivateIpAddress').length)) {
            {0 -contains $_}    {$IPPad  = "`t`t"}
            default    {$IPPad = "`t"}
        }
        $MenuOptions += "$($_.get_item('Name'))$($NamePad)$($_.get_item('State'))$($StatePad)$($_.get_item('Id'))`t$($_.get_item('PrivateIpAddress'))$IPPad$($_.get_item('Platform'))`t`t$($_.get_item('InstanceType'))"
    }

    #Draw the menu
    $UserSelection = Create-Menu $MenuTitle $MenuOptions

    #if 0 refresh was chosen
    if ($UserSelection -eq 0){
        New-Menu
    }
    elseif ($UserSelection -eq 1){
        write-host "`r`nExit selected."
        [console]::cursorvisible = $true
        exit 0
    }
    else {
        #Handle the selection

        #Correct selection offset as first two options are refresh end exit
        $UserSelection = $UserSelection -2
        if ($MenuSelectRaw[$UserSelection].Id -eq $MyInstanceID) {
            write-host "`r`nYour selection:`r`n>$($MenuSelectRaw[$UserSelection].Name) $($MenuSelectRaw[$UserSelection].Id)`r`n**This is the current host, no power events offered**"
            $action = "None"
        }
        else {
            #Actual EC2 line selected
            write-host "`r`nYour selection:`r`n>$($MenuSelectRaw[$UserSelection].Name) $($MenuSelectRaw[$UserSelection].Id)"

            #build actions
            $action_stop = New-Object System.Management.Automation.Host.ChoiceDescription 'Sto&P', 'stop'
            $action_force = New-Object System.Management.Automation.Host.ChoiceDescription '&Force', 'force'
            $action_start = New-Object System.Management.Automation.Host.ChoiceDescription 'Star&T', 'start'
            $action_cancel = New-Object System.Management.Automation.Host.ChoiceDescription '&Cancel', 'cancel'

            $options_stop = [System.Management.Automation.Host.ChoiceDescription[]]($action_cancel, $action_stop, $action_force)
            $options_start = [System.Management.Automation.Host.ChoiceDescription[]]($action_cancel,$action_start)

            #Depending on current EC2 state offer actions
            switch ($MenuSelectRaw[$UserSelection].State) {
                "running"    {$result = $host.ui.PromptForChoice("Stop Running Instance?", "Stop instance $($MenuSelectRaw[$UserSelection].Name) $($MenuSelectRaw[$UserSelection].Id)?", $options_stop, 0)
                                try {
                                  if ($result -eq 1) {
                                    $action = "Stopping instance"
                                    Stop-EC2Instance -InstanceId $MenuSelectRaw[$UserSelection].Id | out-null
                                  }
                                  elseif ($result -eq 2) {
                                    $action = "Force stopping instance"
                                    Stop-EC2Instance -InstanceId $MenuSelectRaw[$UserSelection].Id -Enforce $true | out-null
                                  }
                                  else { $action = "None" }
                                }
                                catch {
                                    if ($error -match "not authorized") {
                                        write-host "ERROR: Not authorized to perform this stop operation, please review instance tags and/or IAM roles."
                                    }
                                    else {
                                        Write-host "An error occured."
                                    }

                                    $error.clear()
                                }
                            }

                "stopped"    {$result = $host.ui.PromptForChoice("Start halted Instance?", "Start instance $($MenuSelectRaw[$UserSelection].Name) $($MenuSelectRaw[$UserSelection].Id)?", $options_start, 0)
                                try {
                                  if ($result -eq 1) {
                                    $action = "Starting instance"
                                    Start-EC2Instance -InstanceId $MenuSelectRaw[$UserSelection].Id | out-null
                                  }
                                  else { $action = "None" }
                                }
                                catch {
                                    if ($error -match "not authorized") {
                                        write-host "ERROR: Not authorized to perform this start operation, please review instance tags and/or IAM roles."
                                    }
                                    else {
                                        Write-host "An error occured."
                                        write-host $error
                                    }
                                    $error.clear()
                                }
                              }

                "stopping"    {$action = "None" ; write-host "Current state is stopping, please wait"}
                "pending"    {$action = "None" ; write-host "Current state is pending, please wait"}
                "shutting-down"    {$action = "None" ; write-host "Current state is shutting-down, please wait"}
                "terminated"    {$action = "None" ; write-host "Current state is terminated, nothing to do"}
            }
        }

        #Display selected action
        write-host "`r`nAction: $action"
        $action = $null
        write-host "Refresh in 5 seconds"
        start-sleep 5

        #Refresh the menu
        New-Menu
    }
}

#The script begins here

write-host "Importing AWS modules -- this may take some time..."

#Import requried AWS modules.  Edit according to documentation if this code is to run from a non-internet control machine
Import-module aws.tools.common #-verbose
Import-Module aws.tools.ec2 #-verbose

#If instantiated with a tag override stash that in a global var so functions have access to it
if ($TagOverride) {
    $global:AlternateTag = $TagOverride
}

#Draw the menu
New-Menu