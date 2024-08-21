' Description: Backend script for ABBUsage Rainmeter skin by Big Kahuna
' Author: Protogen at whirlpool (skin by Big Kahuna)
' Version: 3.5.2
' Date: 5 August 2024

'-------------------------------------------------------------------------------
' Environment, constants, global variables
'-------------------------------------------------------------------------------

Option Explicit

Const rspName = "ABB"

Const forReading = 1
Const forWriting = 2
Const forAppending = 8

Const debugMode = False

Dim appTitle
appTitle = rspName & " Usage"

Dim objDebugLog
Set objDebugLog = New DebugLog

'-------------------------------------------------------------------------------
' Command line arguments
'-------------------------------------------------------------------------------

Dim invalidArgs
invalidArgs = False

If WScript.Arguments.Count = 2 Or WScript.Arguments.Count = 3 Then

  ' Set the debug log name
  objDebugLog.Logname = WScript.Arguments.Item(0) & "-" & WScript.Arguments.Item(1)
  objDebugLog.Logname = Replace(objDebugLog.Logname, ".ini", "")
  objDebugLog.Logname = Replace(objDebugLog.Logname, "\", "-")

  appTitle = appTitle & " [" & WScript.Arguments.Item(0) & "\" & WScript.Arguments.Item(1) & "]"

  ' Delete old files and update the usage
  If WScript.Arguments.Count = 2 Then
    DeleteOldFiles()
    UpdateUsage WScript.Arguments.Item(0), WScript.Arguments.Item(1)

  ' Delete the skin config (partial reset) and update the usage
  ElseIf WScript.Arguments.Item(2) = "clean" Then
    CleanConfig WScript.Arguments.Item(0), WScript.Arguments.Item(1)
    UpdateUsage WScript.Arguments.Item(0), WScript.Arguments.Item(1)

  ' Invalid arguments
  Else
    invalidArgs = True
  End If

ElseIf WScript.Arguments.Count = 1 Then

  ' Delete everything (full reset)
  If WScript.Arguments.Item(0) = "clean" Then
    objDebugLog.Logname = "Clean"
    CleanConfig "", ""

  ' Invalid arguments
  Else
    invalidArgs = True
  End If

' Invalid arguments
Else
  invalidArgs = True
End If

If invalidArgs = True Then
  MsgBox "This script cannot be run directly." & vbCRLF & vbCRLF & _
         "It can only be run via Rainmeter refresh (because" & vbCRLF & _
         "it requires arguments passed in from Rainmeter).", 16, appTitle
  WScript.Quit
End If

'-------------------------------------------------------------------------------
' Sub - DeleteOldFiles
'-------------------------------------------------------------------------------

