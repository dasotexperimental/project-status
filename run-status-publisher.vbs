Option Explicit

Dim shell, fileSystem, scriptFolder, scriptPath, logFolder, logPath, command, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptFolder = fileSystem.GetParentFolderName(WScript.ScriptFullName)
scriptPath = scriptFolder & "\publish-status.ps1"
logFolder = scriptFolder & "\logs"
logPath = logFolder & "\publisher.log"

If Not fileSystem.FolderExists(logFolder) Then
    fileSystem.CreateFolder(logFolder)
End If

' Window style 0 = hidden. Waiting propagates the real PowerShell exit code to Task Scheduler.
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ""& '" & scriptPath & "' *>> '" & logPath & "'"""
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode
