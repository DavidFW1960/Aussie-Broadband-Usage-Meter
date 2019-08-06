' Description: Backend script for ABBUsage Rainmeter skin by Big Kahuna
' Author: Protogen at whirlpool (skin by Big Kahuna)
' Version: 2.1.0
' Date: 18 Jul 2019

Option Explicit

Const rspName = "ABB"

Dim objShell
Set objShell = CreateObject("WScript.Shell")

objShell.Run rspName & "-Usage.vbs clean", 0, True

' EOF
