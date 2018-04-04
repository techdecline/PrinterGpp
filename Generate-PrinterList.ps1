param (
    # Create Migration List
    $newServer = "\\sftlpnt01",
    $oldServer = "\\sftlfs01",
    $printerListFile = "C:\Users\a1mpaschke\AppData\Local\Temp\printerlist.txt",
    $siteCode = "FTL"
)

 # $nameArr = 200..210 | ForEach-Object {"TestPrinter$_"}
 $nameArr = Get-Content $printerListFile
 $scratchDir = join-path $env:TEMP -ChildPath $siteCode
 $printerColl = @()

 foreach ($printer in $nameArr) {
     $printerColl += 1 | Select-Object -Property @{"Name" = "PrinterUncPath";"Expression" = {Join-Path $newServer -ChildPath $printer}},@{"Name" = "Action";"Expression" = {"Update"}}
     $printerColl += 1 | Select-Object -Property @{"Name" = "PrinterUncPath";"Expression" = {Join-Path $oldServer -ChildPath $printer}},@{"Name" = "Action";"Expression" = {"Delete"}}

 }

 $printerColl | Export-Csv -Path (Join-Path $scratchDir -ChildPath printerList.csv) -Force -Delimiter "," -NoTypeInformation