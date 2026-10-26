' Runs Prayer Reminder from source with no console window (development / portable use).
' The installed build uses PrayerReminder.exe instead and does not need this file.
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
args = ""
If WScript.Arguments.Count > 0 Then args = " " & WScript.Arguments(0)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & dir & "\PrayerReminder.ps1""" & args, 0, False
