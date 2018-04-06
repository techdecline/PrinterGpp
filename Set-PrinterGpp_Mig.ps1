param (
    [String]$GpoName = "drucker",
    [String]$Scope = "User",
    [String]$PrinterObjList = "E:\Scripts\PrinterGpp\PrinterList.csv",
    [String]$DomainName = "decline.lab"
)

function New-GPPPrinterObject {
    param (
        [String]$SharedPrinterPath,
        [String]$Action
    )

    switch ($action)
    {
        'Update' {
            $actionPrefix = "U"
            $imageNo = "2"
        }
        'Delete' {
            $actionPrefix = "D"
            $imageNo = "3"
        }
        Default {}
    }

    $printerObj = New-Object -TypeName PSCustomObject
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name clsid -Value "{9A5E9697-9095-436d-A0EE-4D128FDFBCE5}"
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name name -Value $SharedPrinterPath.Split("\")[-1]
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name status -Value $SharedPrinterPath.Split("\")[-1]
    Add-Member -InputObject $printerObj -MemberType NoteProperty -Name image -Value $imageNo.ToString()
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

Function Resolve-FilterGroup {
    param (
        [String]$ShareName,
        [String]$Prefix = "ftl_grp_printer_"
    )

    $groupName = $Prefix + $ShareName
    try {
        Get-ADGroup -Identity $groupName -ErrorAction Stop -OutVariable grpObj
        $returnObj = $grpObj | Select-Object `
            @{"Name" = "GroupName";Expression = {(Get-ADDomain ).NetBIOSName + "\" + $_.Name}},
            @{"Name" = "SIDString";Expression = {$_.SID -as [String]}}
    }
    catch [System.Management.Automation.ActionPreferenceStopException] {
        Write-Warning "No such group $groupName"
        return $false
    }

    return $returnObj
}

function Initialize-PrinterGppFile {
    param (
        [string]$XmlPath
    )

        $content = @'
<?xml version="1.0" encoding="utf-8"?>
<Printers clsid="{1F577D12-3D1B-471e-A1B7-060317597B9C}">
<SharedPrinter clsid="{9A5E9697-9095-436d-A0EE-4D128FDFBCE5}" name="dummyprinter" status="dummyprinter" image="2" changed="2018-03-27 13:48:31" uid="{A7F1336F-067D-43E0-83C1-85685220A79A}" bypassErrors="1">
<Properties action="U" comment="" path="\\dummyserver\dummyprinter" location="" default="0" skipLocal="0" deleteAll="0" persistent="0" deleteMaps="0" port=""/>
<Filters><FilterGroup bool="AND" not="0" name="DECLINE\ftl_grp_printer_TestPrinter204" sid="S-1-5-21-3014742100-1987343316-1888600620-3611" userContext="1" primaryGroup="0" localGroup="0"/></Filters>
</SharedPrinter>
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
    $gpObj = Get-GPO -Name $GpoName -ErrorAction Stop -Domain $DomainName
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
New-Item $printersXmlPath -ItemType File -Force
Initialize-PrinterGppFile -XmlPath $printersXmlPath

# Import XML File
[xml]$xmlObj = Get-Content $printersXmlPath

# select Dummy
$dummyNode = ($xmlObj.Printers.ChildNodes | Where-Object {$_.name -eq "dummyprinter"})

$printerObjArr = Import-Csv $PrinterObjList

# Generate new printers
foreach ($printer in $printerObjArr) {
    #$filterGroup = Resolve-FilterGroup -ShareName $printer.Name

    $printerGppObj = New-GPPPrinterObject -SharedPrinterPath $printer.PrinterUncPath -Action $printer.Action

    $newNode = $dummyNode.Clone()
    $filterNode = $new.Filters
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
    if ($newNode.Properties.action -eq "D") {
        $newNode.RemoveChild($newNode.Filters)
    }
    else {
        if ($grpObj = Resolve-FilterGroup -ShareName $printerGppObj.Name) {
            $grpObj
            $newNode.Filters.FilterGroup.name = $grpObj.GroupName.ToString()
            $newNode.Filters.FilterGroup.sid = [String]$grpObj.SidString
        }
    }



    $xmlObj.Printers.AppendChild($newNode)
}

$xmlObj.Printers.RemoveChild($dummyNode)

# Save XML
# $xmlObj.Save($printersXmlPath)

# Save without Indentation and newline
$xwSettings = New-Object -TypeName System.Xml.XmlWriterSettings
$xwSettings.Indent = $false
$xwSettings.NewLineChars = $null
$xWriter = [System.Xml.XmlWriter]::Create($printersXmlPath,$xwSettings)
$xmlObj.Save($xWriter)
$xWriter.Close()