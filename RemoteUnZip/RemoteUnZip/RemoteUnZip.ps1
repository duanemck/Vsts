[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation
try {
    $RemoteComputers = Get-VstsInput -Name RemoteComputers -Require
    $UserName = Get-VstsInput -Name UserName -Require
    $Password = Get-VstsInput -Name Password -Require
    $ZipFile = Get-VstsInput -Name ZipFile -Require
    $OutputPath = Get-VstsInput -Name OutputPath -Require
    $cleanOutput = Get-VstsInput -Name CleanOutput
    $RemoveZip = Get-VstsInput -Name RemoveZip

    Get-Job | Remove-Job

    $credential = New-Object System.Management.Automation.PSCredential($UserName , (ConvertTo-SecureString -String $Password -AsPlainText -Force));
    $remoteMachines = $RemoteComputers -split ","

    $remoteMachines | ForEach-Object {
        $machineBlock = {
            $machineName = $args[0]
            $credentials = $args[1]
            $ZipFile = $args[2]
            $OutputPath = $args[3]
            $cleanOutput = $args[4]
            $RemoveZip = $args[5]

            $scriptBlockUnzip = {

                $zip = $args[0]
                $output = $args[1]
                $clean = $args[2]
                $remove = $args[3]

                Write-Host "Zip file: $zip "
                Write-Host "Output path: $output"
                Write-Host "Clean: $clean"
                Write-Host "Remove zip: $remove"

                Add-Type -AssemblyName System.IO.Compression.FileSystem

                function Unzip {
                    param([string]$zip, [string]$output)
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $output)
                };
                Write-Host "Start extract zip file ..."

                if (!(Test-Path -Path $output)) {
                    New-Item -ItemType directory -Path $output
                }
                else {
                    if ($clean -eq $TRUE) {
                        Write-Host "Cleaning folder $output"
                        Remove-Item "$output\*" -Recurse -Force
                    }
                }

                Unzip $zip $output
                Write-Host "Extracting is finished."

                if ($remove -eq $TRUE) {
                    Write-Host "Deleting source zip file..."
                    Remove-Item $zip -Force -Recurse
                    Write-Host "Zip file is deleted."
                }
                Write-Verbose "Operation has been completed successfully."
            }

            Write-Host "========================================================================================"
            Write-Host "@#@#@ Opening remote session to $machineName"
            $session = New-PsSession -ComputerName $machineName -Credential $credentials
            Invoke-Command -Session $session -ScriptBlock $scriptBlockUnzip -ArgumentList $ZipFile , $OutputPath , $cleanOutput , $RemoveZip
            Remove-PSSession -Session $session
            Write-Host "@#@#@ Session Closed"
            Write-Host "========================================================================================"
        }
        Write-Output "Starting job on $_"
        Start-Job -Name $_ -ScriptBlock $machineBlock -ArgumentList $_, $credential, $ZipFile , $OutputPath , $cleanOutput , $RemoveZip
    }
    Write-Host "Waiting for all jobs to finish"
    Wait-Job -Name $remoteMachines
    $remoteMachines | ForEach-Object {
        Write-Host "Getting output for $_"
        Receive-Job -Name $_
        Write-Host "------------------------------------------------"
    }
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
