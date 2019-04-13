'-------------------------------------------------------------------------------
' Environment
'-------------------------------------------------------------------------------

Option Explicit

IncludeScript("ABB-Common.vbs")

'-------------------------------------------------------------------------------
' Global variables and objects
'-------------------------------------------------------------------------------

Const ApplicationFolder = "Rainmeter-ABB"

Dim objShell, AppDir, objFS, AuthFile, ServiceFile
Dim AuthURL, CustURL, Username, Password
Dim SendParams, objWinHTTP, Cookie, RefreshToken
Dim objCustomerJson, MaxServiceNameLen, Service(2)

Set objShell = CreateObject("WScript.Shell")

Set objFS = CreateObject("Scripting.FileSystemObject")

AuthURL = "https://myaussie-auth.aussiebroadband.com.au/login"
CustURL = "https://myaussie-api.aussiebroadband.com.au/customer"

'-------------------------------------------------------------------------------
' Prompt for username and password
'-------------------------------------------------------------------------------

Username = InputBox("Please enter your ABB portal username", "ABB Setup")

If Username = "" Then WScript.Quit

Password = InputBox("Please enter your ABB portal password" & vbCRLF & _
                    "(It will not be saved or stored)", "ABB Setup")

If Password = "" Then WScript.Quit

MsgBox "Setup will now test your username and password" & vbCRLF & _
       "and get your NBN Service ID from the ABB portal", 64, "ABB Setup"

'-------------------------------------------------------------------------------
' Application folder and files
'-------------------------------------------------------------------------------

AppDir = (objShell.ExpandEnvironmentStrings("%APPDATA%")) & "\" & ApplicationFolder

If objFS.FolderExists(AppDir) Then
  objFS.DeleteFolder(AppDir)
End If

If Not objFS.FolderExists(AppDir) Then
  objFS.CreateFolder(AppDir)
End If

AuthFile = AppDir & "\ABB-Auth.json"
ServiceFile = AppDir & "\ABB-Service.json"

'-------------------------------------------------------------------------------
' Test login with username and password
'-------------------------------------------------------------------------------

SendParams = "username=" & UrlPercentEncode(Username) & "&password=" & UrlPercentEncode(Password)

Set objWinHTTP = HTTPRequest("POST", AuthURL, "", SendParams, "ABB Setup")

'-------------------------------------------------------------------------------
' Get the cookie and refresh token
'-------------------------------------------------------------------------------

Cookie = GetCookie(objWinHTTP.GetResponseHeader("Set-Cookie"), "ABB Setup")

RefreshToken = GetRefreshToken(objWinHTTP.ResponseText, "ABB Setup")

'-------------------------------------------------------------------------------
' Get the Service ID
'-------------------------------------------------------------------------------

Set objWinHTTP = HTTPRequest("GET", CustURL, Cookie(0), "", "ABB Setup")

Set objCustomerJson = ParseJson(objWinHTTP.ResponseText)

Service(0) = objCustomerJson.services.NBN.[0].service_id

If Len(Service(0)) = 0 Then
  MsgBox "Failed to obtain NBN Service ID from customer info (zero length)", 16, "ABB Setup"
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Prompt for Service name
'-------------------------------------------------------------------------------

MaxServiceNameLen = 16 - Len(Service(0))

Service(1) = InputBox("Your ABB NBN Service ID is " & Service(0) & vbCRLF & _
                      "Please enter a name for this service" & vbCRLF & _
                      "(i.e 'Home', 'Work', etc; Max " & MaxServiceNameLen & " chars)", "ABB Setup")

If Service(1) = "" Then
  Service(1) = Service(0)
Else
  Service(1) = Left(Service(1), MaxServiceNameLen)
End If

'-------------------------------------------------------------------------------
' Save the config
'-------------------------------------------------------------------------------

SaveConfig Cookie, RefreshToken, AuthFile, Service, ServiceFile

MsgBox "Setup has completed successfully", 64, "ABB Setup"

'-------------------------------------------------------------------------------
' Sub - IncludeScript
'-------------------------------------------------------------------------------

Sub IncludeScript(strFilename)

  Dim objFS, objTextFile

  Set objFS = CreateObject("Scripting.FileSystemObject")
  Set objTextFile = objFS.OpenTextFile(strFilename, 1)

  ExecuteGlobal objTextFile.ReadAll

  objTextFile.Close

End Sub

' EOF
