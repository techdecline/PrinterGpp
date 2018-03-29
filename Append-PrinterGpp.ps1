param (
    [String]$GpoName = "Drucker",
    [String]$Scope = "User",
    [String[]]$SharedPrinterPath = @("\\CM-Win10-1\TestDrucker2","\\CM-Win10-1\TestDrucker1")
)

function New-GPPPrinterObject {
    param (
        [String]$SharedPrinterPath,
        [String]$Action
    )

    switch ($action)
    {
        'Update' { $actionPrefix = "U"}
        'Delete' { $actionPrefix = "D"}
        Default {}
    }

    $printerObj = New-Object -TypeName PSCustomObject
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name clsid -Value "{9A5E9697-9095-436d-A0EE-4D128FDFBCE5}"
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name name -Value $SharedPrinterPath.Split("\")[-1]
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name status -Value $SharedPrinterPath.Split("\")[-1]
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name image -Value "2"
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name changed -Value (get-date).GetDateTimeFormats()[31]
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name uid -Value ("{$((New-Guid).guid)}")
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name bypassErrors -Value "1".ToString()

    
    $propertiesDictionary = [ordered]@{
        action="$actionPrefix";
        comment="";
        path="$SharedPrinterPath";
        location="";
        default="0";
        skipLocal="0";
        deleteAll="0";
        persistent="0";
        deleteMaps="0";
        port="0";

    }
    
    Add-Member -InputObject $printerObj -NotePropertyMembers $propertiesDictionary -TypeName printerObj
    return $printerObj
}

function Initialize-PrinterGppFile {
    param (
        [string]$XmlPath
    )

        $content = @'
<?xml version="1.0" encoding="utf-8"?>
<Printers clsid="{1F577D12-3D1B-471e-A1B7-060317597B9C}">
<SharedPrinter clsid="{9A5E9697-9095-436d-A0EE-4D128FDFBCE5}" name="dummyprinter" status="dummyprinter" image="2" changed="2018-03-27 13:48:31" uid="{A7F1336F-067D-43E0-83C1-85685220A79A}" bypassErrors="1"><Properties action="U" comment="" path="\\dummyserver\dummyprinter" location="" default="0" skipLocal="0" deleteAll="0" persistent="0" deleteMaps="0" port=""/></SharedPrinter>
</Printers>
'@

   $content | Out-File $XmlPath -Force -encoding utf8

}

try {
    Import-Module GroupPolicy -ErrorAction Stop
}
catch [System.Management.Automation.ActionPreferenceStopException] {
    Write-Error "Could not load module...exiting"
    return 1
}

try {
    $gpObj = Get-GPO -Name $GpoName -ErrorAction Stop
    $gpPath = "\\$($gpObj.DomainName)\sysvol\$($gpObj.DomainName)\Policies\{$($gpObj.id)}"
}
catch [System.ArgumentException] {
    Write-Error "No Group Policy object matches the criteria...exiting"
    return 1
}


switch ($scope)
{
    "User" {
        $printersXmlPath = Join-Path -Path $gpPath -ChildPath "\User\Preferences\Printers\Printers.xml"
    }
    "Machine" {
        $printersXmlPath = Join-Path -Path $gpPath -ChildPath "\Machine\Preferences\Printers\Printers.xml"
    }
    Default {}
}

# Backup Existing File
if (Test-Path $printersXmlPath) {
    Move-Item $printersXmlPath -Destination "$env:temp\printers_backup_$(get-date -Format yyyyMMdd).xml" -Force

}

# Create and initialize new Printers.xml
$guid = (New-Guid).Guid.ToString()
New-Item $printersXmlPath -ItemType File -Force
Initialize-PrinterGppFile -XmlPath $printersXmlPath

# Import XML File
[xml]$xmlObj = Get-Content $printersXmlPath

# select Dummy
$dummyNode = ($xmlObj.Printers.ChildNodes | Where-Object {$_.name -eq "dummyprinter"})

# Generate new printers
foreach ($printer in $SharedPrinterPath) {
    $printerGppObj = New-GPPPrinterObject -SharedPrinterPath $printer -Action Update

    $newNode = $dummyNode.Clone()
    $newNode.clsid = $printerGppObj.clsid
    $newNode.name = $printerGppObj.name
    $newNode.status = $printerGppObj.status
    $newNode.image = $printerGppObj.image
    $newNode.changed = $printerGppObj.changed
    $newNode.uid = $printerGppObj.uid
    $newNode.bypassErrors = $printerGppObj.bypassErrors
    $newNode.Properties.action = $printerGppObj.action
    $newNode.Properties.comment = $printerGppObj.comment
    $newNode.Properties.path = $printerGppObj.path
    $newNode.Properties.location = $printerGppObj.location
    $newNode.Properties.default = $printerGppObj.default
    $newNode.Properties.skipLocal = $printerGppObj.skipLocal
    $newNode.Properties.deleteAll = $printerGppObj.deleteAll
    $newNode.Properties.persistent = $printerGppObj.persistent
    $newNode.Properties.deleteMaps = $printerGppObj.deleteMaps
    $newNode.Properties.port = $printerGppObj.port
    $xmlObj.Printers.AppendChild($newNode)
}

$xmlObj.Printers.RemoveChild($dummyNode)

# Save XML
$xmlObj.Save($printersXmlPath)