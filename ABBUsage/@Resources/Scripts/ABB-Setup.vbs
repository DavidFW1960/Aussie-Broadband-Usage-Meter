Option Explicit

Dim wInput, fs, f, shell, wAppDir, Encrypted, Key, wUserName, wPassword, wUserDetails
Const ApplicationFolder = "Rainmeter-ABB"

set shell = WScript.CreateObject( "WScript.Shell" )
wAppDir = (shell.ExpandEnvironmentStrings("%APPDATA%")) & "\"& ApplicationFolder
Set fs = CreateObject ("Scripting.FileSystemObject")

If NOT fs.FolderExists(wAppDir) Then
 fs.CreateFolder(wAppDir)
End If

wUserName = ""

If fs.FileExists(wAppDir & "\ABB-Configuration.txt") Then
  Set f = fs.OpenTextFile(wAppDir & "\ABB-Configuration.txt")
  wUserDetails = f.readall
  f.close
  
  wUserName = parse_item (wUserDetails, "User Name =", "<<<")
  
End If

wUserName = InputBox("Please enter your ABB username" & vbCRLF & _
                     "(the same as your ABB user)", "ABB Usage Setup", wUserName)

If wUserName = "" Then wScript.Quit
                     
wPassword = InputBox("Please enter your ABB password" & vbCRLF & _
                     "(it is visible here but will be encrypted)", "ABB Usage Setup")
                    
If wPassword = "" Then wScript.Quit

key = LCase(shell.ExpandEnvironmentStrings("%COMPUTERNAME%"))
Encrypted =  encrypt(wPassword)

Set f = fs.CreateTextFile(wAppDir & "\ABB-Configuration.txt", True)
f.writeline "User Name = " & wUserName & " <<< Your username"
f.close

Set f = fs.CreateTextFile(wAppDir & "\ABB-EncrytpedPassword.txt", True)
f.write encrypted
f.close

Function encrypt(Str)
 
Dim Newstr, LenStr, LenKey, x

  Newstr = ""
  LenStr = Len(Str)
  LenKey = Len(Key)

  if Len(Key)<Len(Str) Then
    For x = 1 to Ceiling(LenStr/LenKey)
      Key = Key & Key
    Next
  End If

  For x = 1 To LenStr
    Newstr = Newstr & chr(Int(asc(Mid(str,x,1))) + Int(asc(Mid(key,x,1)))-20)
  Next

 encrypt = Newstr

End Function

Private Function parse_item (ByRef contents, start_tag, end_tag)

  Dim position, item
	
  position = InStr (1, contents, start_tag, vbTextCompare)
  
  If position > 0 Then
  ' Trim the html information.
    contents = mid (contents, position + len (start_tag))
    position = InStr (1, contents, end_tag, vbTextCompare)
		
    If position > 0 Then
      item = mid (contents, 1, position - 1)
    Else
      Item = ""
    End If
  Else
    item = ""
  End If

  parse_item = Trim(Item)

End Function

Private Function Ceiling(byval n)
	Dim iTmp, f
	n = cdbl(n)
	f = Floor(n)
	if f = n then
		Ceiling = n
		Exit Function
	End If
	Ceiling = cInt(f + 1)
End Function

Private Function Floor(byval n)
	Dim iTmp
	n = cdbl(n)
	iTmp = Round(n)
	if iTmp > n then iTmp = iTmp - 1
	Floor = cInt(iTmp)
End Function
