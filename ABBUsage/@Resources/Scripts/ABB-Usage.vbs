'-------------------------------------------------------------------------------
' Environment
'-------------------------------------------------------------------------------

Option Explicit

IncludeScript("ABB-Common.vbs")

'-------------------------------------------------------------------------------
' Global variables and objects
'-------------------------------------------------------------------------------

Const ApplicationFolder = "Rainmeter-ABB"

Dim objShell, AppDir, objFS, AuthFile, ServiceFile, UsageFileJson, UsageFileXml
Dim AuthURL, UsageURL
Dim AuthJson, objAuthJson, ServiceJson, objServiceJson
Dim Cookie, CookieExpiry, RefreshToken, ExpiresIn, Service(2)
Dim CookieExpiryDays, HalfWayDays
Dim objWinHTTP, UsageJson, objUsageJson, UsageXML
Dim DownVal, UpVal, AllowanceMB, LeftVal, LastUpdated, DaysRemaining, RolloverDay
Dim Debug, FileTracking, StartTime

Set objShell = CreateObject( "WScript.Shell")

Set objFS = CreateObject("Scripting.FileSystemObject")

AuthURL = "https://myaussie-auth.aussiebroadband.com.au/login"
UsageURL = "https://myaussie-api.aussiebroadband.com.au/broadband/<ServiceID>/usage"

Debug = False
FileTracking = False

StartTime = Now()

'-------------------------------------------------------------------------------
' Application folder and files
'-------------------------------------------------------------------------------

AppDir = (objShell.ExpandEnvironmentStrings("%APPDATA%")) & "\" & ApplicationFolder

AuthFile = AppDir & "\ABB-Auth.json"
ServiceFile = AppDir & "\ABB-Service.json"

UsageFileJson = "ABB-Usage.json"
UsageFileXml  = "ABB-Usage.xml"

If Not (objFS.FolderExists(AppDir) And _
        objFS.FileExists(AuthFile) And _
        objFS.FileExists(ServiceFile)) Then
  objShell.run("ABB-Setup.vbs")
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Load the config
'-------------------------------------------------------------------------------

LoadConfig()

CookieExpiryDays = DateDiff("d", Now(), CookieExpiry)
HalfWayDays = Int(ExpiresIn / (60 * 60 * 24 * 2))

If CookieExpiryDays < 366 Then
  RefreshCookie()
End If

'-------------------------------------------------------------------------------
' Get the usage
'-------------------------------------------------------------------------------

UsageURL = Replace(UsageURL, "<ServiceID>", Service(0))

Set objWinHTTP = HTTPRequest("GET", UsageURL, Cookie, "", "ABB Usage")

UsageJson = objWinHTTP.ResponseText

If Debug Then
  MsgBox "UsageJson = '" & UsageJson & "'", 64, "Debug"
End If

If Len(UsageJson) = 0 Then
  RaiseException "Usage JSON String", 999, "Failed to obtain usage json from ABB portal (zero length)"
End If

WriteFile UsageFileJson, UsageJson

'-------------------------------------------------------------------------------
' Parse the usage json
'-------------------------------------------------------------------------------

Set objUsageJson = ParseJson(UsageJson)

DownVal = objUsageJson.downloadedMb * 1000 * 1000
UpVal = objUsageJson.uploadedMb * 1000 * 1000

If IsNull(objUsageJson.remainingMb) Then
  ' Unlimited plan (skin uses allowance1_mb >= 100,000,000 as trigger)
  AllowanceMB = 100000000
  LeftVal = 0
Else
  AllowanceMB = objUsageJson.usedMb + objUsageJson.remainingMb
  LeftVal = objUsageJson.remainingMb * 1000 * 1000
End If

LastUpdated = objUsageJson.lastUpdated
DaysRemaining = objUsageJson.daysRemaining

RolloverDay = Day(DateAdd("d", DaysRemaining, LastUpdated))

If Debug Then
  MsgBox "DownVal = '" & DownVal & "'" & vbCRLF & _
         "UpVal = '" & UpVal & "'" & vbCRLF & _
         "AllowanceMB = '" & AllowanceMB & "'" & vbCRLF & _
         "LeftVal = '" & LeftVal & "'" & vbCRLF & _
         "LastUpdated = '" & LastUpdated & "'" & vbCRLF & _
         "DaysRemaining = '" & DaysRemaining & "'" & vbCRLF & _
         "RolloverDay = '" & RolloverDay & "'", 64, "Debug"
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
           "  <rollover>" & RolloverDay & "</rollover>" & vbCRLF & _
           "  <serviceid>" & Service(0) & "</serviceid>" & vbCRLF & _
           "  <servicename>" & Service(1) & "</servicename>" & vbCRLF & _
           "</usage>"

If Debug Then
  MsgBox "UsageXML = '" & UsageXML & "'", 64, "Debug"
End If

WriteFile UsageFileXml, UsageXML

'-------------------------------------------------------------------------------
' Function - LoadConfig
'-------------------------------------------------------------------------------

Sub LoadConfig()

  AuthJson = ReadFile(AuthFile)
  Set objAuthJson = ParseJson(AuthJson)

  Cookie = objAuthJson.Cookie
  CookieExpiry = objAuthJson.CookieExpiry
  RefreshToken = objAuthJson.RefreshToken
  ExpiresIn = objAuthJson.ExpiresIn

  ServiceJson = ReadFile(ServiceFile)
  Set objServiceJson = ParseJson(ServiceJson)

  Service(0) = objServiceJson.ServiceID
  Service(1) = objServiceJson.ServiceName

  If Debug Then
    MsgBox "CookieExpiry = '" & CookieExpiry & "'" & vbCRLF & _
           "ExpiresIn = '" & ExpiresIn & "'" & vbCRLF & _
           "ServiceID = '" & Service(0) & "'" & vbCRLF & _
           "ServiceName = '" & Service(1) & "'", 64, "Debug"
  End If

End Sub

'-------------------------------------------------------------------------------
' Function - RefreshCookie
'-------------------------------------------------------------------------------

Sub RefreshCookie()

  Dim SendParams
  Dim NewCookie, NewRefreshToken

  If Debug Then
    MsgBox "Your ABB portal cookie is about to be refreshed", 64, "ABB Usage"
  End If

  '-------------------------------------------------------------------------------
  ' Refresh the cookie
  '-------------------------------------------------------------------------------

  SendParams = "refreshToken=" & UrlPercentEncode(RefreshToken)

  Set objWinHTTP = HTTPRequest("PUT", AuthURL, Cookie, SendParams, "ABB Usage")

  '-------------------------------------------------------------------------------
  ' Get the new cookie and new refresh token
  '-------------------------------------------------------------------------------

  NewCookie = GetCookie(objWinHTTP.GetResponseHeader("Set-Cookie"), "ABB Usage")

  NewRefreshToken = GetRefreshToken(objWinHTTP.ResponseText, "ABB Usage")

  '-------------------------------------------------------------------------------
  ' Update the config
  '-------------------------------------------------------------------------------

  SaveConfig NewCookie, NewRefreshToken, AuthFile, Service, ServiceFile

  LoadConfig()

End Sub

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
