# Configuring AWS PowerShell Modules

Windows AMIs in Amazon include a "_Windows PowerSHell for AWS_" enviornment with all AWS modules pre-loaded.  This environment by default has AWS pre-execution checks enabled and can take some time to import modules and cmdlets when called -- importing these smaller specific modules speeds execution significantly.

**Skip down to "Installing the pre-customized modules" to install a modified version of the AWS modules which function better on non-internet connected hosts, or continue reading if you'd like to work with the stock versions of these modules.**

Download or install these specific AWS PowerShell modules from the PowerShell Gallery for the standard PowerShell environment:
- aws.tools.common
- aws.tools.ec2

**Note:** When executing the script on a host with no internet connectivity it is reccomended to modify the modules to remove the pre-execution checks which attempt to connect to public IP service enpoints and time out.

**Reference:** Instructions for manually installing [NuGet packages](https://docs.microsoft.com/en-us/powershell/scripting/gallery/how-to/working-with-packages/manual-download?view=powershell-7.1).

# Installing the Pre-Customized Modules
Download and unzip the [**_AWS_Modules.zip_**](AWS_Modules.zip) file.  Move the extracted directories to the local  C:\Program Files\WindowsPowerShell\Modules folder.

Below are the specific edits to the stock AWS modules.  

**aws.tools.common.psd1:**
```
    # Modules to import as nested modules of the module specified in ModuleToProcess
#    NestedModules = @(
#        'AWS.Tools.Common.Completers.psm1',
#        'AWS.Tools.Common.Aliases.psm1'
#    )
```

```
    # Script files (.ps1) that are run in the caller's environment prior to importing this module
#    ScriptsToProcess = @(
#        'ImportGuard.ps1'
#    )
```

**aws.tools.ec2.psd1:**
```
    # Modules to import as nested modules of the module specified in ModuleToProcess
#    FormatsToProcess = @(
#        'AWS.Tools.EC2.Format.ps1xml'
#    )
```

```
    # Modules to import as nested modules of the module specified in ModuleToProcess
#    NestedModules = @(
#        'AWS.Tools.EC2.Completers.psm1',
#        'AWS.Tools.EC2.Aliases.psm1'
#    )
```

