Option Explicit

Dim shell, fileSystem, scriptFolder, scriptPath, command, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptFolder = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptPath = scriptFolder & "\publish-status.ps1"
' Window style 0 and -WindowStyle Hidden prevent a console flash. Waiting propagates the real exit code.
command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptPath & """"
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode
