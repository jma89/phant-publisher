; Publish.au3/.exe
; Author: John Ambrose
; Created: 7/11/2014
; Purpose: Encrypt, chunk, and upload final
;		   program versions to SparkFun's
;		   Phant service so remote installs
;		   can properly update via the wide
;		   interwebnetz.
#cs
	[FileVersion]
#ce
#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=C:\Program Files (x86)\AutoIt3\Aut2Exe\Icons\AutoIt_Main_v10_48x48_RGB-A.ico
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Fileversion=0.0.0.22
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/so
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <Constants.au3>
#include <Array.au3>
#include <Date.au3>
#include <Math.au3>
#include <WinAPI.au3>
#include "_Base64.au3"
#include "WinHTTP.au3"
#include "aes.au3"
Global $version = _GetVersion()
Global $paramsString
Global $debug = False
Global $iniPath = "publish.ini"
Global $skipEncrypt = False
Global $skipEncode = False
Global $skipChunk = False
Global $skipClear = False
Global $clearOnly = False
Global $skipUpload = False
Global $verifyOnly = False
Global $skipVerify = False
Global $skipDirectory = False
Global $chunkSize = False
Global $storageType = False
Global $uploadLocation = False
Global $directoryStorage = False
Global $directoryLocation = False
Global $directoryPublic = False
Global $directoryPrivate = False
Global $cin
Global $cinString
Global $projectsArray = [0]
Global Enum $_prjName, $_prjFile, $_prjEncKey, $_prjStorage, $_prjLocation, $_prjPublic, $_prjPrivate, $_prjChunkSize, $_prjEncryptSkip, $_prjEncodeSkip, $_prjChunkSkip, $_prjClearSkip, $_prjUploadSkip, $_prjVerifySkip, $_prjDirectorySkip, $_prjKeyCount
Global $projectsToPublish = [0]

; Process command-line switches
If $cmdLine[0] > 0 Then
	For $i = 1 To $cmdLine[0]
		Switch StringLower($cmdLine[$i])
			Case "/debug"
				$debug = True
			Case "/inipath"
				If ($cmdLine[0] >= $i + 1) And ($cmdLine[$i + 1] = StringReplace($cmdLine[$i + 1], "/", "")) Then
					If FileExists($cmdLine[$i + 1]) And FileGetSize($cmdLine[$i + 1]) > 0 Then
						$iniPath = $cmdLine[$i + 1]
					Else
						ConsoleWriteError("Invalid file passed with /inipath:" & @CRLF & @TAB & $cmdLine[$i + 1] & @CRLF & @CRLF & "Continue using the default path:" & @CRLF & @TAB & $iniPath & @CRLF & @CRLF & @CRLF)

						$cinString = _ConsoleInput("y/n?")
						If StringLower($cinString) <> "y" Or StringLower($cinString) <> "yes" Then
							Exit 1
						EndIf
					EndIf
					$paramsString &= " " & $cmdLine[$i]
					$i = $i + 1
				EndIf
			Case "/noencrypt"
				$skipEncrypt = True
			Case "/noencode"
				$skipEncode = True
			Case "/nochunk"
				$skipChunk = True
			Case "/noclear"
				$skipClear = True
			Case "/clearonly"
				$clearOnly = True
			Case "/noupload"
				$skipUpload = True
			Case "/noverify"
				$skipVerify = True
			Case "/verifyonly"
				$verifyOnly = True
			Case "/nodirectory"
				$skipDirectory = True
			Case "/directoryonly"
				$skipEncrypt = True
				$skipEncode = True
				$skipChunk = True
				$skipClear = True
				$skipUpload = True
				$skipVerify = True
			Case "/chunksize"
				If ($cmdLine[0] >= $i + 1) And ($cmdLine[$i + 1] = StringReplace($cmdLine[$i + 1], "/", "")) Then
					$chunkUnit = StringRight($cmdLine[$i + 1], 1)
					Switch StringLower($chunkUnit)
						Case "b"
							$chunkMultiplier = 1
						Case "k"
							$chunkMultiplier = 1024
						Case "m"
							$chunkMultiplier = 1024 * 1024
						Case "g"
							$chunkMultiplier = 1024 * 1024 * 1024
						Case Else
							$chunkMultiplier = False
							ConsoleWriteError("Switch '/chunksize' passed but missing (b|k|m|g). Ignoring value." & @CRLF)
					EndSwitch
					$chunkSize = $chunkMultiplier ? (Number($cmdLine[$i + 1]) * $chunkMultiplier) : False
					$paramsString &= " " & $cmdLine[$i]
					$i = $i + 1
				Else
					ConsoleWriteError("Switch '/chunksize' passed but missing parameter. Will use settings from INI." & @CRLF)
				EndIf
			Case "/storage"
				If ($cmdLine[0] >= $i + 1) And ($cmdLine[$i + 1] = StringReplace($cmdLine[$i + 1], "/", "")) Then
					$storageType = $cmdLine[$i + 1]
					$paramsString &= " " & $cmdLine[$i]
					$i = $i + 1
				Else
					ConsoleWriteError("Switch '/storage' passed but missing parameter. Will use settings from INI." & @CRLF)
				EndIf
			Case "/location"
				If ($cmdLine[0] >= $i + 1) And ($cmdLine[$i + 1] = StringReplace($cmdLine[$i + 1], "/", "")) Then
					$uploadLocation = $cmdLine[$i + 1]
					$paramsString &= " " & $cmdLine[$i]
					$i = $i + 1
				Else
					ConsoleWriteError("Switch '/location' passed but missing parameter. Will use settings from INI." & @CRLF)
				EndIf
			Case "/?"
				ConsoleWrite(@ScriptName & " installs and configures Creo with eDrawings integration." & @CRLF _
						 & @CRLF _
						 & "/debug" & @CRLF _
						 & @TAB & "Enables debug mode" & @CRLF _
						 & @CRLF _
						 & "/iniPath x:\path\to.ini" & @CRLF _
						 & @TAB & "Use specified INI file instead of built-in default" & @CRLF _
						 & @CRLF _
						 & "/noEncrypt" & @CRLF _
						 & @TAB & "Skips encrypting the file before upload" & @CRLF _
						 & @CRLF _
						 & "/noEncode" & @CRLF _
						 & @TAB & "Skips encoding the file before upload" & @CRLF _
						 & @CRLF _
						 & "/noChunk" & @CRLF _
						 & @TAB & "Skips chunking the file before upload" & @CRLF _
						 & @CRLF _
						 & "/noClear" & @CRLF _
						 & @TAB & "Skips clearing the destination before upload" & @CRLF _
						 & @CRLF _
						 & "/noUpload" & @CRLF _
						 & @TAB & "Skips uploading the file" & @CRLF _
						 & @TAB & "(Leaves encrypted, chunked, and encoded files for examination)" & @CRLF _
						 & @CRLF _
						 & "/noVerify" & @CRLF _
						 & @TAB & "Skips verifying the uploaded file" & @CRLF _
						 & @CRLF _
						 & "/storage storagetype" & @CRLF _
						 & @TAB & "Use storage as defined by 'storagetype'" & @CRLF _
						 & @CRLF _
						 & "/location uploaddestination" & @CRLF _
						 & @TAB & "Use destination as defined by 'uploaddestination'" & @CRLF _
						 & @CRLF _
						 & "/chunkSize size(b|k|m|g)" & @CRLF _
						 & @TAB & "Chunk file as defined by size" & @CRLF _
						 & @CRLF _
						 & "/clearOnly" & @CRLF _
						 & @TAB & "Clears the current data at destination and does nothing else" & @CRLF _
						 & @CRLF _
						 & "/verifyOnly" & @CRLF _
						 & @TAB & "Verifies the current data at destination and does nothing else" & @CRLF _
						 & @CRLF _
						 & "/noDirectory" & @CRLF _
						 & @TAB & "Skips updating the directory with new version information" & @CRLF _
						 & @CRLF _
						 & "/directoryOnly" & @CRLF _
						 & @TAB & "Updates the directory listing and does nothing else" & @CRLF _
						 & @CRLF _
						 & "/?" & @CRLF _
						 & @TAB & "This usage dialog." & @CRLF _
						 & @CRLF _
						 & "Parameters are not case sensitive. Default settings located in " & $iniPath & ". Version: " & $version & @CRLF)
				Exit
			Case Else
				; This is the project to publish. Stash it into an arrayzors.
				ReDim $projectsToPublish[UBound($projectsToPublish) + 1]
				$projectsToPublish[UBound($projectsToPublish) - 1] = $cmdLine[$i]
		EndSwitch
		$paramsString &= " " & $cmdLine[$i]
	Next
