# Create Migration List
 $newServer = "\\CM-Win10-3"
 $oldServer = "\\CM-Win10-1"

 $nameArr = 200..210 | ForEach-Object {"TestPrinter$_"}
 $printerColl = @()

 foreach ($printer in $nameArr) {
     $printerColl += 1 | Select-Object -Property @{"Name" = "PrinterUncPath";"Expression" = {Join-Path $newServer -ChildPath $printer}},@{"Name" = "Action";"Expression" = {"Update"}}
     $printerColl += 1 | Select-Object -Property @{"Name" = "PrinterUncPath";"Expression" = {Join-Path $oldServer -ChildPath $printer}},@{"Name" = "Action";"Expression" = {"Delete"}}

 }

 $printerColl | Export-Csv -Path .\PrinterList.csv -Force -Delimiter "," -NoTypeInformation