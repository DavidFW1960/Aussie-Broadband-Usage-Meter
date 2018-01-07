Option Explicit

Dim Debug, FileTracking
Debug = false
FileTracking = false

Dim log_file, ItemCount, SkipFileCheck, UpdateStarted, UpdateTimeStamp, DayStart, WTempDir, Shell, wAppDir, wURLTemp
Dim contents, Item, parsed_data ()
Dim wshShell
Dim wUsername, wPassword, wQuota, wResetDay, wProductID

Const ForReading = 1, ForWriting = 2, ForAppending = 8 
Const ApplicationFolder = "Rainmeter-ABB"

log_file = "ABB"
SkipFileCheck = False

Set shell = WScript.CreateObject( "WScript.Shell" )
wAppDir = (shell.ExpandEnvironmentStrings("%APPDATA%")) & "\"& ApplicationFolder
wTempDir = (shell.ExpandEnvironmentStrings("%TEMP%")) & "\"& ApplicationFolder
Set Shell = Nothing

Private Function Get_Cache_Value (paramString, statfile)
  
  Dim fs, fp, f, fl, wshell, counter, InTime, wParam

  InTime = Now()
  wParam = LCase(Replace(paramString," ",""))

  Set fs = CreateObject ("Scripting.FileSystemObject")

  If (fs.FileExists (wTempDir & "/" & statfile & ".txt")) Then
	
    ' Don't read the file contents while the update is running
    Set f = fs.OpenTextFile (wTempDir & "/" & statfile & ".txt", ForReading)
    contents = f.readall
    f.Close
    
    If InStr(contents,"</endoffile>") > 0 Then
      item = parse_item (contents, "<" & wParam & ">", "</" & wParam & ">")
    Else
      item = "Lock or Bad Read"
    End If
 
    Set fs = Nothing
		
    contents = item

  Else
    contents = "Missing Update File - Check Updating Meter"
  End If

  Get_Cache_Value = contents

End Function

Private Function Floor(byval n)
	Dim iTmp
	n = cdbl(n)
	iTmp = Round(n)
	if iTmp > n then iTmp = iTmp - 1
	Floor = cInt(iTmp)
End Function

Function Ceiling(byval n)
	Dim iTmp, f
	n = cdbl(n)
	f = Floor(n)
	if f = n then
		Ceiling = n
		Exit Function
	End If
	Ceiling = cInt(f + 1)
End Function

Function LastUpdate ()
  
  LastUpdate = Get_Cache_Value("Usage Updated", log_file)

End Function

Function UpdateStats ()

  Dim wxml, wxmlUsage, fs, f, wURL, wSendParams, wCookie, wHeaders, InTime, wUserDetails, NewFormat, objShell, wEtag
 
  InTime = Now()
  UpdateStarted = Now()
  UpdateTimeStamp = Year(UpdateStarted) & MyLpad(Month(UpdateStarted),"0",2) & MyLpad(Day(UpdateStarted),"0",2) & "-" & MyLpad(Hour(UpdateStarted),"0",2) & MyLpad(Minute(UpdateStarted),"0",2) & MyLpad(Second(UpdateStarted),"0",2)
  NewFormat = False
  Set fs = CreateObject ("Scripting.FileSystemObject")

  If NOT (fs.FolderExists(wTempDir)) Then fs.CreateFolder(wTempDir)

  If NOT (fs.FolderExists(wAppDir) AND _
          fs.FileExists(wAppDir & "\" & log_file & "-Configuration.txt") AND _
          fs.FileExists(wAppDir & "\" & "\" & log_file & "-EncrytpedPassword.txt")) Then
    Set objShell = CreateObject("WScript.Shell")
    objShell.run(log_file & "-Setup.vbs")
    Set objShell = Nothing
    wScript.Quit
  End If
  
  Set f = fs.OpenTextFile(wAppDir & "\" & log_file & "-Configuration.txt")
  wUserDetails = f.readall
  f.close
  
  wUserName = parse_item (wUserDetails, "User Name =", "<<<")
  
  Set f = fs.OpenTextFile(wAppDir & "\" & log_file & "-EncrytpedPassword.txt")
  wUserDetails = f.readall
  f.close

  Set wxml = CreateObject("MSXML2.ServerXMLHTTP.6.0")

  wURL = "https://my.aussiebroadband.com.au/usage.php?xml=yes"
  
  wSendParams="login_username=" & wUsername & "&login_password=" & Decrypt(wUserDetails)
  
  wxml.Open "POST", wURL, False

  wxml.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"

  On Error Resume Next
  
  wxml.send wSendParams

 if  Err.Number <> 0 Then   
    RaiseException "Sign On - " & wURL, Err.Number, Err.Description
  End If
  
    Set f = fs.CreateTextFile (log_file & "-Usage.txt", True)
    f.write (wxml.ResponseText)
    f.close


  contents = wxml.ResponseText
  
  Set fs = Nothing

End Function

Private Function parse_item (ByRef contents, start_tag, end_tag)

  Dim position, item
	
  position = InStr (1, contents, start_tag, vbTextCompare)
  
  If position > 0 Then

    contents = mid (contents, position + len (start_tag))
    position = InStr (1, contents, end_tag, vbTextCompare)
		
    If position > 0 Then
      item = mid (contents, 1, position - 1)
    Else
      Item = "Invalid Data"
    End If
  Else
    item = "Invalid Data"
  End If

  parse_item = Trim(Item)

End Function

Sub RaiseException (pErrorSection, pErrorCode, pErrorMessage)

    Dim errfs, errf, errContent
    
    Set errfs = CreateObject ("Scripting.FileSystemObject")
    Set errf = errfs.CreateTextFile(log_file & "-errors.txt", True)
    
    errContent = Now() & vbCRLF & vbCRLF & _
                 pErrorSection & vbCRLF & _
                 "Error Code: " & pErrorCode & vbCRLF & _
                 "--------------------------------------" & vbCRLF & _
                 pErrorMessage
    errf.write errContent
    errf.close
    
    If FileTracking Then
      Set errf = errfs.CreateTextFile (log_file & "-errors-" & UpdateTimeStamp & ".txt", True)
      errf.write errContent
      errf.close
    End If

    Set errf = Nothing
    
    If errfs.FileExists(log_file & "-Updating.txt") Then errfs.DeleteFile(log_file & "-Updating.txt") 

    Set errfs = Nothing
    
    WScript.Quit

End Sub

Function Decrypt(Str)

  Dim Key, NewStr, LenStr, LenKey, wsh, x
   
  set wsh = WScript.CreateObject( "WScript.Shell" )
  key = LCase(wsh.ExpandEnvironmentStrings("%COMPUTERNAME%"))

  Newstr = ""
  LenStr = Len(Str)
  LenKey = Len(Key)

  if Len(Key)<Len(Str) Then
    For x = 1 to Ceiling(LenStr/LenKey)
      Key = Key & Key
    Next
  End If

  For x = 1 To LenStr
    Newstr = Newstr & chr(Int(asc(Mid(str,x,1))) + 20 - Int(asc(Mid(key,x,1))))
  Next

 Decrypt = Newstr

End Function

Function MyLPad (MyValue, MyPadChar, MyPaddedLength) 
  MyLpad = String(MyPaddedLength - Len(MyValue), MyPadChar) & MyValue 
End Function

Dim fs, f, wResponse
Dim wRegExp, wMeasureDefs, GenerateMeasureSection, wMeasureIdx
    
wResponse = UpdateStats()
   
If wResponse = "Fetch Failed" Then RaiseException "Fetch", "ERR", "Check Setup"
    
GenerateMeasureSection = False

