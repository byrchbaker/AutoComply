if ([System.Environment]::Is64BitProcess) {
    $choice = Read-Host -Prompt "[0] Download STIGs and SCAP Security Appliance Checker`n[1] Download Dod GPOs (these fix the problems that scap detected)"
    if ($choice -eq 0) {
        # Load the HTML Agility Pack assembly
        Add-Type -Path '.\HtmlAgilityPack.dll'

        # Define the URL to parse
        $url = 'https://public.cyber.mil/stigs/scap/'

        # Send an HTTP request and parse the HTML
        $response = Invoke-WebRequest -Uri $url
        $html = [HtmlAgilityPack.HtmlDocument]::new()
        $html.LoadHtml($response.Content)

        # Define an array to store the extracted data
        $downloadLinks = @()

        # Find all the rows in the table with the class 'file'
        $rows = $html.DocumentNode.SelectNodes("//tr[@class='file']")

        # Iterate through the rows and extract the information
        foreach ($row in $rows) {
            $nameNode = $row.SelectSingleNode(".//td[@class='title_column']/a")
            if ($null -ne $nameNode) {
                $name = $nameNode.InnerText.Trim()
                $url = $nameNode.GetAttributeValue("href", "").Trim()
                
                # Add the extracted data to the array
                $downloadLinks += [PSCustomObject]@{
                    Name = $name
                    URL  = $url
                }
            }
        }

        $terms = @( "Cisco", "TOSS", "SUSE Linux", "Red Hat", "Oracle", "Solaris", "Adobe", "SCC")

        $filteredLinks = @()

        foreach ($link in $downloadLinks) {
            $containsTerm = $false
            foreach ($term in $terms) {
                if ($link.Name -match $term) {
                    $containsTerm = $true
                    break
                }
            }

            if ($containsTerm) {
                $filteredLinks += $link
            }
        }

        $selectedItems = Compare-Object $($filteredLinks.Name) $($downloadLinks.Name) | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject | Out-GridView -Title "Please select the STIG SCAP benchmarks to download!" -OutputMode Multiple
        $selectedItems = $selectedItems.split("`n")

        foreach ($item in $selectedItems) {
            $url = $downloadLinks | Where-Object {$_.Name -like "*$item*"} | Select-Object -ExpandProperty URL
            
            # Download and Extract the zip file 
            $filePath = Join-Path $PSScriptRoot $item
            Write-Host "Downloading '$($item)' to '$filePath'..."

            # Download the file
            Invoke-WebRequest -Uri $url -OutFile "$filePath.zip"
            Write-Host "Unzipping '$($item)'..."
            
            # Clean things up
            Get-ChildItem -Path $PSScriptRoot -Filter "*.zip" | Expand-Archive -Force
            Get-ChildItem -Path $PSScriptRoot -Filter "*.xml" -Recurse | Move-Item -Destination $PSScriptRoot
            
        }

        # Downloads and Installs the SCAP application
        foreach ($file in $($downloadLinks | Where-Object { $_.Name -like '*SCC* *.* *Windows*' } | Select-Object -ExpandProperty Name)) {
            # Download the file
            
            $filePath = Join-Path $PSScriptRoot $file
            Write-Host "Downloading '$($file)' to '$filePath'..."
            Invoke-WebRequest -Uri $($downloadLinks | Where-Object { $_.Name -like "*$($file)*" } | Select-Object -ExpandProperty URL) -OutFile "$filePath.zip"

            # Unzip the file
            Write-Host "Unzipping '$($file)'..."
            Expand-Archive -Path "$filePath.zip" -DestinationPath $PSScriptRoot -Force

            # Unzipping the zip file within the folder we just created
            Write-Host "Unzipping SCAP..."
            
            # Get folders in the scriptroot directory
            Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object { $_.Name -like "*scc**windows*" } | ForEach-Object {

                $setup = Get-ChildItem -Path $_.FullName | Where-Object { $_.Name -like "*SCC**Setup*" -and $_.Extension -eq ".exe" } | Select-Object -ExpandProperty FullName
                Write-Host "Running $setup"
                Start-Process -FilePath $setup -ArgumentList "/silent" -Wait
            }

        }

        Get-ChildItem -Path $PSScriptRoot -Filter "*.zip" | Remove-Item -Force
        Get-ChildItem -Path $PSScriptRoot -Directory | Remove-Item -Force -Recurse

    } elseif ($choice -eq 1) {
        
        Add-Type -Path '.\HtmlAgilityPack.dll'

        # Define the URL to parse
        $url = 'https://public.cyber.mil/stigs/gpo/'

        # Send an HTTP request and parse the HTML
        $response = Invoke-WebRequest -Uri $url
        $html = [HtmlAgilityPack.HtmlDocument]::new()
        $html.LoadHtml($response.Content)

        # Define an array to store the extracted data
        $downloadLinks = @()

        # Find all the rows in the table with the class 'file'
        $rows = $html.DocumentNode.SelectNodes("//tr[@class='file']")

        # Iterate through the rows and extract the information
        foreach ($row in $rows) {
            $nameNode = $row.SelectSingleNode(".//td[@class='title_column']/a")
            if ($null -ne $nameNode) {
                $name = $nameNode.InnerText.Trim()
                $url = $nameNode.GetAttributeValue("href", "").Trim()
                
                # Add the extracted data to the array
                $downloadLinks += [PSCustomObject]@{
                    Name = $name
                    URL  = $url
                }
            }
        }



        # Download the file
        Invoke-WebRequest -Uri $url -OutFile "DISA_DoD_GPO.zip"
        
        # Clean things up
        Get-ChildItem -Path $PSScriptRoot -Filter "*.zip" | Expand-Archive -Force
        Get-ChildItem -Path $PSScriptRoot -Filter "*.zip" | Remove-Item -Force -Recurse

        # Get the folders in the DISA_DoD_GPO directory and add the names of folders to a gridview
        $selectedItems = Get-ChildItem -Path $PSScriptRoot -Directory -Filter "DISA_DoD_GPO" | Get-ChildItem -Directory | Select-Object -ExpandProperty Name | Where-Object {$_ -notmatch "Support Files" -and $_ -notmatch "ADMX Templates"} | Out-GridView -Title "Please select the GPOs to download!" -OutputMode Multiple
        $selectedItems = $selectedItems.split("`n")
        
        foreach ($item in $selectedItems) {
            foreach ($gpo in $(Get-ChildItem -Path $([IO.Path]::Combine($PSScriptRoot, "DISA_DoD_GPO", $item, "GPOs")) -Directory)) {
                # Run $gpo.FullName with LGPO.exe
                Write-Host "Running LGPO with $item"
                # Start-Process LPGO
                Start-process -FilePath "LGPO.exe" -ArgumentList "/g", "$($gpo.FullName)" -Wait
            }
        }
    } else {
        Write-Host "Invalid input"
    }
} else {
    # 32-Bit : Needs Powershell Core

    # Downloading Powershell Core
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) *> $Null
    choco install powershell-core -y *> $Null

    # Test the location of powershell core
    if (Test-Path -Path "C:\Program Files\PowerShell\7") {
        & "$env:ProgramFiles\PowerShell\7\pwsh.exe" -File "$PSScriptRoot\32.bot.ps1"
    } else {
        & "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe" -File "$PSScriptRoot\32.bot.ps1"
    }
}