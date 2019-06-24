Option Explicit

Const rspName = "ABB"

Dim objShell
Set objShell = CreateObject("WScript.Shell")

objShell.Run rspName & "-Usage.vbs clean", 0, True

' EOF
