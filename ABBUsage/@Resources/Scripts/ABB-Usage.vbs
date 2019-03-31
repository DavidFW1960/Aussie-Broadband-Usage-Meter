'-------------------------------------------------------------------------------
' Environment
'-------------------------------------------------------------------------------

Option Explicit

'-------------------------------------------------------------------------------
' Global variables and objects
'-------------------------------------------------------------------------------

Const ApplicationFolder = "Rainmeter-ABB"

Dim objShell, AppDir, ConfigFile, EncodedFile
Dim objFS, fileHandle, ConfigData
Dim ComputerName, EncodedPassword
Dim Username, ServiceID, Password
Dim objWinHTTP, SendParams, SetCookie, Cookie
Dim AuthURL, UsageURL
Dim UsageJSON, objUsageJSON, UsageXML
Dim DownVal, UpVal, AllowanceMB, LeftVal, LastUpdated, Rollover
Dim Debug, FileTracking, StartTime

Set objShell = CreateObject( "WScript.Shell")

Set objFS = CreateObject("Scripting.FileSystemObject")

Set objWinHTTP = CreateObject("WinHTTP.WinHTTPRequest.5.1")

ComputerName = LCase(objShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))

AuthURL = "https://myaussie-auth.aussiebroadband.com.au/login"
UsageURL = "https://myaussie-api.aussiebroadband.com.au/broadband/<ServiceID>/usage"

Debug = False
FileTracking = False

StartTime = Now()

'-------------------------------------------------------------------------------
' Application folder and files
'-------------------------------------------------------------------------------

AppDir = (objShell.ExpandEnvironmentStrings("%APPDATA%")) & "\" & ApplicationFolder

If Not objFS.FolderExists(AppDir) Then
  objFS.CreateFolder(AppDir)
End If

ConfigFile = AppDir & "\ABB-Configuration.txt"
EncodedFile = AppDir & "\ABB-EncodedPassword.txt"

'-------------------------------------------------------------------------------
' Run setup if required
'-------------------------------------------------------------------------------

If Not (objFS.FolderExists(AppDir) And _
        objFS.FileExists(ConfigFile) And _
        objFS.FileExists(EncodedFile)) Then

  objShell.run("ABB-Setup.vbs")
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Load username and service ID
'-------------------------------------------------------------------------------

Username = ""
ServiceID = ""

Set fileHandle = objFS.OpenTextFile(ConfigFile)
ConfigData = fileHandle.readall
fileHandle.close

Username = parse_item(ConfigData, "Username = ", "<<<")
ServiceID = parse_item(ConfigData, "ServiceID = ", "<<<")

If Username = "" Or ServiceID = "" Then
  objShell.run("ABB-Setup.vbs")
  WScript.Quit
End If

UsageURL = Replace(UsageURL, "<ServiceID>", ServiceID)

If Debug Then
  MsgBox "UsageURL = '" & UsageURL & "'", 64, "Debug"
End If

'-------------------------------------------------------------------------------
' Load and decode password
'-------------------------------------------------------------------------------

Set fileHandle = objFS.OpenTextFile(EncodedFile)
EncodedPassword = fileHandle.readall
fileHandle.close

Password = Decode(EncodedPassword, ComputerName)

If Password = "" Then
  objShell.run("ABB-Setup.vbs")
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Login with username and password and get cookie
'-------------------------------------------------------------------------------

SendParams = "username=" & Username & "&password=" & Password

objWinHTTP.Open "POST", AuthURL, False
objWinHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"

On Error Resume Next

objWinHTTP.send SendParams

If Err.Number <> 0 Then
  RaiseException "Login VB Error - " & AuthURL, Err.Number, Err.Description
End If

If objWinHTTP.Status <> 200 Then
  RaiseException "Login HTTP Error - " & AuthURL, objWinHTTP.Status, objWinHTTP.StatusText
End If

SetCookie = objWinHTTP.GetResponseHeader("Set-Cookie")
Cookie = Split(SetCookie, ";")(0)

If Len(SetCookie) = 0 Or Len(Cookie) = 0 Then
  RaiseException "Cookie", 999, "Failed to obtain auth cookie from ABB portal (zero length)"
End If

'-------------------------------------------------------------------------------
' Get usage json
'-------------------------------------------------------------------------------

objWinHTTP.Open "GET", UsageURL, False
objWinHTTP.setRequestHeader "Cookie", Cookie

On Error Resume Next

objWinHTTP.send

If Err.Number <> 0 Then
  RaiseException "Usage VB Error - " & UsageURL, Err.Number, Err.Description
End If

If objWinHTTP.Status <> 200 Then
  RaiseException "Usage HTTP Error - " & UsageURL, objWinHTTP.Status, objWinHTTP.StatusText
End If

UsageJSON = objWinHTTP.ResponseText

If Debug Then
  MsgBox "UsageJSON = '" & UsageJSON & "'", 64, "Debug"
End If

If Len(UsageJSON) = 0 Then
  RaiseException "Usage JSON String", 999, "Failed to obtain usage info from ABB portal (zero length)"
End If

'-------------------------------------------------------------------------------
' Parse usage json
'-------------------------------------------------------------------------------

Set objUsageJSON = parse_json(UsageJSON)

DownVal = objUsageJSON.downloadedMb * 1000 * 1000
UpVal = objUsageJSON.uploadedMb * 1000 * 1000

If objUsageJSON.remainingMb = "" Or objUsageJSON.remainingMb Is Null Then
  ' Unlimited plan (skin uses allowance1_mb >= 100,000,000 as trigger)
  AllowanceMB = 100000000
  LeftVal = 0
