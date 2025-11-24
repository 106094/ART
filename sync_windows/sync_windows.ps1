
$sourcePaths = @(
    "C:\Users\user\Desktop\ART_VTT",
    "C:\Users\user\Desktop\Internal",
    "C:\Users\user\Desktop\ART_Foxconn"
)
$destPath = "\\192.168.50.175\Users\user\Desktop\"
foreach($sourcePath in $sourcePaths){
   $sourcename = Split-Path $sourcePath -Leaf
   $sourcenamepart=($sourcename -split "_")[-1]
    $destination = Get-ChildItem -path $destPath -Directory | Where-Object { $_.Name -like "*ART-*" -and $_.Name -match "$sourcenamepart$" } 
    if (test-path $destination) {
         $destFullPath = Join-Path $destination.FullName "Data"
         robocopy $sourcePath $destFullPath /MIR /XD "*_[Temp]ReleaseDate_ARTVersion*" "*_Old*" /XF "*_[Temp]ReleaseDate_ARTVersion*" "*_Old*"
    }
}