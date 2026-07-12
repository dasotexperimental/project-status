Option Explicit

Dim shell, fileSystem, scriptFolder, command
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptFolder = fileSystem.GetParentFolderName(WScript.ScriptFullName)
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & scriptFolder & "\publish-status.ps1"""

' Window style 0 = hidden; do not wait for the publisher to finish.
shell.Run command, 0, False
