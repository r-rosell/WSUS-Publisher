$wsusServer=GEt-WsusServer
$Items=Get-ChildItem -Path E:\WSUS\UpdateServicesPackages\

foreach ($Item in $Items.NAme)
{
	$error.clear()
	$Item
    GEt-WsusUpdate -UpdateId $Item
	if ($error)
	{
        Write-host "Lösche $Item"
        Remove-Item -Path E:\WSUS\UpdateServicesPackages\$Item -Recurse
     }
}
		