EndIf

; Parse the INI file
If FileExists($iniPath) Then
	$iniSections = IniReadSectionNames($iniPath)
	If IsArray($iniSections) Then
		For $i = 1 To $iniSections[0]
			Switch StringLower($iniSections[$i])
				Case "projects"
					$iniSection = IniReadSection($iniPath, $iniSections[$i])
					If IsArray($iniSection) Then
						For $j = 1 To $iniSection[0][0]
							addProject($iniSection[$j][0], $iniSection[$j][1])
						Next
					EndIf
				Case "settings"
					$iniSection = IniReadSection($iniPath, $iniSections[$i])
					If IsArray($iniSection) Then
						For $j = 1 To $iniSection[0][0]
							Switch StringLower($iniSection[$j][0])
								Case "directoryStorage"
									$directoryStorage = $iniSection[$j][1]
								Case "directoryLocation"
									$directoryLocation = $iniSection[$j][1]
								Case "directoryPublic"
									$directoryPublic = $iniSection[$j][1]
								Case "directoryPrivate"
									$directoryPrivate = $iniSection[$j][1]
							EndSwitch
						Next
					EndIf
					#cs
						Case "multifieldsettings"
						$iniSection = IniReadSection($iniPath, $iniSections[$i])
						If IsArray($iniSection) Then
						For $j = 1 To $iniSection[0][0]
						$newDim = UBound($licenseOptions) + 1
						ReDim $licenseOptions[$newDim][3]
						$licenseOptions[$newDim - 1][0] = $iniSection[$j][0]
						$licenseOptionsArray = StringSplit($iniSection[$j][1], "|")
						If $licenseOptionsArray[0] > 1 Then
						$licenseOptions[$newDim - 1][1] = $licenseOptionsArray[1]
						$licenseOptions[$newDim - 1][2] = $licenseOptionsArray[2]
						EndIf
						Next
						EndIf
					#ce
			EndSwitch
		Next
	Else
		ConsoleWriteError("Invalid config file:" & @CRLF & @TAB & $iniPath & @CRLF)
		Exit 1
	EndIf
Else
	ConsoleWriteError("Cannot find config file:" & @CRLF & @TAB & $iniPath & @CRLF)
	Exit 1
EndIf

; Validate/sanitize all our inputs
validateProject($projectsToPublish)
If UBound($projectsToPublish) < 1 Then
	ConsoleWriteError("No valid projects selected for processing." & @CRLF)
	Exit 1
