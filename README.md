# Eigene Updates über WSUS verteilen

Solange es WSUS noch gibt und es sowieso in vielen Firmen eingesetzt wird, kann man darüber doch auch eigene Software verteilen.
Für alle, die sich keine Software-Deployment-Lösung zulegen wollen (oder dürfen), ist dieses kleine Script gedacht.

Inspiriert von LUP und WPP, veröffentlicht das Script eigene Updates über WSUS.
Nur waren mir beide Lösungen mit zuviel manuellem Aufwand verbunden.

Und weil das mittlerweile doch ganz gut funktioniert, will ich euch daran teilhabne lassen.

## Meine Umgebung
Das Script läuft lokal auf dem WSUS-Server. Remote kann funktionieren, hab ich nie gestestet.

Auf dem Server läuft ebenfalls [Ketarin](https://ketarin.org/)

Zu jeder Software, die verteilt wird, gibt es ein .properties-File mit Basisinformationen. Beislpiele habe ich angefügt.

Die Regeln, um zu erkennen, ob die Software installiert ist, bzw. installiert werden kann, sind [hier](https://learn.microsoft.com/en-us/previous-versions/bb531100(v=technet.10)) bei Microsoft zu finden.
Ich gehe in den meisten Fällen File-basiert vor und prüfe auf Vorhandensein des aktuellen Programms und vegleiche die File-Version der vorhandenen .exe mit der neuen Version.

Ketarin läuft täglich als geplanter Task und holt die aktuellen Versionen.
Es wurde überall noch eine Variable `version` hinzugefügt.
Als Post-Download-Script rufe ich dann mein Powershell-Script auf:
`\path\to\PublishUpdate.ps1 -Executable $app.CurrentLocation  -Version $app.variables.ReplaceAllInString("{version}") -AppName $app.Name -Approve $true | Out-File \path\to\$app.log`


