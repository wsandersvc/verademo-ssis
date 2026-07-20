$SourceFolder = "."
$OutputFolder  = "./extracted"

if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$ExportedFiles = @{}
$Collisions = @()
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
        $BaseFileName = "{0:D3}_{1}.sql" -f $CommandIndex, ($TaskName -replace '[<>:"/\\|?*]', '_')
        $FileKey = $BaseFileName.ToLower()
        $FileName = $BaseFileName

        if ($ExportedFiles.ContainsKey($FileKey)) {
            $Collision = @{
                FileName = $BaseFileName
                FirstSource = $ExportedFiles[$FileKey]
                SecondSource = "$PackageName/$BaseFileName"
            }
            $Collisions += $Collision
            Write-Host "WARNING: Duplicate SQL filename detected: '$BaseFileName'" -ForegroundColor Yellow
            Write-Host "  First:  $($ExportedFiles[$FileKey])" -ForegroundColor Yellow
            Write-Host "  Appending suffix for: $PackageName" -ForegroundColor Yellow

            $NameWithoutExt = $BaseFileName -replace '\.sql$', ''
            $Suffix = 2
            while ($ExportedFiles.ContainsKey("$NameWithoutExt`_$Suffix.sql".ToLower())) {
                $Suffix++
            }
            $FileName = "$NameWithoutExt`_$Suffix.sql"
            $FileKey = $FileName.ToLower()
        }

        $ExportedFiles[$FileKey] = "$PackageName/$FileName"
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

if ($Collisions.Count -gt 0) {
    Write-Host "`nExtraction complete with WARNINGS!" -ForegroundColor Yellow
    Write-Host "$($Collisions.Count) collision(s) detected and renamed" -ForegroundColor Yellow
} else {
    Write-Host "`nExtraction complete! Files saved to $OutputFolder" -ForegroundColor Green
}