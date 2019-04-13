'-------------------------------------------------------------------------------
' Function - UrlPercentEncode
'-------------------------------------------------------------------------------

Function UrlPercentEncode(stringToEncode)

  Dim encodedStr, i, currentChar, ansiVal

  encodedStr = ""

  For i = 1 to Len(stringToEncode)

    currentChar = Mid(stringToEncode, i, 1)
    ansiVal = Asc(currentChar)

    ' Numbers or uppercase letters or lowercase letters - do not encode
    If (ansiVal >= 48 And ansiVal <= 57) Or (ansiVal >= 65 And ansiVal <= 90) Or (ansiVal >= 97 And ansiVal <= 122) Then
      encodedStr = encodedStr & currentChar

    ' Everything else - encode
    Else
      encodedStr = encodedStr & "%" & Right("00" & Hex(ansiVal), 2)

    End If

  Next

  UrlPercentEncode = encodedStr

End Function

'-------------------------------------------------------------------------------
' Function - HTTPRequest
'-------------------------------------------------------------------------------

Function HTTPRequest(Request, URL, Cookie, SendParams, ScriptName)

  Dim objWinHTTP

  Set objWinHTTP = CreateObject("WinHTTP.WinHTTPRequest.5.1")

  objWinHTTP.Open Request, URL, False

  If Request = "POST" Or Request = "PUT" Then
    objWinHTTP.SetRequestHeader "Content-Type", "application/x-www-form-urlencoded"
  End If

  If Len(Cookie) > 0 Then
    objWinHTTP.SetRequestHeader "Cookie", Cookie
  End If

  If ScriptName = "ABB Usage" Then
    On Error Resume Next
  End If

  If Len(SendParams) > 0 Then
    objWinHTTP.Send SendParams
  Else
    objWinHTTP.Send
  End If

  If ScriptName = "ABB Usage" And Err.Number <> 0 Then
    RaiseException ScriptName & " VB Error - " & URL, Err.Number, Err.Description
  End If

  If objWinHTTP.Status <> 200 Then
    RaiseException ScriptName & " HTTP " & Request & " request failed", objWinHTTP.Status, objWinHTTP.StatusText
    WScript.Quit
  End If

  Set HTTPRequest = objWinHTTP

End Function

'-------------------------------------------------------------------------------
' Function - GetCookie
'-------------------------------------------------------------------------------

Function GetCookie(SetCookieString, ScriptName)

  Dim CookieParts, objRegExp
  Set objRegExp = New RegExp

  CookieParts = Split(SetCookieString, ";")

  objRegExp.Pattern = "^.* (\d+-\w+-\d+ \d+:\d+:\d+) .*$"

  CookieParts(1) = objRegExp.Replace(CookieParts(1), "$1")

  If Len(CookieParts(0)) = 0 Then
    MsgBox "Failed to obtain auth cookie from ABB portal", 16, ScriptName
    WScript.Quit
  End If

  If Len(CookieParts(1)) = 0 Then
    MsgBox "Failed to obtain auth cookie expiry from ABB portal", 16, ScriptName
    WScript.Quit
  End If

  GetCookie = CookieParts

End Function

'-------------------------------------------------------------------------------
' Function - GetRefreshToken
'-------------------------------------------------------------------------------

Function GetRefreshToken(RefreshTokenJson, ScriptName)

  Dim objRefreshTokenJson, RefreshTokenParts(2)

  If Len(RefreshTokenJson) = 0 Then
    MsgBox "Failed to obtain refresh token json from ABB portal", 16, ScriptName
    WScript.Quit
  End If

  Set objRefreshTokenJson = ParseJson(RefreshTokenJson)

  RefreshTokenParts(0) = objRefreshTokenJson.refreshToken
  RefreshTokenParts(1) = objRefreshTokenJson.expiresIn

  If Len(RefreshTokenParts(0)) = 0 Then
    MsgBox "Failed to obtain refresh token from ABB portal", 16, ScriptName
    WScript.Quit
  End If

  If Len(RefreshTokenParts(1)) = 0 Then
    MsgBox "Failed to obtain refresh token expiry from ABB portal", 16, ScriptName
    WScript.Quit
  End If

  GetRefreshToken = RefreshTokenParts

End Function

'-------------------------------------------------------------------------------
' Function - ParseJson
'-------------------------------------------------------------------------------

Function ParseJson(JsonStr)

  Dim objHtmlFile, pWindow

  Set objHtmlFile = CreateObject("htmlfile")
  Set pWindow = objHtmlFile.parentWindow

  pWindow.execScript "var json = " & JsonStr, "JScript"

  Set ParseJson = pWindow.json

End Function

'-------------------------------------------------------------------------------
' Sub - SaveConfig
'-------------------------------------------------------------------------------

Sub SaveConfig(Cookie, RefreshToken, AuthFile, Service, ServiceFile)

  Dim AuthJson, ServiceJson

  AuthJson = "{" & vbCRLF & _
             "  ""Cookie"": """ & Cookie(0) & """," & vbCRLF & _
             "  ""CookieExpiry"": """ & Cookie(1) & """," & vbCRLF & _
             "  ""RefreshToken"": """ & RefreshToken(0) & """," & vbCRLF & _
             "  ""ExpiresIn"": """ & RefreshToken(1) & """" & vbCRLF & _
             "}"

  WriteFile AuthFile, AuthJson

  ServiceJson = "{" & vbCRLF & _
                "  ""ServiceID"": """ & Service(0) & """," & vbCRLF & _
                "  ""ServiceName"": """ & Service(1) & """" & vbCRLF & _
                "}"

  WriteFile ServiceFile, ServiceJson

End Sub

'-------------------------------------------------------------------------------
' Function - ReadFile
'-------------------------------------------------------------------------------

Function ReadFile(FileName)

  Dim objFS, objTextFile

  Set objFS = CreateObject("Scripting.FileSystemObject")

  Set objTextFile = objFS.OpenTextFile(FileName, 1)

  ReadFile = objTextFile.ReadAll

  objTextFile.close

End Function

'-------------------------------------------------------------------------------
' Sub - WriteFile
'-------------------------------------------------------------------------------

Sub WriteFile(FileName, Contents)

  Dim objFS, objTextFile

  Set objFS = CreateObject("Scripting.FileSystemObject")

  Set objTextFile = objFS.CreateTextFile(FileName, True)

  objTextFile.WriteLine Contents

  objTextFile.close

End Sub

'-------------------------------------------------------------------------------
' Sub - RaiseException
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

  WScript.Quit

End Sub

' EOF
