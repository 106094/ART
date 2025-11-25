
$sourcePaths =get-childitem "C:\Users\user\Desktop\ART_*" -directory


$destPath = "\\192.168.50.175\Users\user\Desktop\"
foreach($sourcePath in $sourcePaths){
   $sourcefolderpath=$sourcePath.fullname
     $sourcename=$sourcePath.name
    $destination = Get-ChildItem -path $destPath -Directory | Where-Object { $_.Name -eq  $sourcename }
    if (test-path $destination.FullName) {
     $sourfolders= get-childitem $sourcefolderpath -directory|Where-Object{$_.name -notlike "*old*" -and $_.name -notlike "*temp*"}
         foreach ($sourcefolder in $sourfolders){     
         $sourcefoldername=$sourcefolder.name
         $sourcefolderpath=$sourcefolder.fullname
             $destFullPath=join-path  ( $destination.FullName) $sourcefoldername
            robocopy  $sourcefolderpath $destFullPath /MIR /XD "DATA"
         
         }
    }
}
