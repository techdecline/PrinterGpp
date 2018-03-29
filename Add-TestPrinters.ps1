function Add-TestPrinter {
    param (
        [String]$Name,
        [String]$IPAddress
    )

    $driverName = "HP Color LaserJet CM6040 MFP PCL6 Class Driver"

    if (-not ($port = Get-PrinterPort -Name $IPAddress -ErrorAction SilentlyContinue)) {
        $port = Add-PrinterPort -Name $IPAddress -PrinterHostAddress $IPAddress
    }
    Add-Printer -DriverName $driverName -Name $Name -ShareName $Name -Shared -PortName $IPAddress
}


$arr = 200..210
foreach ($item in $arr) {
    Add-TestPrinter -Name "TestPrinter$item" -IPAddress "192.168.0.$item"
}