Else
  AllowanceMB = objUsageJSON.usedMb + objUsageJSON.remainingMb
  LeftVal = objUsageJSON.remainingMb * 1000 * 1000
End If

LastUpdated = objUsageJSON.lastUpdated
Rollover = Day(StartTime) - objUsageJSON.daysTotal + objUsageJSON.daysRemaining

If Debug Then
  MsgBox "DownVal = '" & DownVal & "'" & vbCRLF & _
         "UpVal = '" & UpVal & "'" & vbCRLF & _
         "AllowanceMB = '" & AllowanceMB & "'" & vbCRLF & _
         "LeftVal = '" & LeftVal & "'" & vbCRLF & _
         "LastUpdated = '" & LastUpdated & "'" & vbCRLF & _
         "Rollover = '" & Rollover & "'", 64, "Debug"
End If

'-------------------------------------------------------------------------------
' Create and save usage xml
'-------------------------------------------------------------------------------

UsageXML = "<usage>" & vbCRLF & _
           "  <down1>" & DownVal & "</down1>" & vbCRLF & _
           "  <up1>" & UpVal & "</up1>" & vbCRLF & _
           "  <allowance1_mb>" & AllowanceMB & "</allowance1_mb>" & vbCRLF & _
           "  <left1>" & LeftVal & "</left1>" & vbCRLF & _
           "  <lastupdated>" & LastUpdated & "</lastupdated>" & vbCRLF & _
           "  <rollover>" & Rollover & "</rollover>" & vbCRLF & _
           "</usage>"

If Debug Then
  MsgBox "UsageXML = '" & UsageXML & "'", 64, "Debug"
End If

Set fileHandle = objFS.CreateTextFile("ABB-Usage.txt", True)
fileHandle.write UsageXML
fileHandle.close

'-------------------------------------------------------------------------------
' Private Function - parse_item
'-------------------------------------------------------------------------------

Private Function parse_item(ByRef contents, start_tag, end_tag)

  Dim position, item

  position = InStr(1, contents, start_tag, vbTextCompare)

  If position > 0 Then
    contents = Mid(contents, position + Len(start_tag))
    position = InStr (1, contents, end_tag, vbTextCompare)

    If position > 0 Then
      item = Mid(contents, 1, position - 1)
    Else
      item = ""
    End If
  Else
    item = ""
  End If

  parse_item = Trim(item)

End Function

'-------------------------------------------------------------------------------
' Private Function - Decode
'-------------------------------------------------------------------------------

Function Decode(Str, SeedStr)

  Dim NewStr, LenStr, LenKey, x

  NewStr = ""
  LenStr = Len(Str)
  LenKey = Len(SeedStr)

  If Len(SeedStr) < Len(Str) Then
    For x = 1 to Ceiling(LenStr/LenKey)
      SeedStr = SeedStr & SeedStr
    Next
  End If

  For x = 1 To LenStr
    NewStr = NewStr & chr(Int(asc(Mid(Str, x, 1))) + 20 - Int(asc(Mid(SeedStr, x, 1))))
  Next

  Decode = NewStr

End Function

'-------------------------------------------------------------------------------
' Private Function - Ceiling
'-------------------------------------------------------------------------------

Function Ceiling(byval n)

  Dim fTmp

  n = cdbl(n)
  fTmp = Floor(n)

  If fTmp = n then
    Ceiling = n
    Exit Function
  End If

  Ceiling = cInt(fTmp + 1)

End Function

'-------------------------------------------------------------------------------
' Private Function - Floor
'-------------------------------------------------------------------------------

Private Function Floor(byval n)

  Dim rTmp

  n = cdbl(n)
  rTmp = Round(n)

  If rTmp > n then
    rTmp = rTmp - 1
  End If

  Floor = cInt(rTmp)

End Function

'-------------------------------------------------------------------------------
' Private Function - RaiseException
'-------------------------------------------------------------------------------

Sub RaiseException(pErrorSection, pErrorCode, pErrorMessage)

    Dim errContent, errfs, errf
    Dim FileTimeStamp

    errContent = Now() & vbCRLF & vbCRLF & _
                 pErrorSection & vbCRLF & _
                 "Error Code: " & pErrorCode & vbCRLF & _
                 "--------------------------------------" & vbCRLF & _
                 pErrorMessage

    Set errfs = CreateObject("Scripting.FileSystemObject")

    Set errf = errfs.CreateTextFile("ABB-errors.txt", True)
    errf.write errContent
    errf.close

    If FileTracking Then

      FileTimeStamp = Year(StartTime) & Right("0" & Month(StartTime), 2) & Right("0" & Day(StartTime), 2) & "-" & _
                      Right("0" & Hour(StartTime), 2) & Right("0" & Minute(StartTime), 2) & Right("0" & Second(StartTime), 2)

      Set errf = errfs.CreateTextFile("ABB-errors-" & FileTimeStamp & ".txt", True)
      errf.write errContent
      errf.close

    End If

    Set errf = Nothing
    Set errfs = Nothing

    WScript.Quit

End Sub

'-------------------------------------------------------------------------------
' Function - parse_json
'-------------------------------------------------------------------------------

Function parse_json(JsonStr)

  Dim objHtmlFile, pWindow

  Set objHtmlFile = CreateObject("htmlfile")
  Set pWindow = objHtmlFile.parentWindow

  pWindow.execScript "var json = " & JsonStr, "JScript"

  Set parse_json = pWindow.json

End Function

' EOF