Sub DeleteOldFiles()
  If debugMode Then objDebugLog.Message "info", "DeleteOldFiles", "Entering Sub DeleteOldFiles"

  Dim objShell, objFS, appData, appDir
  Set objShell = CreateObject("WScript.Shell")
  Set objFS = CreateObject("Scripting.FileSystemObject")

  appData = objShell.ExpandEnvironmentStrings("%APPDATA%")
  appDir = "Rainmeter-" & rspName

  Dim arrPaths, strPath, arrOldFiles, strOldFile, deleteEverything

  arrPaths = Array("", appData & "\" & appDir & "\")
  arrOldFiles = Array("Common.vbs", "Setup.vbs", "Auth.json", "Service.json", "Usage.json", "Usage.xml", "error.txt", "errors.txt")
  deleteEverything = False

  For Each strPath in arrPaths
    For Each strOldFile in arrOldFiles
      strOldFile = strPath & rspName & "-" & strOldFile
      If objFS.FileExists(strOldFile) Then
        If debugMode Then objDebugLog.Message "info", "DeleteOldFiles", "Deleting old file '" & strOldFile & "'"
        objFS.DeleteFile(strOldFile)
        deleteEverything = True
      End If
    Next
  Next

  If deleteEverything = True Then
    CleanConfig "", ""
  End If
End Sub

'-------------------------------------------------------------------------------
' Sub - UpdateUsage
'-------------------------------------------------------------------------------

Sub UpdateUsage(currentConfig, currentFile)
  If debugMode Then objDebugLog.Message "info", "UpdateUsage", "Entering Sub UpdateUsage"

  Dim objUsage
  Set objUsage = New Usage

  objUsage.CurrentConfig = currentConfig
  objUsage.CurrentFile   = currentFile

  objUsage.GetUsage()
End Sub

'-------------------------------------------------------------------------------
' Sub - CleanConfig
'-------------------------------------------------------------------------------

Sub CleanConfig(currentConfig, currentFile)
  If debugMode Then objDebugLog.Message "info", "CleanConfig", "Entering Sub CleanConfig"

  Dim objDataFile
  Set objDataFile = New DataFile
  objDataFile.Filename = "Unused-Dummy-Filename"

  If currentConfig <> "" And currentFile <> "" Then
    objDataFile.Subdir = currentConfig & "\" & currentFile
  End If

  objDataFile.DeleteConfigPath()

  If currentConfig = "" And currentFile = "" Then
    MsgBox "All user configuration files have been deleted." & vbCRLF & _
           "Refresh a single skin now to trigger skin setup.", 64, appTitle
  End If
End Sub

'-------------------------------------------------------------------------------
' Class - DebugLog
'-------------------------------------------------------------------------------

Class DebugLog

  Private p_logname
  Private p_filename

  Private Sub Class_Initialize
    p_logname = ""
    p_filename = rspName & "-DebugLog-<LOGNAME>-<YYYY>-<MM>-<DD>.txt"
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - Logname
  '-------------------------------------------------------------------------------

  Public Property Let Logname(ByVal strLogname)
    p_logname = strLogname
  End Property

  Public Property Get Logname()
    Logname = p_logname
  End Property

  '-------------------------------------------------------------------------------
  ' Property - Filename
  '-------------------------------------------------------------------------------

  Public Property Let Filename(ByVal strFilename)
    p_filename = strFilename
  End Property

  Public Property Get Filename()
    Dim today, resolvedFilename

    today = Now()
    resolvedFilename = p_filename
    resolvedFilename = Replace(resolvedFilename, "<LOGNAME>", Me.Logname)
    resolvedFilename = Replace(resolvedFilename, "<YYYY>", Year(today))
    resolvedFilename = Replace(resolvedFilename, "<MM>", Right("0" & Month(today), 2))
    resolvedFilename = Replace(resolvedFilename, "<DD>", Right("0" & Day(today), 2))

    Filename = resolvedFilename
  End Property

  '-------------------------------------------------------------------------------
  ' Sub - Message
  '-------------------------------------------------------------------------------

  Public Sub Message(strLevel, strCaller, strMessage)
    Dim objLogFile, strLogMessage
    Set objLogFile = OpenLogFile()

    strLogMessage = TimeStamp() & " <" & strLevel & "> " & strCaller & ": " & strMessage

    objLogFile.WriteLine strLogMessage
    objLogFile.close
  End Sub

  '-------------------------------------------------------------------------------
  ' Function - OpenLogFile
  '-------------------------------------------------------------------------------

  Private Function OpenLogFile()
    Dim objFS, strFilename
    Set objFS = CreateObject("Scripting.FileSystemObject")

    strFilename = Me.Filename

    If objFS.FileExists(strFilename) Then
      Set OpenLogFile = objFS.OpenTextFile(strFilename, forAppending)
    Else
      MsgBox "Debug mode is currently enabled." & vbCRLF & _
             "If not required, please disable.", 48, appTitle
      Set OpenLogFile = objFS.CreateTextFile(strFilename, True)
    End If
  End Function

  '-------------------------------------------------------------------------------
  ' Function - TimeStamp
  '-------------------------------------------------------------------------------

  Private Function TimeStamp()
    Dim strNow, singTimer, milliseconds
    Dim strDate, strTime, strMilliseconds

    strNow = Now()
    singTimer = Timer()
    milliseconds = Int((singTimer - Int(singTimer)) * 1000)

    strDate =             Year(strNow)     & "-" & Right("0" &  Month(strNow), 2) & "-" & Right("0" &    Day(strNow), 2)
    strTime = Right("0" & Hour(strNow), 2) & ":" & Right("0" & Minute(strNow), 2) & ":" & Right("0" & Second(strNow), 2)
    strMilliseconds = Right("000" & CStr(milliseconds), 4)

    TimeStamp = strDate & "T" & strTime & "." & strMilliseconds
  End Function

End Class

'-------------------------------------------------------------------------------
' Class - AuthCookie
'-------------------------------------------------------------------------------

Class AuthCookie

  Private p_cookie
  Private p_expiry

  Private Sub Class_Initialize
    p_cookie = ""
    p_expiry = ""
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - Cookie
  '-------------------------------------------------------------------------------

  Public Property Let Cookie(ByVal strCookie)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Cookie"

    p_cookie = strCookie
  End Property

  Public Property Get Cookie()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Cookie"

    Cookie = p_cookie
  End Property

  '-------------------------------------------------------------------------------
  ' Property - Expiry
  '-------------------------------------------------------------------------------

  Public Property Let Expiry(ByVal strExpiry)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Expiry"

    p_expiry = strExpiry
  End Property

  Public Property Get Expiry()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Expiry"

    Expiry = p_expiry
  End Property

  '-------------------------------------------------------------------------------
  ' Property - SetCookie
  '-------------------------------------------------------------------------------

  Public Property Let SetCookie(ByVal strSetCookie)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let SetCookie"

    Dim objRegExpCookie, strCookie, strExpiry
    Set objRegExpCookie = New RegExp

    ' Extract the correct 'Set-Cookie:' line from all response headers
    objRegExpCookie.Pattern = "[\s\S]*\r\n(Set-Cookie:\s+myaussie_cookie=.+)\r\n[\s\S]*"
    strSetCookie = objRegExpCookie.Replace(strSetCookie, "$1")

    ' Extract the 'myaussie_cookie=' cookie field from the line
    objRegExpCookie.Pattern = "^.+(myaussie_cookie=[^;]+);.+$"
    strCookie = objRegExpCookie.Replace(strSetCookie, "$1")

    ' Extract the 'expires=' date field from the line
    objRegExpCookie.Pattern = "^.*expires=\w+,\s*(\d+(?:\s+|-)\w+(?:\s+|-)\d+\s+\d+:\d+:\d+)\s.*$"
    strExpiry = objRegExpCookie.Replace(strSetCookie, "$1")

    If IsEmpty(strCookie) Or strCookie = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "Cookie is undefined or blank"
      WScript.Quit
    End If

    If IsEmpty(strExpiry) Or strExpiry = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "Expiry is undefined or blank"
      WScript.Quit
    End If

    If debugMode Then
      objDebugLog.Message "info", TypeName(Me), "Cookie length = '" & Len(strCookie) & "'"
      objDebugLog.Message "info", TypeName(Me), "Cookie Expiry = '" & strExpiry & "'"
    End If

    Me.Cookie = strCookie
    Me.Expiry = strExpiry
  End Property

  '-------------------------------------------------------------------------------
  ' Function - HalfWayToExpiry
  '-------------------------------------------------------------------------------

  Public Function HalfWayToExpiry(strExpiresIn)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function HalfWayToExpiry"

    If Me.Expiry = "" Then
      If debugMode Then objDebugLog.Message "warning", TypeName(Me), "Expiry is not set"
      Exit Function
    End If

    Dim expiryDays, halfWayDays

    expiryDays = DateDiff("d", Now(), Me.Expiry)
    halfWayDays = Int(CLng(strExpiresIn) / (60 * 60 * 24 * 2))

    If debugMode Then
      objDebugLog.Message "info", TypeName(Me), "expiryDays = '" & expiryDays & "'"
      objDebugLog.Message "info", TypeName(Me), "halfWayDays = '" & halfWayDays & "'"
    End If

    If expiryDays < halfWayDays Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Cookie is over half way to expiry"
      HalfWayToExpiry = True
    Else
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Cookie is under half way to expiry"
      HalfWayToExpiry = False
    End If
  End Function

End Class

'-------------------------------------------------------------------------------
' Class - RefreshToken
'-------------------------------------------------------------------------------

Class RefreshToken

  Private p_token
  Private p_expiresIn

  Private Sub Class_Initialize
    p_token = ""
    p_expiresIn = ""
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - Token
  '-------------------------------------------------------------------------------

  Public Property Let Token(ByVal strToken)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Token"

    p_token = strToken
  End Property

  Public Property Get Token()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Token"

    Token = p_token
  End Property

  '-------------------------------------------------------------------------------
  ' Property - ExpiresIn
  '-------------------------------------------------------------------------------

  Public Property Let ExpiresIn(ByVal strExpiresIn)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let ExpiresIn"

    p_expiresIn = strExpiresIn
  End Property

  Public Property Get ExpiresIn()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get ExpiresIn"

    ExpiresIn = p_expiresIn
  End Property

End Class

'-------------------------------------------------------------------------------
' Class - DataFile
'-------------------------------------------------------------------------------

Class DataFile

  Private AppPath
  Private p_subdir
  Private p_filename
  Private p_file
  Private p_contents

  Private Sub Class_Initialize
    AppPath = GetAppPath()
    p_subdir = ""
    p_filename = ""
    p_file = ""
    p_contents = ""
  End Sub

  '-------------------------------------------------------------------------------
  ' Function - GetAppPath
  '-------------------------------------------------------------------------------

  Private Function GetAppPath()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function GetAppPath"

    Dim objShell, appData, appDir, appPath
    Set objShell = CreateObject("WScript.Shell")

    appData = objShell.ExpandEnvironmentStrings("%APPDATA%")
    appDir = "Rainmeter-" & rspName
    appPath = appData & "\" & appDir

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "AppPath = '" & appPath & "'"

    GetAppPath = appPath
  End Function

  '-------------------------------------------------------------------------------
  ' Property - Subdir
  '-------------------------------------------------------------------------------

  Public Property Let Subdir(ByVal strSubdir)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Subdir"

    p_subdir = strSubdir

    Dim strFile
    strFile = AppPath & "\" & Me.Subdir & "\" & Me.Filename
    Me.File = strFile
  End Property

  Public Property Get Subdir()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Subdir"

    Subdir = p_subdir
  End Property

  '-------------------------------------------------------------------------------
  ' Property - Filename
  '-------------------------------------------------------------------------------

  Public Property Let Filename(ByVal strFilename)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Filename"

    p_filename = rspName & "-" & strFilename

    Dim strFile
    strFile = AppPath & "\" & Me.Subdir & "\" & Me.Filename
    Me.File = strFile
  End Property

  Public Property Get Filename()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Filename"

    Filename = p_filename
  End Property

  '-------------------------------------------------------------------------------
  ' Property - File
  '-------------------------------------------------------------------------------

  Public Property Let File(ByVal strFile)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let File"

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "File = '" & strFile & "'"

    p_file = strFile
  End Property

  Public Property Get File()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get File"

    File = p_file
  End Property

  '-------------------------------------------------------------------------------
  ' Property - Contents
  '-------------------------------------------------------------------------------

  Public Property Let Contents(ByVal appFileData)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Contents"

    If Not IsFilenameSet() Then Exit Property
    EnsureFilePathExists()

    Dim appFilename
    appFilename = Me.File

    If debugMode Then
      objDebugLog.Message "info", TypeName(Me), "Saving contents of '" & appFilename & "'"
      objDebugLog.Message "info", TypeName(Me), "Contents length = '" & Len(appFileData) & "'"
    End If

    Dim objFS, objTextFile
    Set objFS = CreateObject("Scripting.FileSystemObject")
    Set objTextFile = objFS.CreateTextFile(appFilename, True)

    objTextFile.WriteLine appFileData
    objTextFile.close

    p_contents = appFileData
  End Property

  Public Property Get Contents()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Contents"

    If Not IsFilenameSet() Then Exit Property

    If p_contents <> "" Then
      Contents = p_contents
      Exit Property
    End If

    Dim objFS, appFilename, objTextFile, appFileData
    Set objFS = CreateObject("Scripting.FileSystemObject")
    appFilename = Me.File
    Set objTextFile = objFS.OpenTextFile(appFilename, forReading)

    appFileData = objTextFile.ReadAll
    objTextFile.close

    If debugMode Then
      objDebugLog.Message "info", TypeName(Me), "Loaded contents of '" & appFilename & "'"
      objDebugLog.Message "info", TypeName(Me), "Contents length = '" & Len(appFileData) & "'"
    End If

    p_contents = appFileData
    Contents = appFileData
  End Property

  '-------------------------------------------------------------------------------
  ' Function - FileExists
  '-------------------------------------------------------------------------------

  Public Function FileExists()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function FileExists"

    If Not IsFilenameSet() Then Exit Function

    Dim objFS, appFilename
    Set objFS = CreateObject("Scripting.FileSystemObject")

    appFilename = Me.File

    If objFS.FileExists(appFilename) Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "File '" & appFilename & "' exists"
      FileExists = True
    Else
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "File '" & appFilename & "' does not exist"
      FileExists = False
    End If
  End Function

  '-------------------------------------------------------------------------------
  ' Function - IsFilenameSet
  '-------------------------------------------------------------------------------

  Private Function IsFilenameSet()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function IsFilenameSet"

    Dim appFilename
    appFilename = Me.Filename

    If appFilename = "" Then
      If debugMode Then objDebugLog.Message "warning", TypeName(Me), "Filename is not set"
      IsFilenameSet = False
    Else
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Filename is set"
      IsFilenameSet = True
    End If
  End Function

  '-------------------------------------------------------------------------------
  ' Sub - EnsureFilePathExists
  '-------------------------------------------------------------------------------

  Private Sub EnsureFilePathExists()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub EnsureFilePathExists"

    Dim objFS, filePath
    Set objFS = CreateObject("Scripting.FileSystemObject")

    filePath = objFS.GetParentFolderName(Me.File)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Ensuring path '" & filePath & "' exists"
    CreatePath(filePath)
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - CreatePath
  '-------------------------------------------------------------------------------

  Private Sub CreatePath(absPath)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub CreatePath"

    Dim objFS
    Set objFS = CreateObject("Scripting.FileSystemObject")

    If objFS.FolderExists(absPath) Then
      Exit Sub
    End If

    CreatePath(objFS.GetParentFolderName(absPath))
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Creating folder '" & absPath & "'"
    objFS.CreateFolder(absPath)
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - DeleteConfigPath
  '-------------------------------------------------------------------------------

  Public Sub DeleteConfigPath()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub DeleteConfigPath"

    Dim objFS, configPath
    Set objFS = CreateObject("Scripting.FileSystemObject")

    configPath = AppPath

    If Me.Subdir <> "" Then
      configPath = AppPath & "\" & Me.Subdir
    End If

    If Not objFS.FolderExists(configPath) Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Folder '" & configPath & "' does not exist"
      Exit Sub
    End If

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Deleting folder '" & configPath & "'"

    objFS.DeleteFolder(configPath)
  End Sub

End Class

'-------------------------------------------------------------------------------
' Class - HTTPRequest
'-------------------------------------------------------------------------------

Class HTTPRequest

  Public Request
  Public URL
  Public Cookie

  Public Username
  Public Password
  Public RefreshToken

  Public SetCookie
  Public ResponseText

  Private Sub Class_Initialize
    Request = ""
    URL = ""
    Cookie = ""

    Username = ""
    Password = ""
    RefreshToken = ""

    SetCookie = ""
    ResponseText = ""
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - Send
  '-------------------------------------------------------------------------------

  Public Sub Send()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub Send"

    Dim objWinHTTP, sendParams
    Set objWinHTTP = CreateObject("WinHTTP.WinHTTPRequest.5.1")

    objWinHTTP.Open Request, URL, False

    If Request = "POST" Or Request = "PUT" Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Setting header Content-Type: application/x-www-form-urlencoded"
      objWinHTTP.SetRequestHeader "Content-Type", "application/x-www-form-urlencoded"
    End If

    If Cookie <> "" Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Setting header Cookie"
      objWinHTTP.SetRequestHeader "Cookie", Cookie
    End If

    If RefreshToken <> "" Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Adding send parameter refreshToken"
      sendParams = "refreshToken=" & PercentEncode(RefreshToken)
    ElseIf Username <> "" And Password <> "" Then
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Adding send parameter username and password"
      sendParams = "username=" & PercentEncode(Username) & "&password=" & PercentEncode(Password)
    End If

    On Error Resume Next

    If IsEmpty(sendParams) Then
      objWinHTTP.Send
    Else
      objWinHTTP.Send sendParams
    End If

    If Err.Number <> 0 Then
      If debugMode Then
        objDebugLog.Message "error", TypeName(Me), "Request "     & Request         & _
                                                   "; URL "       & URL             & _
                                                   "; ErrNumber " & Err.Number      & _
                                                   "; ErrDesc "   & Replace(Err.Description, vbCRLF, "")
      End If
      If Username <> "" And Password <> "" Then
        MsgBox "Failed to obtain an authentication cookie from the " & rspName & " portal." & vbCRLF & _
               "Possible network error - please check your connection and try again." & vbCRLF & vbCRLF & _
               "(If the problem persists, post the issue on whirlpool)", 16, appTitle
      End If
      WScript.Quit
    End If

    If objWinHTTP.Status <> 200 Then
      If debugMode Then
        objDebugLog.Message "error", TypeName(Me), "Request "      & Request               & _
                                                   "; URL "        & URL                   & _
                                                   "; Status "     & objWinHTTP.Status     & _
                                                   "; StatusText " & objWinHTTP.StatusText
      End If
      If Username <> "" And Password <> "" Then
        MsgBox "Failed to obtain an authentication cookie from the " & rspName & " portal." & vbCRLF & _
               "Please check your username and password and try again." & vbCRLF & vbCRLF & _
               "(If the problem persists, post the issue on whirlpool)", 16, appTitle
      End If
      WScript.Quit
    End If

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Request was successful"

    SetCookie = objWinHTTP.GetAllResponseHeaders()
    ResponseText = objWinHTTP.ResponseText
  End Sub

  '-------------------------------------------------------------------------------
  ' Function - PercentEncode
  '-------------------------------------------------------------------------------

  Private Function PercentEncode(strPlain)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function PercentEncode"

    Dim strEncoded, index, currentChar, ansiVal

    For index = 1 to Len(strPlain)
      currentChar = Mid(strPlain, index, 1)
      ansiVal = Asc(currentChar)

      ' Do not encode numbers, uppercase and lowercase letters
      ' Encode everything else
      If (ansiVal >= 48 And ansiVal <= 57) Or _
         (ansiVal >= 65 And ansiVal <= 90) Or _
         (ansiVal >= 97 And ansiVal <= 122) Then
        strEncoded = strEncoded & currentChar
      Else
        strEncoded = strEncoded & "%" & Right("00" & Hex(ansiVal), 2)
      End If
    Next

    PercentEncode = strEncoded
  End Function

End Class

'-------------------------------------------------------------------------------
' Class - JSON
'-------------------------------------------------------------------------------

Class JSON

  Private p_jsonStruct

  '-------------------------------------------------------------------------------
  ' Property - JSONText, JSONStruct
  '-------------------------------------------------------------------------------

  Public Property Let JSONText(ByVal strJSON)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let JSONText"

    Dim objHTMLFile, parentWindow
    Set objHTMLFile = CreateObject("HTMLFile")
    Set parentWindow = objHTMLFile.parentWindow

    parentWindow.execScript "var json = " & strJSON, "JScript"

    Set p_jsonStruct = parentWindow.json
  End Property

  Public Property Get JSONStruct()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get JSONStruct"

    Set JSONStruct = p_jsonStruct
  End Property

End Class

'-------------------------------------------------------------------------------
' Class - Auth
'-------------------------------------------------------------------------------

Class Auth

  Private p_subdir
  Private objAuthFile
  Public objAuthCookie
  Private objRefreshToken
  Private authURL

  Private Sub Class_Initialize
    p_subdir = ""
    Set objAuthFile = New DataFile
    objAuthFile.Filename = "Auth.json"
    Set objAuthCookie = New AuthCookie
    Set objRefreshToken = New RefreshToken
    authURL = "https://myaussie-auth.aussiebroadband.com.au/login"
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - Subdir
  '-------------------------------------------------------------------------------

  Public Property Let Subdir(ByVal strSubdir)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Subdir"

    p_subdir = strSubdir

    objAuthFile.Subdir = Me.Subdir
  End Property

  Public Property Get Subdir()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Subdir"

    Subdir = p_subdir
  End Property

  '-------------------------------------------------------------------------------
  ' Sub - GetAuth
  '-------------------------------------------------------------------------------

  Public Sub GetAuth()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub GetAuth"

    If Not objAuthFile.FileExists() Then CreateAuth()
    LoadAuth()

    If objAuthCookie.HalfWayToExpiry(objRefreshToken.ExpiresIn) Then
      RefreshAuth()
      LoadAuth()
    End If
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - CreateAuth
  '-------------------------------------------------------------------------------

  Private Sub CreateAuth()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub CreateAuth"

    Dim objHTTPRequest, username, password, strMessage, intClickVal
    Set objHTTPRequest = New HTTPRequest

    username = InputBox("Please enter your " & rspName & " portal username" & vbCRLF & _
                        "(Your username will not be saved or stored)", appTitle)
    If username = "" Then WScript.Quit

    password = InputBox("Please enter your " & rspName & " portal password" & vbCRLF & _
                        "(Your password will not be saved or stored)", appTitle)
    If password = "" Then WScript.Quit

    strMessage = "Your username and password will now be used to" & vbCRLF & _
                 "obtain an authentication cookie from the " & rspName & " portal."

    intClickVal = MsgBox(strMessage, 64, appTitle)

    objHTTPRequest.Request = "POST"
    objHTTPRequest.URL = authURL
    objHTTPRequest.Username = username
    objHTTPRequest.Password = password
    objHTTPRequest.Send()

    SaveAuth(objHTTPRequest)
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - LoadAuth
  '-------------------------------------------------------------------------------

  Private Sub LoadAuth()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub LoadAuth"

    Dim objJSON
    Set objJSON = New JSON

    objJSON.JSONText = objAuthFile.Contents

    objAuthCookie.Cookie = objJSON.JSONStruct.Cookie
    objAuthCookie.Expiry = objJSON.JSONStruct.CookieExpiry

    objRefreshToken.Token     = objJSON.JSONStruct.RefreshToken
    objRefreshToken.ExpiresIn = objJSON.JSONStruct.ExpiresIn

    If debugMode Then
      objDebugLog.Message "info", TypeName(Me), "CookieExpiry = '" & objAuthCookie.Expiry      & "'"
      objDebugLog.Message "info", TypeName(Me), "ExpiresIn = '"    & objRefreshToken.ExpiresIn & "'"
    End If
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - RefreshAuth
  '-------------------------------------------------------------------------------

  Private Sub RefreshAuth()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub RefreshAuth"

    Dim objHTTPRequest
    Set objHTTPRequest = New HTTPRequest

    objHTTPRequest.Request = "PUT"
    objHTTPRequest.URL = authURL
    objHTTPRequest.Cookie = objAuthCookie.Cookie
    objHTTPRequest.RefreshToken = objRefreshToken.Token
    objHTTPRequest.Send()

    SaveAuth(objHTTPRequest)
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - SaveAuth
  '-------------------------------------------------------------------------------

  Private Sub SaveAuth(objHTTPRequest)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub SaveAuth"

    objAuthCookie.SetCookie = objHTTPRequest.SetCookie

    Dim objJSON, authFileContents
    Set objJSON = New JSON

    objJSON.JSONText = objHTTPRequest.ResponseText

    objRefreshToken.Token     = objJSON.JSONStruct.refreshToken
    objRefreshToken.ExpiresIn = objJSON.JSONStruct.expiresIn

    authFileContents = _
      "{"                                                          & vbCRLF & _
      "  ""Cookie"": """       & objAuthCookie.Cookie      & """," & vbCRLF & _
      "  ""CookieExpiry"": """ & objAuthCookie.Expiry      & """," & vbCRLF & _
      "  ""RefreshToken"": """ & objRefreshToken.Token     & """," & vbCRLF & _
      "  ""ExpiresIn"": """    & objRefreshToken.ExpiresIn & """"  & vbCRLF & _
      "}"

    objAuthFile.Contents = authFileContents
  End Sub

End Class

'-------------------------------------------------------------------------------
' Class - UserSelection
'-------------------------------------------------------------------------------

Class UserSelection

  Private p_desc
  Private p_dict

  '-------------------------------------------------------------------------------
  ' Property - Desc
  '-------------------------------------------------------------------------------

  Public Property Let Desc(strDesc)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Desc"

    p_desc = strDesc
  End Property

  Public Property Get Desc()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Desc"

    Desc = p_desc
  End Property

  '-------------------------------------------------------------------------------
  ' Property - Dict
  '-------------------------------------------------------------------------------

  Public Property Let Dict(objDict)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Dict"

    Set p_dict = objDict
  End Property

  Public Property Get Dict()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Dict"

    Set Dict = p_dict
  End Property

  '-------------------------------------------------------------------------------
  ' Function - GetUserSelection
  '-------------------------------------------------------------------------------

  Public Function GetUserSelection()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function GetUserSelection"

    Dim arrDictKeys, strMessage, index, userResponse

    arrDictKeys = Me.Dict.Keys
    strMessage = "Please select the " & Me.Desc & " for this skin" & vbCRLF & vbCRLF
    For index = 1 to Me.Dict.Count
      strMessage = strMessage & CStr(index) & " - " & arrDictKeys(index - 1) & vbCRLF
    Next
    strMessage = strMessage & vbCRLF & "Selection (1 - " & Me.Dict.Count & ")?"

    Do Until 1 <= userResponse And userResponse <= Me.Dict.Count
      userResponse = InputBox(strMessage, appTitle)
      If IsNumeric(userResponse) Then
        userResponse = CInt(userResponse)
      Else
        userResponse = 0
      End If
    Loop

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User response = '" & userResponse & "'"

    GetUserSelection = arrDictKeys(userResponse - 1)
  End Function

End Class

'-------------------------------------------------------------------------------
' Class - Options
'-------------------------------------------------------------------------------

Class Options

  Private p_subdir
  Private objOptionsFile

  Private Sub Class_Initialize
    p_subdir = ""
    Set objOptionsFile = New DataFile
    objOptionsFile.Filename = "Options.xml"
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - Subdir
  '-------------------------------------------------------------------------------

  Public Property Let Subdir(ByVal strSubdir)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Subdir"

    p_subdir = strSubdir

    objOptionsFile.Subdir = Me.Subdir
  End Property

  Public Property Get Subdir()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Subdir"

    Subdir = p_subdir
  End Property

  '-------------------------------------------------------------------------------
  ' Sub - EnsureOptionsExist
  '-------------------------------------------------------------------------------

  Public Sub EnsureOptionsExist()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub EnsureOptionsExist"

    If Me.Subdir = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "Subdir is not set"
      Exit Sub
    End If

    If objOptionsFile.FileExists() Then Exit Sub

    CreateOptions()
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - CreateOptions
  '-------------------------------------------------------------------------------

  Private Sub CreateOptions()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub CreateOptions"

    Dim strBarStyleSize, strFontSize, strNominalAllowance, optionsFileContents

    strBarStyleSize     = GetBarStyleSize()
    strFontSize         = GetFontSize()
    strNominalAllowance = GetNominalAllowance()

    optionsFileContents = _
      "<options>"                                                          & vbCRLF & _
      "  <barstylesize>"     & strBarStyleSize     & "</barstylesize>"     & vbCRLF & _
      "  <font>"             & strFontSize         & "</font>"             & vbCRLF & _
      "  <nominalallowance>" & strNominalAllowance & "</nominalallowance>" & vbCRLF & _
      "</options>"

    objOptionsFile.Contents = optionsFileContents
  End Sub

  '-------------------------------------------------------------------------------
  ' Function - GetBarStyleSize
  '-------------------------------------------------------------------------------

  Private Function GetBarStyleSize()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function GetBarStyleSize"

    Dim objDict, objUserSelection, userSelection
    Set objDict = CreateObject("Scripting.Dictionary")
    Set objUserSelection = New UserSelection

    objDict.Add "Dashed 5px", "image5px"
    objDict.Add "Dashed 8px", "image8px"
    objDict.Add "Solid 5px",  "solid5px"
    objDict.Add "Solid 8px",  "solid8px"

    objUserSelection.Desc = "bar style and size"
    objUserSelection.Dict = objDict
    userSelection = objUserSelection.GetUserSelection()

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User selection = '" & objDict(userSelection) & "'"

    GetBarStyleSize = objDict(userSelection)
  End Function

  '-------------------------------------------------------------------------------
  ' Function - GetFontSize
  '-------------------------------------------------------------------------------

  Private Function GetFontSize()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function GetFontSize"

    Dim objDict, objUserSelection, userSelection
    Set objDict = CreateObject("Scripting.Dictionary")
    Set objUserSelection = New UserSelection

    objDict.Add "Small (8px)",   "small"
    objDict.Add "Medium (12px)", "medium"
    objDict.Add "Large (16px)",  "large"

    objUserSelection.Desc = "font size"
    objUserSelection.Dict = objDict
    userSelection = objUserSelection.GetUserSelection()

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User selection = '" & objDict(userSelection) & "'"

    GetFontSize = objDict(userSelection)
  End Function

  '-------------------------------------------------------------------------------
  ' Function - GetNominalAllowance
  '-------------------------------------------------------------------------------

  Private Function GetNominalAllowance()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function GetNominalAllowance"

    Dim intClickVal, strMessage, userResponse

    strMessage = "Do you wish to override the " & rspName & " usage allowance?" & vbCRLF & vbCRLF & _
                 "(If you don't know what this does, choose No)"

    intClickVal = MsgBox(strMessage, 292, appTitle)

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User click value = '" & intClickVal & "'"

    If intClickVal = 7 Then
      GetNominalAllowance = "0"
      Exit Function
    End If

    strMessage = "Please enter the nominal allowance (in GB)" & vbCRLF & _
                 "for this skin" & vbCRLF & vbCRLF & _
                 "Allowance (1 - 100000)?"

    Do Until 1 <= userResponse And userResponse <= 100000
      userResponse = InputBox(strMessage, appTitle)
      If IsNumeric(userResponse) Then
        userResponse = CLng(userResponse)
      Else
        userResponse = 0
      End If
    Loop

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User response = '" & userResponse & "'"

    GetNominalAllowance = CStr(userResponse)
  End Function

End Class

'-------------------------------------------------------------------------------
' Class - Service
'-------------------------------------------------------------------------------

Class Service

  Private p_subdir
  Private objOptions
  Private objServiceFile
  Private p_serviceID
  Private p_serviceName
  Public objAuth
  Private serviceURL

  Private Sub Class_Initialize
    p_subdir = ""
    Set objOptions = New Options
    Set objServiceFile = New DataFile
    objServiceFile.Filename = "Service.json"
    p_serviceID = ""
    p_serviceName = ""
    Set objAuth = New Auth
    serviceURL = "https://myaussie-api.aussiebroadband.com.au/customer"
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - Subdir
  '-------------------------------------------------------------------------------

  Public Property Let Subdir(ByVal strSubdir)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Subdir"

    p_subdir = strSubdir

    objOptions.Subdir = Me.Subdir
    objServiceFile.Subdir = Me.Subdir
    Dim subdirParts
    subdirParts = Split(Me.Subdir, "\")
    objAuth.Subdir = subdirParts(0)
  End Property

  Public Property Get Subdir()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Subdir"

    Subdir = p_subdir
  End Property

  '-------------------------------------------------------------------------------
  ' Property - ServiceID
  '-------------------------------------------------------------------------------

  Public Property Let ServiceID(ByVal strServiceID)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let ServiceID"

    p_serviceID = strServiceID
  End Property

  Public Property Get ServiceID()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get ServiceID"

    ServiceID = p_serviceID
  End Property

  '-------------------------------------------------------------------------------
  ' Property - ServiceName
  '-------------------------------------------------------------------------------

  Public Property Let ServiceName(ByVal strServiceName)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let ServiceName"

    p_serviceName = strServiceName
  End Property

  Public Property Get ServiceName()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get ServiceName"

    ServiceName = p_serviceName
  End Property

  '-------------------------------------------------------------------------------
  ' Sub - GetService
  '-------------------------------------------------------------------------------

  Public Sub GetService()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub GetService"

    If Me.Subdir = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "Subdir is not set"
      Exit Sub
    End If

    objAuth.GetAuth()

    If Not objServiceFile.FileExists() Then CreateService()
    objOptions.EnsureOptionsExist()
    LoadService()
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - CreateService
  '-------------------------------------------------------------------------------

  Private Sub CreateService()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub CreateService"

    Dim objHTTPRequest, objJSON, serviceFileContents
    Dim maxLen, strMessage, objRegExpResponse, userResponse
    Set objHTTPRequest = New HTTPRequest
    Set objJSON = New JSON
    Set objRegExpResponse = New RegExp

    objHTTPRequest.Request = "GET"
    objHTTPRequest.URL = serviceURL
    objHTTPRequest.Cookie = objAuth.objAuthCookie.Cookie
    objHTTPRequest.Send()

    objJSON.JSONText = objHTTPRequest.ResponseText

    Me.ServiceID = GetServiceID(objJSON)

    If IsEmpty(Me.ServiceID) Or Me.ServiceID = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "ServiceID is undefined or blank"
      WScript.Quit
    End If

    maxLen = 16 - Len(Me.ServiceID)
    strMessage = "Your NBN Service ID for this skin is " & Me.ServiceID & vbCRLF & vbCRLF & _
                 "Please enter a name for this service" & vbCRLF & _
                 "(e.g. 'Home', 'Home2', 'Work', 'Primary')" & vbCRLF & vbCRLF & _
                 "Service Name (alphanumeric only; max " & maxLen & " chars)?"

    objRegExpResponse.Pattern = "^\w+$"

    Do Until objRegExpResponse.Test(userResponse)
      userResponse = InputBox(strMessage, appTitle)
    Loop

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User response = '" & userResponse & "'"

    Me.ServiceName = Left(userResponse, maxLen)

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User response (max chars) = '" & userResponse & "'"

    serviceFileContents = _
      "{"                                              & vbCRLF & _
      "  ""ServiceID"": """   & Me.ServiceID   & """," & vbCRLF & _
      "  ""ServiceName"": """ & Me.ServiceName & """"  & vbCRLF & _
      "}"

    objServiceFile.Contents = serviceFileContents
  End Sub

  '-------------------------------------------------------------------------------
  ' Function - GetServiceID
  '-------------------------------------------------------------------------------

  Private Function GetServiceID(objJSON)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Function GetServiceID"

    Dim serviceCount
    serviceCount = objJSON.JSONStruct.services.NBN.Length

    If serviceCount <= 0 Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "NBN array (customer JSON) is empty or missing"
      MsgBox "Failed to obtain an NBN Service ID from the " & rspName & " portal." & vbCRLF & _
             "Possible " & rspName & " portal change - please try again." & vbCRLF & vbCRLF & _
             "(If the problem persists, post the issue on whirlpool)", 16, appTitle
      WScript.Quit
    ElseIf serviceCount = 1 Then
      GetServiceID = objJSON.JSONStruct.services.NBN.[0].service_id
      If debugMode Then objDebugLog.Message "info", TypeName(Me), "Single NBN Service ID found = '" & GetServiceID & "'"
      Exit Function
    End If

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Multiple NBN Service IDs found"

    Dim objDict, index, serviceID, objUserSelection, userSelection
    Set objDict = CreateObject("Scripting.Dictionary")
    Set objUserSelection = New UserSelection

    For index = 0 to (serviceCount - 1)
      serviceID = Eval("objJSON.JSONStruct.services.NBN.[" & index & "].service_id")
      objDict.Add serviceID, serviceID
    Next

    objUserSelection.Desc = "NBN Service ID"
    objUserSelection.Dict = objDict
    userSelection = objUserSelection.GetUserSelection()

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "User selection = '" & objDict(userSelection) & "'"

    GetServiceID = objDict(userSelection)
  End Function

  '-------------------------------------------------------------------------------
  ' Sub - LoadService
  '-------------------------------------------------------------------------------

  Private Sub LoadService()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub LoadService"

    Dim objJSON
    Set objJSON = New JSON

    objJSON.JSONText = objServiceFile.Contents

    Me.ServiceID   = objJSON.JSONStruct.ServiceID
    Me.ServiceName = objJSON.JSONStruct.ServiceName

    If debugMode Then
      objDebugLog.Message "info", TypeName(Me), "ServiceID = '"   & Me.ServiceID   & "'"
      objDebugLog.Message "info", TypeName(Me), "ServiceName = '" & Me.ServiceName & "'"
    End If
  End Sub

End Class

'-------------------------------------------------------------------------------
' Class - Usage
'-------------------------------------------------------------------------------

Class Usage

  Private p_currentConfig
  Private p_currentFile
  Private p_subdir
  Private objUsageFileJSON
  Private objUsageFileXML
  Private objService
  Private usageURL

  Private Sub Class_Initialize
    p_currentConfig = ""
    p_currentFile = ""
    p_subdir = ""
    Set objUsageFileJSON = New DataFile
    objUsageFileJSON.Filename = "Usage.json"
    Set objUsageFileXML = New DataFile
    objUsageFileXML.Filename = "Usage.xml"
    Set objService = New Service
    usageURL = "https://myaussie-api.aussiebroadband.com.au/broadband/<ServiceID>/usage"
  End Sub

  '-------------------------------------------------------------------------------
  ' Property - CurrentConfig
  '-------------------------------------------------------------------------------

  Public Property Let CurrentConfig(ByVal strCurrentConfig)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let CurrentConfig"

    p_currentConfig = strCurrentConfig
  End Property

  Public Property Get CurrentConfig()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get CurrentConfig"

    CurrentConfig = p_currentConfig
  End Property

  '-------------------------------------------------------------------------------
  ' Property - CurrentFile
  '-------------------------------------------------------------------------------

  Public Property Let CurrentFile(ByVal strCurrentFile)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let CurrentFile"

    p_currentFile = strCurrentFile
  End Property

  Public Property Get CurrentFile()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get CurrentFile"

    CurrentFile = p_currentFile
  End Property

  '-------------------------------------------------------------------------------
  ' Property - Subdir
  '-------------------------------------------------------------------------------

  Public Property Let Subdir(ByVal strSubdir)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Let Subdir"

    p_subdir = strSubdir

    objUsageFileJSON.Subdir = Me.Subdir
    objUsageFileXML.Subdir = Me.Subdir
    objService.Subdir = Me.Subdir
  End Property

  Public Property Get Subdir()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Get Subdir"

    Subdir = p_subdir
  End Property

  '-------------------------------------------------------------------------------
  ' Sub - GetUsage
  '-------------------------------------------------------------------------------

  Public Sub GetUsage()
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub GetUsage"

    If Me.CurrentConfig = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "CurrentConfig is not set"
      WScript.Quit
    End If

    If Me.CurrentFile = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "CurrentFile is not set"
      WScript.Quit
    End If

    Me.Subdir = Me.CurrentConfig & "\" & Me.CurrentFile

    Dim objJSON
    Set objJSON = New JSON

    objService.GetService()

    GetUsageJSON(objJSON)
    CreateUsageXML(objJSON)
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - GetUsageJSON
  '-------------------------------------------------------------------------------

  Private Sub GetUsageJSON(objJSON)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub GetUsageJSON"

    Dim objHTTPRequest
    Set objHTTPRequest = New HTTPRequest

    objHTTPRequest.Request = "GET"
    objHTTPRequest.URL = Replace(usageURL, "<ServiceID>", objService.ServiceID)
    objHTTPRequest.Cookie = objService.objAuth.objAuthCookie.Cookie
    objHTTPRequest.Send()

    If IsEmpty(objHTTPRequest.ResponseText) Or objHTTPRequest.ResponseText = "" Then
      If debugMode Then objDebugLog.Message "error", TypeName(Me), "ResponseText is undefined or blank"
      WScript.Quit
    End If

    objUsageFileJSON.Contents = objHTTPRequest.ResponseText
    objJSON.JSONText          = objHTTPRequest.ResponseText

    ' For testing, simulates bad data from ABB
    'objUsageFileJSON.Contents = "{""usedMb"":0,""downloadedMb"":0,""uploadedMb"":0,""daysTotal"":31,""daysRemaining"":11,""remainingMb"":null,""lastUpdated"":null}"
    'objJSON.JSONText          = "{""usedMb"":0,""downloadedMb"":0,""uploadedMb"":0,""daysTotal"":31,""daysRemaining"":11,""remainingMb"":null,""lastUpdated"":null}"

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "JSON " & objHTTPRequest.ResponseText
  End Sub

  '-------------------------------------------------------------------------------
  ' Sub - CreateUsageXML
  '-------------------------------------------------------------------------------

  Private Sub CreateUsageXML(objJSON)
    If debugMode Then objDebugLog.Message "info", TypeName(Me), "Entering Sub CreateUsageXML"

    Dim downBytes, upBytes, allowanceMBytes, leftBytes
    Dim currentTime, lastUpdated, daysRemaining, rolloverDay
    Dim usageFileContents

    downBytes = objJSON.JSONStruct.downloadedMb * 1000 * 1000
    upBytes   = objJSON.JSONStruct.uploadedMb   * 1000 * 1000

    If IsNull(objJSON.JSONStruct.remainingMb) And IsNull(objJSON.JSONStruct.lastUpdated) Then
      ' Bad data (from ABB), use negative values to signal "bad data" to skin
      downBytes       = -1000 * 1000 * 1000
      upBytes         = 0
      allowanceMBytes = -1000
      leftBytes       = 0
    ElseIf IsNull(objJSON.JSONStruct.remainingMb) Then
      ' Unlimited plan, skin uses allowance1_mb >= 100,000,000 as trigger
      allowanceMBytes = 100000000
      leftBytes       = 0
    Else
      ' Good data (from ABB), use actual values from ABB
      allowanceMBytes = objJSON.JSONStruct.usedMb + objJSON.JSONStruct.remainingMb
      leftBytes       = objJSON.JSONStruct.remainingMb * 1000 * 1000
    End If

    If IsNull(objJSON.JSONStruct.lastUpdated) Then
      ' Bad data (from ABB), use current date and time (format: YYYY-MM-DD HH:MM:SS)
      currentTime = Now()
      lastUpdated = Right("20" & Year(currentTime), 4) & "-" & Right("0" & Month(currentTime), 2) & "-" & Right("0" & Day(currentTime), 2) & " "
      lastUpdated = lastUpdated & Right("0" & Hour(currentTime), 2) & ":" & Right("0" & Minute(currentTime), 2) & ":" & Right("0" & Second(currentTime), 2)
    Else
      ' Good data (from ABB), use date and time from ABB
      lastUpdated = objJSON.JSONStruct.lastUpdated
    End If

    daysRemaining = objJSON.JSONStruct.daysRemaining
    rolloverDay = Day(DateAdd("d", daysRemaining, lastUpdated))

    usageFileContents = _
      "<usage>"                                                         & vbCRLF & _
      "  <down1>"         & downBytes              & "</down1>"         & vbCRLF & _
      "  <up1>"           & upBytes                & "</up1>"           & vbCRLF & _
      "  <allowance1_mb>" & allowanceMBytes        & "</allowance1_mb>" & vbCRLF & _
      "  <left1>"         & leftBytes              & "</left1>"         & vbCRLF & _
      "  <lastupdated>"   & lastUpdated            & "</lastupdated>"   & vbCRLF & _
      "  <rollover>"      & rolloverDay            & "</rollover>"      & vbCRLF & _
      "  <serviceid>"     & objService.ServiceID   & "</serviceid>"     & vbCRLF & _
      "  <servicename>"   & objService.ServiceName & "</servicename>"   & vbCRLF & _
      "</usage>"

    objUsageFileXML.Contents = usageFileContents

    If debugMode Then objDebugLog.Message "info", TypeName(Me), "XML " & Replace(Replace(usageFileContents, vbCRLF, ""), " ", "")
  End Sub

End Class

' EOF
