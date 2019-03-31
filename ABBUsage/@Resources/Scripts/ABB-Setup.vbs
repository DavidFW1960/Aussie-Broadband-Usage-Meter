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
Dim Username, ServiceID, Password
Dim objWinHTTP, SendParams, SetCookie, Cookie
Dim AuthURL, CustURL
Dim CustomerJSON, objCustomerJSON
Dim ComputerName, EncodedPassword

Set objShell = CreateObject("WScript.Shell")

Set objFS = CreateObject("Scripting.FileSystemObject")

Set objWinHTTP = CreateObject("WinHTTP.WinHTTPRequest.5.1")

ComputerName = LCase(objShell.ExpandEnvironmentStrings("%COMPUTERNAME%"))

AuthURL = "https://myaussie-auth.aussiebroadband.com.au/login"
CustURL = "https://myaussie-api.aussiebroadband.com.au/customer"

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
' Load existing username and service ID
'-------------------------------------------------------------------------------

Username = ""
ServiceID = ""

If objFS.FileExists(ConfigFile) Then
  Set fileHandle = objFS.OpenTextFile(ConfigFile)
  ConfigData = fileHandle.readall
  fileHandle.close

  Username = parse_item(ConfigData, "Username = ", "<<<")
  ServiceID = parse_item(ConfigData, "ServiceID = ", "<<<")
End If

'-------------------------------------------------------------------------------
' Prompt for username and password
'-------------------------------------------------------------------------------

Password = ""

Username = InputBox("Please enter your ABB username" & vbCRLF & _
                     "(the same as your ABB user)", "ABB Setup", Username)

If Username = "" Then WScript.Quit

Password = InputBox("Please enter your ABB password" & vbCRLF & _
                     "(it is visible here but will be encoded)", "ABB Setup")

If Password = "" Then WScript.Quit

MsgBox "Setup will now test your username and password" & vbCRLF & _
       "and retrieve your NBN Service ID from the ABB portal", 64, "ABB Setup"

'-------------------------------------------------------------------------------
' Test login with username and password
'-------------------------------------------------------------------------------

SendParams = "username=" & Username & "&password=" & Password

objWinHTTP.Open "POST", AuthURL, False
objWinHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
objWinHTTP.send SendParams

If objWinHTTP.Status <> 200 Then
  MsgBox "Failed to login to ABB portal (HTTP Status " & objWinHTTP.Status & ")" & vbCRLF & _
         "Please check your username/password" & vbCRLF & _
         "and run the ABB-Setup script again", 16, "ABB Setup"
  WScript.Quit
End If

SetCookie = objWinHTTP.GetResponseHeader("Set-Cookie")
Cookie = Split(SetCookie, ";")(0)

If Len(SetCookie) = 0 Or Len(Cookie) = 0 Then
  MsgBox "Failed to obtain auth cookie from ABB portal", 16, "ABB Setup"
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Get customer json
'-------------------------------------------------------------------------------

objWinHTTP.Open "GET", CustURL, False
objWinHTTP.setRequestHeader "Cookie", Cookie
objWinHTTP.send

If objWinHTTP.Status <> 200 Then
  MsgBox "Failed to obtain customer info from ABB portal (HTTP Status " & objWinHTTP.Status & ")", 16, "ABB Setup"
  WScript.Quit
End If

CustomerJSON = objWinHTTP.ResponseText

If Len(CustomerJSON) = 0 Then
  MsgBox "Failed to obtain customer info from ABB portal (zero length)", 16, "ABB Setup"
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Parse customer json
'-------------------------------------------------------------------------------

Set objCustomerJSON = parse_json(CustomerJSON)

ServiceID = objCustomerJSON.services.NBN.[0].service_id

If Len(ServiceID) = 0 Then
  MsgBox "Failed to obtain NBN Service ID from customer info (zero length)", 16, "ABB Setup"
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Save user config
'-------------------------------------------------------------------------------

Set fileHandle = objFS.CreateTextFile(ConfigFile, True)
fileHandle.writeline "Username = " & Username & " <<< Your ABB username"
fileHandle.writeline "ServiceID = " & ServiceID & " <<< Your ABB NBN Service ID"
fileHandle.close

'-------------------------------------------------------------------------------
' Encode and save password
'-------------------------------------------------------------------------------

EncodedPassword = Encode(Password, ComputerName)

Set fileHandle = objFS.CreateTextFile(EncodedFile, True)
fileHandle.write EncodedPassword
fileHandle.close

MsgBox "Setup has completed successfully" & vbCRLF & vbCRLF & _
       "(Your ABB NBN Service ID is " & ServiceID & ")", 64, "ABB Setup"

'-------------------------------------------------------------------------------
' Private Function - parse_item
'-------------------------------------------------------------------------------

Private Function parse_item(ByRef contents, start_tag, end_tag)

  Dim position, item

  position = InStr(1, contents, start_tag, vbTextCompare)

  If position > 0 Then
    contents = Mid(contents, position + Len(start_tag))
    position = InStr(1, contents, end_tag, vbTextCompare)

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
' Function - parse_json
'-------------------------------------------------------------------------------

Function parse_json(JsonStr)

  Dim objHtmlFile, pWindow

  Set objHtmlFile = CreateObject("htmlfile")
  Set pWindow = objHtmlFile.parentWindow

  pWindow.execScript "var json = " & JsonStr, "JScript"

  Set parse_json = pWindow.json

End Function

'-------------------------------------------------------------------------------
' Function - Encode
'-------------------------------------------------------------------------------

Function Encode(Str, SeedStr)

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
    NewStr = NewStr & chr(Int(asc(Mid(Str, x, 1))) + Int(asc(Mid(SeedStr, x, 1))) - 20)
  Next

  Encode = NewStr

End Function

'-------------------------------------------------------------------------------
' Private Function - Ceiling
'-------------------------------------------------------------------------------

Private Function Ceiling(byval n)

  Dim fTmp

  n = cdbl(n)
  fTmp = Floor(n)

  If fTmp = n Then
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

  If rTmp > n Then
    rTmp = rTmp - 1
  End If

  Floor = cInt(rTmp)

End Function

' EOF
