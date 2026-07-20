$SourceFolder = "."
$OutputFolder  = "./extracted"

if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$DtsxFiles = Get-ChildItem -Path $SourceFolder -Filter "*.dtsx" -Recurse

foreach ($File in $DtsxFiles) {
    $Xml = [xml](Get-Content $File.FullName)
    $Ns = [System.Xml.XmlNamespaceManager]($Xml.NameTable)
    $Ns.AddNamespace("DTS", "www.microsoft.com/SqlServer/Dts")

    $PackageName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    $PackageFolder = Join-Path $OutputFolder $PackageName

    if (-not (Test-Path $PackageFolder)) {
        New-Item -ItemType Directory -Path $PackageFolder | Out-Null
    }

    $Nodes = $Xml.SelectNodes("//*[@name='SqlCommand']", $Ns)
    $CommandIndex = 1
    $ExtractedCount = 0

    foreach ($Node in $Nodes) {
        $SqlCommand = $Node.InnerText.Trim()

        if ([string]::IsNullOrEmpty($SqlCommand)) {
            continue
        }

        $TaskName = $Node.ParentNode.ParentNode.Name
        $FileName = "{0:D3}_{1}.sql" -f $CommandIndex, ($TaskName -replace '[<>:"/\\|?*]', '_')
        $FilePath = Join-Path $PackageFolder $FileName

        $Header = "-- Package: $PackageName`r`n"
        $Header += "-- Task: $TaskName`r`n"
        $Header += "-- Command #$CommandIndex`r`n"
        $Header += "-- " + ("=" * 60) + "`r`n`r`n"

        $Header + $SqlCommand | Out-File -FilePath $FilePath -Encoding utf8
        $CommandIndex++
        $ExtractedCount++
    }

    if ($ExtractedCount -gt 0) {
        Write-Host "Extracted $ExtractedCount SQL commands from '$PackageName' to: $PackageFolder" -ForegroundColor Green
    } else {
        Write-Host "No SQL commands found in '$PackageName'" -ForegroundColor Yellow
    }
}

Write-Host "Extraction complete! Files saved to $OutputFolder" -ForegroundColor Green