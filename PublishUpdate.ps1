param(
	[String]$Executable,
	[String]$Version,
	[String]$AppName,
	[Boolean]$Test,
	[Boolean]$Approve
)
"Parameter"
$Version
$Executable
$AppName
$Test
$Approve

$WSUSSrv="LEFTY.stanztechnik.de"
$WSUSPort=8530
$AllComputersGroup="Alle Computer"
$PropertiesPath="E:\Update2WSUS"



function convertVersion {
	#Converts the Version to the WSUS-compatilble format x.x.x.x
    param (
		$Version2check
	)
    #$Version2check	

    $tmpVersion=$Version2check.split(".",4).replace(".","")
    for ($i=0; $i -le 3;$i++) {
        if ($tmpVersion.Length -ge $i+1) {
            $convVersionNumber = $convVersionNumber + $tmpVersion[$i] 
        }
        else {
            $convVersionNumber= $convVersionNumber + "0"
        }
        if ($i -lt 3) {
            $convVersionNumber = $convVersionNumber + "."
        }
    }
    return $convVersionNumber
}

function deleteOldUpdates {
	
	param (
		$String2SearchFor
	)
		
	$UpdScp = [Microsoft.UpdateServices.Administration.UpdateScope]::new()
	$UpdScp.TextIncludes = $String2SearchFor

	$UpdCol=$WSUSServer.getupdates($UpdScp)

	ForEach ($upd in $UpdCol) {
		$upd.decline()
		$WSUSServer.DeleteUpdate($upd.id.UpdateId)
	}
}

function approveUpdate {
	param (
		$IDToApprove
	)
	$groups = $WSUSServer.GetComputerTargetGroups() | Where {$_.Name -eq $AllComputersGroup}
	foreach ($group in $groups)
	{
		$upd=$WSUSServer.getUpdate($IDToApprove)
		$upd
		$upd.Approve("Install",$group)
	}
}

[void][reflection.assembly]::LoadWithPartialName(“Microsoft.UpdateServices.Administration”)

$app=Get-Item $Executable

$swProps=ConvertFrom-Stringdata(Get-Content "$PropertiesPath\$AppName.properties" -raw)
#$swProps.isInstalled.Replace('$swVersion', $Version)
#$swprops.isInstallable.Replace('$swVersion', $Version)
#$swprops.cmdLineArgs

$Version = convertVersion($Version)

$WSUSServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WSUSSrv,$false,$WSUSPort)

$sdp = [Microsoft.UpdateServices.Administration.SoftwareDistributionPackage]::new()

$sdpInstallBehavior = [Microsoft.UpdateServices.Administration.Installbehavior]::new()
$sdpInstallBehavior.CanRequestUserInput=$false
$sdpInstallBehavior.Impact=[Microsoft.UpdateServices.Administration.InstallationImpact]::Minor
$sdpInstallBehavior.RebootBehavior=[Microsoft.UpdateServices.Administration.RebootBehavior]::NeverReboots
$sdpInstallBehavior.RequiresNetworkConnectivity=$false

$sdpReturnCodes = [Microsoft.UpdateServices.Administration.ReturnCode]::new() 
$sdpReturnCodes.InstallationResult=[Microsoft.UpdateServices.Administration.InstallationResult]::Succeeded
$sdpReturnCodes.ReturnCodeValue=0
$sdpReturnCodes.IsRebootRequired=$false


if ($app.Extension -eq ".exe") {
$sdp.PopulatePackageFromExe((Get-Item $Executable).Name)
$sdp.PackageType = [Microsoft.UpdateServices.Administration.PackageType]::Update
$sdpCommandline = [Microsoft.UpdateServices.Administration.COmmandlineItem]::new()
$sdpCommandline.CommandLineExecutableName = (Get-Item $Executable).Name
$sdpCommandline.Arguments = $swProps.cmdLineArgs
$sdpCommandline.ReturnCodes.Add($sdpReturnCodes)

}
elseif ($app.Extension -eq ".msi") {
	$sdp.PopulatePackageFromWindowsInstaller($Executable)
	$sdp.PackageType = [Microsoft.UpdateServices.Administration.PackageType]::Update
#	$sdp.IsInstallable = $swProps.isInstallable.Replace('$swVersion', $Version)
	$sdpCommandline = [Microsoft.UpdateServices.Administration.WindowsInstallerItem]::new()
	$sdpCommandline.WindowsInstallerFile = (Get-Item $Executable).Name
	if ($swprops.cmdLineArgs -ne ""){
	$sdpCommandLine.InstallCommandLine=$swprops.cmdLineArgs
	}
	
}
else {
	Write-Host "Dateityp $app.Extension nicht unterstützt"
	exit
}

$sdpCommandline.IsInstalledApplicabilityRule = $swProps.isInstalled.Replace('$swVersion', $Version)
$sdpCommandLine.IsInstallableApplicabilityRule = $swProps.isInstallable.Replace('$swVersion', $Version)
$sdpCommandline.InstallBehavior=$sdpInstallBehavior

$sdp.InstallableItems[0] = $sdpCommandline


$sdp.Title = $AppName.ToString() + " " + $Version.ToString()

$sdp.VendorName = "Custom"

$sdp.PackageUpdateClassification = "Updates"

#$sdp.PackageType = [Microsoft.UpdateServices.Administration.PackageType]::Update

$sdp.ProductNames.Add($swProps.Product)

#$swprops.isInstallable
#$swprops.isInstalled

#$sdp.IsInstallable = $swProps.isInstallable.Replace('$swVersion', $swVErsion)

$sdp
$sdpTempFile = "E:\Update2WSUS\" + $sdp.PackageID + ".sdp"
#$sdpTempFIle
$sdp.Save($sdpTempFile)

deleteOldUpdates($AppName)

$sdp.PackageId
$WSUSPublisher = $WSUSServer.GetPublisher($sdpTempFile)
#$WSUSPublisher.VerifyAndPublishPackage(
if ($Test -eq $false) {
	$WSUSPublisher.PublishPackage( (Get-Item $Executable).DirectoryName.ToString() ,$null)
	if ($Approve -eq $true) {
		approveUpdate($sdp.PackageId)
	}
	
	$ConnectionString = "server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true"
	$SQLConnection= New-Object System.Data.SQLClient.SQLConnection($ConnectionString)
	$SQLConnection.Open()
	$SQLCommand = new-object "System.data.sqlclient.sqlcommand"
	$SQLCommand.Connection=$SQLConnection
	$SQLCommand.CommandText = "UPDATE dbo.tbUpdate set IsLocallyPublished=0 WHERE UpdateID='" +$sdp.PackageID + "'"
	$rowsAffected = $SQLCommand.ExecuteNonQuery()
	$SQLConnection.Close()
	#$rowsAffected
}
Remove-Item $sdpTempFile