EndIf

_AesInit()

; Run through each requested project and do that process
For $i = 0 To UBound($projectsToPublish) - 1
	For $j = 0 To UBound($projectsArray) - 1
		If StringLower($projectsToPublish[$i]) = StringLower($projectsArray[$j][$_prjName]) Then
			ConsoleWrite("Processing '" & $projectsArray[$j][$_prjName] & "'..." & @CRLF)
			; Prep up our variables
			Local $thisPrjFile = $projectsArray[$j][$_prjFile]
			Local $thisPrjFilename = StringRight($thisPrjFile, StringLen($thisPrjFile) - StringInStr($thisPrjFile, "\", 0, -1))
			Local $thisPrjFileVersion = FileGetVersion($thisPrjFile)
			Local $thisPrjEncKey = $projectsArray[$j][$_prjEncKey]
			Local $thisPrjStorage = $projectsArray[$j][$_prjStorage]
			Local $thisPrjLocation = $projectsArray[$j][$_prjLocation]
			Local $thisPrjPublic = $projectsArray[$j][$_prjPublic]
			Local $thisPrjPrivate = $projectsArray[$j][$_prjPrivate]
			Local $thisPrjChunkSize = $projectsArray[$j][$_prjChunkSize]
			$thisPrjStagingPath = @TempDir & "\stagedPublish-" & $projectsArray[$j][$_prjName]
			While FileExists($thisPrjStagingPath)
				$thisPrjStagingPath &= Chr(Random(65, 122, 1))
			WEnd
			If Not DirCreate($thisPrjStagingPath) Then
				ConsoleWriteError("Unable to create staging folder at '" & $thisPrjStagingPath & "'. Using '" & @ScriptDir & "' instead.")
				$thisPrjStagingPath = @ScriptDir
			EndIf
			If $debug Then
				ConsoleWrite(@TAB & "DEBUG: Staging path is '" & $thisPrjStagingPath & "'" & @CRLF)
			EndIf

			; Encrypt
			If Not $skipEncrypt And Not $clearOnly And Not $verifyOnly And Not $projectsArray[$j][$_prjEncryptSkip] Then
				ConsoleWrite(" Encrypting with AES... ")
				Local $opTimer = TimerInit()
				$outputFile = $thisPrjStagingPath & "\" & $thisPrjFilename & ".enc"
				_AesEncryptFile($thisPrjEncKey, $thisPrjFile, $outputFile, "CBC")
				Local $opCost = TimerDiff($opTimer)
				ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
			Else
				ConsoleWrite(" Skipped encrypting." & @CRLF)
				$outputFile = $thisPrjFile
			EndIf

			; Encode
			If Not $skipEncode And Not $clearOnly And Not $verifyOnly And Not $projectsArray[$j][$_prjEncodeSkip] Then
				ConsoleWrite(" Encoding as Base64... ")
				Local $opTimer = TimerInit()
				$fileToEncode = FileOpen($outputFile, $FO_BINARY)
				$fileString = _Base64Encode(FileRead($fileToEncode), False)
				FileClose($fileToEncode)
				Local $opCost = TimerDiff($opTimer)
				ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
			Else
				ConsoleWrite(" Skipped encoding." & @CRLF)
				$fileToEncode = FileOpen($outputFile, $FO_BINARY)
				$fileString = FileRead($fileToEncode)
				FileClose($fileToEncode)
			EndIf

			; Chunk
			If Not $skipChunk And Not $clearOnly And Not $verifyOnly And Not $projectsArray[$j][$_prjChunkSkip] And $thisPrjChunkSize Then
				ConsoleWrite(" Chunking to " & $thisPrjChunkSize & " byte chunks... ")
				Local $opTimer = TimerInit()
				If IsString($fileString) Then
					$inputLength = StringLen($fileString)
				ElseIf IsBinary($fileString) Then
					$inputLength = BinaryLen($fileString)
				Else
					ConsoleWriteError("Invalid stream for chunking. Terminating." & @CRLF)
					Exit 1
				EndIf
				$minLastChunkSize = $inputLength > 640 ? 640 : 0
				$numChunks = Ceiling(($inputLength - $minLastChunkSize) / $thisPrjChunkSize) + 1
				If $debug Then
					ConsoleWrite(@CRLF & @TAB & "DEBUG: Using " & $numChunks & " chunks." & @CRLF)
				EndIf
				Dim $chunkedFile[$numChunks]
				$pos = 1
				For $k = 0 To $numChunks - 2
					If IsString($fileString) Then
						$chunkedFile[$k] = StringMid($fileString, $pos, _Min($thisPrjChunkSize, $inputLength - $pos - $minLastChunkSize))
					ElseIf IsBinary($fileString) Then
						$chunkedFile[$k] = BinaryMid($fileString, $pos, _Min($thisPrjChunkSize, $inputLength - $pos - $minLastChunkSize))
					EndIf
					$pos = $pos + _Min($thisPrjChunkSize, $inputLength - $pos - $minLastChunkSize)
				Next
				If IsString($fileString) Then
					$chunkedFile[$numChunks - 1] = StringMid($fileString, $pos)
				ElseIf IsBinary($fileString) Then
					$chunkedFile[$numChunks - 1] = BinaryMid($fileString, $pos)
				EndIf
				Local $opCost = TimerDiff($opTimer)
				ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
			Else
				ConsoleWrite(" Skipped chunking." & @CRLF)
				$numChunks = 1
				Dim $chunkedFile[$numChunks]
				$chunkedFile[0] = $fileString
			EndIf

			; Clear
			If Not $skipClear And Not $verifyOnly And Not $projectsArray[$j][$_prjClearSkip] Then
				ConsoleWrite(" Clearing previous uploads from '" & $thisPrjLocation & "'... ")
				Local $opTimer = TimerInit()
				$remoteResult = remoteOperation("clear", $thisPrjLocation, $thisPrjStorage, False, False, False, False, $thisPrjPublic, $thisPrjPrivate)
				If $debug Then
					ConsoleWrite(@CRLF & @TAB & "DEBUG: Remote operation result: '" & StringStripWS($remoteResult, 3) & "'" & @CRLF)
				EndIf
				Local $opCost = TimerDiff($opTimer)
				ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
			Else
				ConsoleWrite(" Skipped clearing." & @CRLF)
			EndIf

			; Upload
			If Not $skipUpload And Not $clearOnly And Not $verifyOnly And Not $projectsArray[$j][$_prjUploadSkip] Then
				ConsoleWrite(" Uploading " & ($numChunks > 1 ? ("files") : ("file")) & " to '" & $thisPrjLocation & "'... " & @CRLF)
				Local $opTimer = TimerInit()
				For $k = 0 To $numChunks - 1
					;chunknum, data, totalchunks, version
					$uploaded = False
					Do
						ConsoleWrite("  Uploading " & $k + 1 & " of " & $numChunks & "..." & @CRLF)
						$remoteResult = remoteOperation("put", $thisPrjLocation, $thisPrjStorage, $k, $chunkedFile[$k], $numChunks, $thisPrjFileVersion, $thisPrjPublic, $thisPrjPrivate)
						If StringLeft($remoteResult, 1) <> "1" Then
							ConsoleWriteError("   Error uploading chunk: '" & StringStripWS($remoteResult, 3) & "'" & @CRLF)
							$cinString = _ConsoleInput("    Retry or abort (r/a)?")
							If StringLower($cinString) = "a" Or StringLower($cinString) = "abort" Then
								ConsoleWriteError("   Aborting upload." & @CRLF)
								ExitLoop 2
							ElseIf StringLower($cinString) = "r" Or StringLower($cinString) = "retry" Then
								ContinueLoop
							EndIf
						Else
							$uploaded = True
						EndIf
						If $debug Then
							ConsoleWrite(@TAB & "DEBUG: Remote operation result: '" & StringStripWS($remoteResult, 3) & "'" & @CRLF)
						EndIf
					Until $uploaded
				Next
				Local $opCost = TimerDiff($opTimer)
				ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
			Else
				ConsoleWrite(" Skipped uploading." & @CRLF)
			EndIf

			; Verify
			If Not $skipVerify And Not $clearOnly And Not $projectsArray[$j][$_prjVerifySkip] Then
				ConsoleWrite(" Verifying upload at '" & $thisPrjLocation & "'... ")
				Local $opTimer = TimerInit()
				$remoteResult = remoteOperation("get", $thisPrjLocation, $thisPrjStorage, False, False, False, False, $thisPrjPublic)
				If $debug Then
					ConsoleWrite(@CRLF & @TAB & "DEBUG: Remote operation result: " & StringLen($remoteResult) & " bytes" & @CRLF)
					ClipPut($remoteResult)
				EndIf

				; Turn the result into an array
				$verifyArray1 = StringSplit($remoteResult, @CRLF, 2)
				Dim $verifyArray[UBound($verifyArray1)][5]
				For $k = 0 To UBound($verifyArray1) - 1
					$verifyArray2 = StringSplit($verifyArray1[$k], ",", 2)
					For $l = 0 To UBound($verifyArray2) - 1
						$verifyArray[$k][$l] = $verifyArray2[$l]
					Next
				Next

				; Figure out column numbers
				$vfyClmChunkNum = -1
				$vfyClmData = -1
				$vfyClmTotalChunks = -1
				$vfyClmVersion = -1
				For $k = 0 To UBound($verifyArray, 2) - 1
					Switch StringLower($verifyArray[0][$k])
						Case "chunknum"
							$vfyClmChunkNum = $k
						Case "data"
							$vfyClmData = $k
						Case "totalchunks"
							$vfyClmTotalChunks = $k
						Case "version"
							$vfyClmVersion = $k
					EndSwitch
				Next

				If $vfyClmChunkNum < 0 Or $vfyClmData < 0 Or $vfyClmTotalChunks < 0 Or $vfyClmVersion < 0 Then
					ConsoleWriteError("Missing column data at destination. Aborting verificaion." & @CRLF)
					$verifyFile = ""
					$verifyFileDecrypted = ""
				Else
					; Loop through what we have
					$fullString = ""
					$verifyVersion = $verifyArray[1][$vfyClmVersion]
					$limit = _Max(UBound($verifyArray) - 1, Number($verifyArray[1][$vfyClmTotalChunks]))
					If $debug Then
						ConsoleWrite(@TAB & "DEBUG: Reconstituting string based on " & $limit & " rows for version " & $verifyVersion & "." & @CRLF)
					EndIf
					For $k = 0 To $limit
						For $l = 0 To UBound($verifyArray) - 1
							If $verifyArray[$l][$vfyClmVersion] = $verifyVersion Then
								If $verifyArray[$l][$vfyClmChunkNum] = $k Then
									$fullString &= StringStripWS($verifyArray[$l][$vfyClmData], 8)
								EndIf
							EndIf
						Next
					Next
					If $debug Then
						ConsoleWrite(@TAB & "DEBUG: Reconstiuted string: " & StringLen($fullString) & " bytes" & @CRLF)
					EndIf

					; Decode that string
					If Not $skipEncode Then
						$verifyDecoded = _Base64Decode($fullString)
					Else
						$verifyDecoded = $fullString
					EndIf
					$verifyFile = $thisPrjStagingPath & "\" & $thisPrjFilename & ".encver"
					$verifyFileDecrypted = $thisPrjStagingPath & "\" & $thisPrjFilename & ".dec"
					$fileDecoded = FileOpen($verifyFile, BitOR($FO_BINARY, $FO_OVERWRITE))
					FileWrite($fileDecoded, $verifyDecoded)
					FileClose($fileDecoded)

					; Decrypt into a file
					If Not $skipEncrypt Then
						_AesDecryptFile($thisPrjEncKey, $verifyFile, $verifyFileDecrypted, "CBC")
					EndIf

					; Check if it worked
					If Not $verifyOnly Then
						Local $Ret = RunWait('cmd /c "fc /b "' & $thisPrjFile & '" "' & $verifyFileDecrypted & '""')

						If $Ret = 0 Then
							ConsoleWrite("  Verification successful." & @CRLF)
						Else
							ConsoleWriteError("Verification failed (" & $verifyFileDecrypted & "). Press <ENTER> to continue." & @CRLF)
							_ConsoleInput()
						EndIf
					Else
						ConsoleWrite("  Please verify file at '" & $verifyFileDecrypted & "' and press <ENTER> to continue." & @CRLF)
						_ConsoleInput()
					EndIf

					Local $opCost = TimerDiff($opTimer)
					ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
				EndIf
			Else
				ConsoleWrite(" Skipped verifying." & @CRLF)
				$verifyFile = ""
				$verifyFileDecrypted = ""
			EndIf

			; Update directory
			If Not $skipDirectory And Not $clearOnly And Not $verifyOnly And Not $projectsArray[$j][$_prjDirectorySkip] Then
				ConsoleWrite(" Updating directory at '" & $directoryLocation & "'... ")
				Local $opTimer = TimerInit()
				$remoteResult = remoteOperation("get", $directoryLocation, $directoryStorage, False, False, False, False, $directoryPublic)
				If $debug Then
					ConsoleWrite(@CRLF & @TAB & "DEBUG: Remote operation result: " & StringLen($remoteResult) & " bytes" & @CRLF)
					ClipPut($remoteResult)
				EndIf

				; Turn the result into an array
				$verifyArray1 = StringSplit($remoteResult, @CRLF, 2)
				Dim $verifyArray[UBound($verifyArray1)][4]
				For $k = 0 To UBound($verifyArray1) - 1
					$verifyArray2 = StringSplit($verifyArray1[$k], ",", 2)
					For $l = 0 To UBound($verifyArray2) - 1
						$verifyArray[$k][$l] = $verifyArray2[$l]
					Next
				Next

				; Figure out column numbers
				$dirClmProgram = -1
				$dirClmPublicKey = -1
				$dirClmVersion = -1
				For $k = 0 To UBound($verifyArray, 2) - 1
					Switch StringLower($verifyArray[0][$k])
						Case "program"
							$dirClmProgram = $k
						Case "phantpublickey"
							$dirClmPublicKey = $k
						Case "version"
							$dirClmVersion = $k
					EndSwitch
				Next

				If StringLower($verifyArray[0][0]) = "no data has been pushed to this stream" Then
					$dirClmProgram = 0
					$dirClmPublicKey = 1
					$dirClmVersion = 2
				EndIf

				If $dirClmProgram < 0 Or $dirClmPublicKey < 0 Or $dirClmVersion < 0 Then
					ConsoleWriteError("Missing column data at destination. Aborting directory update." & @CRLF)
					ConsoleWriteError("Returned string: " & $verifyArray[0][0] & @CRLF)
				Else
					; Update this program's row in the directory
					$updatedEntry = False
					For $k = 0 To UBound($verifyArray) - 1
						If $verifyArray[$k][$dirClmProgram] = $projectsArray[$j][$_prjName] Then
							$verifyArray[$k][$dirClmVersion] = $thisPrjPublic
							$verifyArray[$k][$dirClmVersion] = $thisPrjFileVersion
							$updatedEntry = True
						EndIf
					Next
					If Not $updatedEntry Then
						ReDim $verifyArray[UBound($verifyArray) + 1][4]
						$verifyArray[UBound($verifyArray) - 1][$dirClmPublicKey] = $thisPrjPublic
						$verifyArray[UBound($verifyArray) - 1][$dirClmProgram] = $projectsArray[$j][$_prjName]
						$verifyArray[UBound($verifyArray) - 1][$dirClmVersion] = $thisPrjFileVersion
					EndIf

					; Clear the existing directory
					$remoteResult = remoteOperation("clear", $directoryLocation, $directoryStorage, False, False, False, False, $directoryPublic, $directoryPrivate)
					If $debug Then
						ConsoleWrite(@CRLF & @TAB & "DEBUG: Remote operation result: '" & StringStripWS($remoteResult, 3) & "'" & @CRLF)
					EndIf

					; Upload the new directory
					For $k = 1 To UBound($verifyArray) - 1
						$uploaded = False
						Do
							ConsoleWrite("  Uploading directory entry " & $k & " of " & UBound($verifyArray) - 1 & "..." & @CRLF)
							If $verifyArray[$k][$dirClmPublicKey] <> "" And $verifyArray[$k][$dirClmProgram] <> "" And $verifyArray[$k][$dirClmVersion] <> "" Then
								$remoteResult = remoteOperation("put", $directoryLocation, $directoryStorage, $verifyArray[$k][$dirClmPublicKey], $verifyArray[$k][$dirClmProgram], $verifyArray[$k][$dirClmVersion], False, $directoryPublic, $directoryPrivate)
								If StringLeft($remoteResult, 1) <> "1" Then
									ConsoleWriteError("   Error uploading directory: '" & StringStripWS($remoteResult, 3) & "'" & @CRLF)
									$cinString = _ConsoleInput("    Retry or abort (r/a)?")
									If StringLower($cinString) = "a" Or StringLower($cinString) = "abort" Then
										ConsoleWriteError("   Aborting upload." & @CRLF)
										ExitLoop 2
									ElseIf StringLower($cinString) = "r" Or StringLower($cinString) = "retry" Then
										ContinueLoop
									EndIf
								Else
									$uploaded = True
								EndIf
								If $debug Then
									ConsoleWrite(@TAB & "DEBUG: Remote operation result: '" & StringStripWS($remoteResult, 3) & "'" & @CRLF)
								EndIf
							Else
								$uploaded = True
								If $debug Then
									ConsoleWrite(@TAB & "DEBUG: Skipped due to empty line" & @CRLF)
								EndIf
							EndIf
						Until $uploaded
					Next

					Local $opCost = TimerDiff($opTimer)
					ConsoleWrite("Done (" & $opCost & " ms)" & @CRLF)
				EndIf
			Else
				ConsoleWrite(" Skipped updating directory." & @CRLF)
			EndIf

			If Not $skipEncrypt And Not $clearOnly And Not $verifyOnly And Not $projectsArray[$j][$_prjEncryptSkip] Then
				FileDelete($outputFile)
			EndIf
			If Not $skipVerify And Not $clearOnly And Not $projectsArray[$j][$_prjVerifySkip] Then
				FileDelete($verifyFile)
				FileDelete($verifyFileDecrypted)
			EndIf
			DirRemove($thisPrjStagingPath, 1)
		EndIf
	Next
Next

Func addProject($prjName, $prjStatus)
	If StringLower($prjStatus) = "enable" Then
		If $debug Then
			ConsoleWrite(@TAB & "DEBUG: Found project '" & $prjName & "'" & @CRLF)
		EndIf
		Local $prjArray = loadINISection($prjName)
		If IsArray($prjArray) Then
			$newDim = UBound($projectsArray)
			ReDim $projectsArray[$newDim + 1][$_prjKeyCount]
			$projectsArray[$newDim - 1][$_prjName] = $prjName
			For $i = 0 To UBound($prjArray) - 1
				Switch StringLower($prjArray[$i][0])
					Case "file"
						$projectsArray[$newDim - 1][$_prjFile] = StringReplace($prjArray[$i][1], '"', '')
					Case "enckey"
						$projectsArray[$newDim - 1][$_prjEncKey] = $prjArray[$i][1]
					Case "storage"
						$projectsArray[$newDim - 1][$_prjStorage] = $prjArray[$i][1]
					Case "location"
						$projectsArray[$newDim - 1][$_prjLocation] = $prjArray[$i][1]
					Case "public"
						$projectsArray[$newDim - 1][$_prjPublic] = $prjArray[$i][1]
					Case "private"
						$projectsArray[$newDim - 1][$_prjPrivate] = $prjArray[$i][1]
					Case "chunksize"
						$chunkUnit = StringRight($prjArray[$i][1], 1)
						Switch StringLower($chunkUnit)
							Case "b"
								$chunkMultiplier = 1
							Case "k"
								$chunkMultiplier = 1024
							Case "m"
								$chunkMultiplier = 1024 * 1024
							Case "g"
								$chunkMultiplier = 1024 * 1024 * 1024
							Case Else
								$chunkMultiplier = False
								If $debug Then
									ConsoleWrite(@TAB & "DEBUG: 'chunksize' key invalid: " & $prjArray[$i][1] & @CRLF)
								EndIf
						EndSwitch
						$projectsArray[$newDim - 1][$_prjChunkSize] = $chunkMultiplier ? (Number($prjArray[$i][1]) * $chunkMultiplier) : False
					Case "encrypt"
						$projectsArray[$newDim - 1][$_prjEncryptSkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case "encode"
						$projectsArray[$newDim - 1][$_prjEncodeSkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case "chunk"
						$projectsArray[$newDim - 1][$_prjChunkSkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case "clear"
						$projectsArray[$newDim - 1][$_prjClearSkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case "upload"
						$projectsArray[$newDim - 1][$_prjUploadSkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case "verify"
						$projectsArray[$newDim - 1][$_prjVerifySkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case "directory"
						$projectsArray[$newDim - 1][$_prjDirectorySkip] = StringLower($prjArray[$i][1]) = "skip" ? True : False
					Case ""
						; Avoid unnecessary DEBUG lines
					Case Else
						If $debug Then
							ConsoleWrite(@TAB & "DEBUG: Unknown key found: " & $prjArray[$i][0] & @CRLF)
						EndIf
				EndSwitch
			Next
		Else
			If $debug Then
				ConsoleWrite(@TAB & "DEBUG: Project '" & $prjName & "' listed but no settings found." & @CRLF)
			EndIf
		EndIf
	Else
		If $debug Then
			ConsoleWrite(@TAB & "DEBUG: Project '" & $prjName & "' not enabled: Has status '" & $prjStatus & "'" & @CRLF)
		EndIf
	EndIf
EndFunc   ;==>addProject

Func loadINISection($sectionToLoad)
	Local $iniSections, $iniSection
	Local $resultArray = []
	$validResult = False
	; Parse the INI file
	If FileExists($iniPath) Then
		$iniSections = IniReadSectionNames($iniPath)
		If IsArray($iniSections) Then
			For $i = 1 To $iniSections[0]
				Switch StringLower($iniSections[$i])
					Case StringLower($sectionToLoad)
						$iniSection = IniReadSection($iniPath, $iniSections[$i])
						If IsArray($iniSection) Then
							For $j = 1 To $iniSection[0][0]
								ReDim $resultArray[UBound($resultArray) + 1][2]
								$resultArray[UBound($resultArray) - 1][0] = $iniSection[$j][0]
								$resultArray[UBound($resultArray) - 1][1] = $iniSection[$j][1]
							Next
							$validResult = True
						EndIf
				EndSwitch
			Next
			If Not $validResult Then
				Return False
			EndIf
		Else
			Return False
		EndIf
	Else
		Return False
	EndIf
	Return $resultArray
EndFunc   ;==>loadINISection

Func validateProject(ByRef $prjArray)
	; Everybody should be an array
	If Not IsArray($prjArray) Then
		Return False
	EndIf

	; Make sure every entry is defined in the array
	For $i = 0 To UBound($prjArray) - 1
		$validProject = False
		For $j = 0 To UBound($projectsArray) - 1
			If StringLower($prjArray[$i]) = StringLower($projectsArray[$j][$_prjName]) Then
				$validProject = True
			EndIf
		Next
		If Not $validProject Then
			$prjArray[$i] = ""
		EndIf
	Next

	; Clear out the entries we've discarded
	$loTotalRows = UBound($prjArray, 1)
	$k = 0
	$validEntry = False
	For $i = 0 To $loTotalRows - 1
		$j = 0
		While $prjArray[$i] = "" And $i + $j < $loTotalRows - 1
			$j = $j + 1
			$prjArray[$i] = $prjArray[$i + $j]
			$prjArray[$i + $j] = ""
		WEnd
		If $prjArray[$i] = "" And $i + $j >= $loTotalRows - 1 Then
			$j = $j + 1
		EndIf
		If Not $prjArray[$i] = "" Then
			$validEntry = True
		EndIf
		$k = $j < $k ? $k : $j
	Next

	; Chop the blank rows off the end
	If Not $validEntry Then
		ReDim $prjArray[0]
	Else
		ReDim $prjArray[$loTotalRows - $k]
	EndIf

	Return True
EndFunc   ;==>validateProject

Func remoteOperation($operation, $location, $type, $data1 = False, $data2 = False, $data3 = False, $data4 = False, $public = False, $private = False)
	Switch StringLower($type)
		Case "phant"
			Switch StringLower($operation)
				Case "clear"
					$sDomainFront = StringRight($location, StringLen($location) - StringInStr($location, "://") - 2)
					$sDomain = StringLeft($sDomainFront, StringInStr($sDomainFront, "/") - 1)
					$sPage = "input/" & $public

					$sHeaders = "Content-Type: application/xml; charset=utf-8" & @CRLF
					$sHeaders &= "Phant-Private-Key: " & $private & @CRLF

					$hOpen = _WinHttpOpen()
					$hConnect = _WinHttpConnect($hOpen, $sDomain)
					$hRequest = _WinHttpOpenRequest($hConnect, "DELETE", $sPage)
					_WinHttpSendRequest($hRequest, $sHeaders)
					_WinHttpReceiveResponse($hRequest)

					$sReturned = ""
					If _WinHttpQueryDataAvailable($hRequest) Then ; if there is data
						Do
							$sReturned &= _WinHttpReadData($hRequest)
						Until @error
					EndIf

					_WinHttpCloseHandle($hRequest)
					_WinHttpCloseHandle($hConnect)
					_WinHttpCloseHandle($hOpen)

					Return $sReturned
				Case "put"
					$sDomainFront = StringRight($location, StringLen($location) - StringInStr($location, "://") - 2)
					$sDomain = StringLeft($sDomainFront, StringInStr($sDomainFront, "/") - 1)
					$sPage = "input/" & $public

					$sHeaders = "Content-Type: application/x-www-form-urlencoded" & @CRLF
					$sHeaders &= "Phant-Private-Key: " & $private & @CRLF
					;chunknum, data, totalchunks, version
					If $data4 Then
						$sData = "chunknum=" & $data1
						$sData &= "&data=" & $data2
						$sData &= "&totalchunks=" & $data3
						$sData &= "&version=" & $data4
					Else
						$sData = "phantpublickey=" & $data1
						$sData &= "&program=" & $data2
						$sData &= "&version=" & $data3
					EndIf

					$hOpen = _WinHttpOpen()
					$hConnect = _WinHttpConnect($hOpen, $sDomain)
					$hRequest = _WinHttpOpenRequest($hConnect, "POST", $sPage)
					_WinHttpSendRequest($hRequest, $sHeaders, _URLEncode($sData))
					_WinHttpReceiveResponse($hRequest)

					$sReturned = ""
					If _WinHttpQueryDataAvailable($hRequest) Then ; if there is data
						Do
							$sReturned &= _WinHttpReadData($hRequest)
						Until @error
					EndIf

					_WinHttpCloseHandle($hRequest)
					_WinHttpCloseHandle($hConnect)
					_WinHttpCloseHandle($hOpen)

					Return $sReturned
				Case "get"
					$sDomainFront = StringRight($location, StringLen($location) - StringInStr($location, "://") - 2)
					$sDomain = StringLeft($sDomainFront, StringInStr($sDomainFront, "/") - 1)
					$sPage = "output/" & $public & ".csv"

					$sHeaders = "Content-Type: application/x-www-form-urlencoded" & @CRLF

					$hOpen = _WinHttpOpen()
					$hConnect = _WinHttpConnect($hOpen, $sDomain)
					$hRequest = _WinHttpOpenRequest($hConnect, "GET", $sPage)
					_WinHttpSendRequest($hRequest, $sHeaders)
					_WinHttpReceiveResponse($hRequest)

					$sReturned = ""
					If _WinHttpQueryDataAvailable($hRequest) Then ; if there is data
						Do
							$sReturned &= _WinHttpReadData($hRequest)
						Until @error
					EndIf

					_WinHttpCloseHandle($hRequest)
					_WinHttpCloseHandle($hConnect)
					_WinHttpCloseHandle($hOpen)

					Return $sReturned
				Case Else
					; Unsupported
					ConsoleWriteError("Unsupported remote operation '" & $operation & "'." & @CRLF)
					Return False
			EndSwitch
		Case "file"
			Switch StringLower($operation)
				Case "clear"

				Case "put"
				Case "get"
				Case Else
					; Unsupported
					ConsoleWriteError("Unsupported remote operation '" & $operation & "'." & @CRLF)
					Return False
			EndSwitch
		Case Else
			; Unsupported
			ConsoleWriteError("Unsupported remote storage type '" & $type & "'. Terminating." & @CRLF)
			Exit 1
	EndSwitch
EndFunc   ;==>remoteOperation

Func _GetVersion()
	If @Compiled Then
		Return FileGetVersion(@AutoItExe)
	Else
		Return IniRead(@ScriptFullPath, "FileVersion", "#AutoIt3Wrapper_Res_Fileversion", "0.0.0.0") & " beta"
	EndIf
EndFunc   ;==>_GetVersion

Func PreIncr(ByRef $v)
	$v += 1
	Return $v
EndFunc   ;==>PreIncr

Func PostIncr(ByRef $v)
	Dim $x = $v
	$v += 1
	Return $x
EndFunc   ;==>PostIncr

Func _ConsoleInput($sPrompt = "")
	If Not @Compiled Then Return SetError(1, 0, 0) ; Not compiled

	ConsoleWrite($sPrompt)

	Local $tBuffer = DllStructCreate("char"), $nRead, $sRet = ""
	Local $hFile = _WinAPI_CreateFile("CON", 2, 2)

	While 1
		_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), 1, $nRead)
		If DllStructGetData($tBuffer, 1) = @CR Then ExitLoop
		If $nRead > 0 Then $sRet &= DllStructGetData($tBuffer, 1)
	WEnd

	_WinAPI_CloseHandle($hFile)
	Return $sRet
EndFunc   ;==>_ConsoleInput

;===============================================================================
; _URLEncode()
; Description:  : Encodes a string to be URL-friendly
; Parameter(s):  : $toEncode       - The String to Encode
;                  : $encodeType = 0 - Practical Encoding (Encode only what is necessary)
;                  :             = 1 - Encode everything
;                  :             = 2 - RFC 1738 Encoding - http://www.ietf.org/rfc/rfc1738.txt
; Return Value(s): : The URL encoded string
; Author(s):  : nfwu
; Note(s):   : -
;
;===============================================================================
Func _URLEncode($toEncode, $encodeType = 0)
	Local $strHex = "", $iDec
	Local $aryChar = StringSplit($toEncode, "")
	If $encodeType = 1 Then;;Encode EVERYTHING
		For $i = 1 To $aryChar[0]
			$strHex = $strHex & "%" & Hex(Asc($aryChar[$i]), 2)
		Next
		Return $strHex
	ElseIf $encodeType = 0 Then;;Practical Encoding
		For $i = 1 To $aryChar[0]
			$iDec = Asc($aryChar[$i])
			If $iDec <= 32 Or $iDec = 37 Then
				$strHex = $strHex & "%" & Hex($iDec, 2)
			Else
				$strHex = $strHex & $aryChar[$i]
			EndIf
		Next
		Return $strHex
	ElseIf $encodeType = 2 Then;;RFC 1738 Encoding
		For $i = 1 To $aryChar[0]
			If Not StringInStr("$-_.+!*'(),;/?:@=&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890", $aryChar[$i]) Then
				$strHex = $strHex & "%" & Hex(Asc($aryChar[$i]), 2)
			Else
				$strHex = $strHex & $aryChar[$i]
			EndIf
		Next
		Return $strHex
	EndIf
EndFunc   ;==>_URLEncode
;===============================================================================
; _URLDecode()
; Description:  : Tranlates a URL-friendly string to a normal string
; Parameter(s):  : $toDecode - The URL-friendly string to decode
; Return Value(s): : The URL decoded string
; Author(s):  : nfwu
; Note(s):   : -
;
;===============================================================================
Func _URLDecode($toDecode)
	Local $strChar = "", $iOne, $iTwo
	Local $aryHex = StringSplit($toDecode, "")
	For $i = 1 To $aryHex[0]
		If $aryHex[$i] = "%" Then
			$i = $i + 1
			$iOne = $aryHex[$i]
			$i = $i + 1
			$iTwo = $aryHex[$i]
			$strChar = $strChar & Chr(Dec($iOne & $iTwo))
		Else
			$strChar = $strChar & $aryHex[$i]
		EndIf
	Next
	Return StringReplace($strChar, "+", " ")
EndFunc   ;==>_URLDecode

