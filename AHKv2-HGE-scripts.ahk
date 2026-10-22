; ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** *****
; *	Misc applications command tweaks 
; *	Created by: Hugo Gaibor
; *	Date: 2026-Oct-21
; * License: GNU/GPL3+
; *
; * Latest version: https://github.com/hgaibor/AutoHotkey-HGE-Scripts
; * History:
; *		
; *		2026-10-20	 Refactored code for Autohotkey V2 from legacy 
; *                  https://github.com/hgaibor/AutoHotkey-HGE-Scripts (archived)
; *
; ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** *****

Persistent(true)

; Attempt to load INI file, if not successful, exit app
global IniSettingsFileName := SubStr(A_ScriptName, 1, InStr(A_ScriptName, ".", false, -1) - 1) . ".ini"
global IniSettingsFilePath := SubStr(A_ScriptFullPath, 1, InStr(A_ScriptFullPath, ".", false, -1) - 1) . ".ini"
global HotkeysFilePath := A_ScriptFullPath . "_hotkeys"

if !FileExist(IniSettingsFilePath)
{
	MsgBox(
		"Please make sure there is an file named " . IniSettingsFileName . " in the same folder as this .ahk file.`n`n"
		. "If file is not present get the example .ini file at:`n https://github.com/hgaibor/AutoHotkey-HGE-Scripts`n`n"
		. "Press CONTROL+C to copy this dialog text with the URL.`n`n"
		. "Script will exit now",
		"ERROR: Script .ini settings not found",
		16
	)
	ExitApp()
}

if !FileExist(HotkeysFilePath)
{
	MsgBox(
		"Please make sure there is an file named " . A_ScriptName . "_hotkeys in the same folder as this .ahk file.`n`n"
		. "If file is not present get the example .ini file at:`n https://github.com/hgaibor/AutoHotkey-HGE-Scripts`n`n"
		. "Press CONTROL+C to copy this dialog text with the URL.`n`n"
		. "Script will exit now",
		"ERROR: Script .ahk_hotkeys file not found",
		16
	)
	ExitApp()
}

global RunScriptAsAdmin := IniRead(IniSettingsFilePath, "GeneralSettings", "RunScriptAsAdmin", "no")
if (RunScriptAsAdmin == "ERROR") 
{
	RunScriptAsAdmin := "no"
}

; Get full path for script
full_command_line := DllCall("GetCommandLine", "str")

if (RunScriptAsAdmin = "yes") 
{	
	; Validate the script has admin rights, as it is necessary for the route_add commands to work 
	if !(A_IsAdmin || RegExMatch(full_command_line, " /restart(?!\S)"))
	{
		try
		{
			if A_IsCompiled
				Run('*RunAs "' . A_ScriptFullPath . '" /restart')
			else
				Run('*RunAs "' . A_AhkPath . '" /restart "' . A_ScriptFullPath . '"')
		}
		ExitApp()
	}
}

; GeneralSettings Section	
global WinEnvName := IniRead(IniSettingsFilePath, "GeneralSettings", "WinEnvName", "")
if (WinEnvName == "ERROR")
{
	WinEnvName := ""
}

global MaxBrowserArguments := IniRead(IniSettingsFilePath, "GeneralSettings", "BrowsersProfiles-MaxBrowserArguments", "10")
if (MaxBrowserArguments == "ERROR" || !IsInteger(MaxBrowserArguments))
{
	MaxBrowserArguments := 10
}
else
{
	MaxBrowserArguments := Integer(MaxBrowserArguments)
}

global MaxOpenWebSiteInputs := IniRead(IniSettingsFilePath, "GeneralSettings", "ShowOpenWebSiteWithInput-MaxOpenWebSiteInputs", "10")
if (MaxOpenWebSiteInputs == "ERROR" || !IsInteger(MaxOpenWebSiteInputs))
{
	MaxOpenWebSiteInputs := 10
}
else
{
	MaxOpenWebSiteInputs := Integer(MaxOpenWebSiteInputs)
}

global MaxFolderSlots := 20
global MaxOpenCreateFolderAndFileInputs := 10

; VPN config variables, used inside functions:
; VARIABLES FOR AddIPtoRoute()
global ClientIP := IniRead(IniSettingsFilePath, "VPNSettings", "ClientIP", "")
global FQDN     := IniRead(IniSettingsFilePath, "VPNSettings", "FQDN", "")
global Mask     := IniRead(IniSettingsFilePath, "VPNSettings", "Mask", "")
global Gateway  := IniRead(IniSettingsFilePath, "VPNSettings", "Gateway", "")

; General init message
MsgBox(
	"Run as admin: " . A_IsAdmin . "`n"
	. "Environment: " . WinEnvName . "`n"
	. "Script Source: `n" . full_command_line,
	"Running " . A_ScriptName . " script",
	64
)

; InputHook global definitions
global ProcessSlotInputHook := ""
global FolderSlotSearchById := false

; Including Hotkeys shortcut on remote file
#Include %A_ScriptDir%
#Include %A_ScriptName%_hotkeys 

open_ini_file(*) {
	Run(IniSettingsFilePath)
}

; BEGIN Script-Wide special placeholder variables replacement function ReplacePlaceholderStrings
; which will be replaced on all functions that hase this line:
; <== {PLACEHOLDER VARIABLE ENABLED} ==>
ReplacePlaceholderStrings(BaseString) {
	; Function to dynamically generate values based on common AHK expressions, this will allow you to use these placeholders 
	; at the ini file to set names based on AHk variables. 
	; Note: Not all of these placeholders are standard AHK variables
	SanitizedString := BaseString

	; Custom placeholders not default for  AHK variables
	SanitizedString := StrReplace(SanitizedString, "{A_DATE_NOW}", FormatTime(, "yyyy-MM-dd"))
	SanitizedString := StrReplace(SanitizedString, "{A_TIME_NOW}", FormatTime(, "HH.mm.ss"))
	SanitizedString := StrReplace(SanitizedString, "{A_12HourAM_PM}", FormatTime(, "hh.mm.ss tt"))
	SanitizedString := StrReplace(SanitizedString, "{A_YDay0}", FormatTime(, "YDay0"))

	; Week of year (last 2 digits)
	SanitizedString := StrReplace(SanitizedString, "{A_Week_of_year}", SubStr(A_YWeek, -2))

	; Standard date/time variable replacements
	SanitizedString := StrReplace(SanitizedString, "{A_YYYY}", A_YYYY)
	SanitizedString := StrReplace(SanitizedString, "{A_Year}", A_YYYY)

	Previous_A_YYYY := String(Integer(A_YYYY) - 1)
	SanitizedString := StrReplace(SanitizedString, "{A_Year-1}", Previous_A_YYYY)

	SanitizedString := StrReplace(SanitizedString, "{A_MM}", A_MM)

	Previous_A_MM := Format("{:02}", Integer(A_MM) - 1)
	SanitizedString := StrReplace(SanitizedString, "{A_MM-1}", Previous_A_MM)

	SanitizedString := StrReplace(SanitizedString, "{A_Mon}", A_MM)
	SanitizedString := StrReplace(SanitizedString, "{A_DD}", A_DD)
	SanitizedString := StrReplace(SanitizedString, "{A_MDay}", A_DD)
	SanitizedString := StrReplace(SanitizedString, "{A_MMMM}", FormatTime(, "MMMM"))
	SanitizedString := StrReplace(SanitizedString, "{A_MMM}", FormatTime(, "MMM"))
	SanitizedString := StrReplace(SanitizedString, "{A_DDDD}", FormatTime(, "dddd"))
	SanitizedString := StrReplace(SanitizedString, "{A_DDD}", FormatTime(, "ddd"))
	SanitizedString := StrReplace(SanitizedString, "{A_WDay}", A_WDay)
	SanitizedString := StrReplace(SanitizedString, "{A_YDay}", A_YDay)
	SanitizedString := StrReplace(SanitizedString, "{A_YWeek}", A_YWeek)
	SanitizedString := StrReplace(SanitizedString, "{A_Hour}", A_Hour)
	SanitizedString := StrReplace(SanitizedString, "{A_Min}", A_Min)
	SanitizedString := StrReplace(SanitizedString, "{A_Sec}", A_Sec)
	SanitizedString := StrReplace(SanitizedString, "{A_MSec}", A_MSec)
	SanitizedString := StrReplace(SanitizedString, "{A_Now}", A_Now)
	SanitizedString := StrReplace(SanitizedString, "{A_LineBreak}", "`n")

	; User-defined paths
	KnownPaths := [
		"A_MyDocuments_Path", "A_Downloads_Path", "A_ProgramFiles_Path",
		"A_ProgramFiles_x86_Path", "A_UserFolder_Path"
	]
	Loop 12 {
		KnownPaths.Push("A_User_Defined_Path_" . A_Index)
	}

	for _, PathKey in KnownPaths {
		UserDefinedPathVar := IniRead(IniSettingsFilePath, "UserDefinedPaths", PathKey, "")
		UserDefinedPathVar := CleanUpPathString(UserDefinedPathVar)
		SanitizedString := StrReplace(SanitizedString, "{" . PathKey . "}", UserDefinedPathVar)
	}

	return SanitizedString
}

; BEGIN Functions to process input hooks, which are used by slot-based functions
ProcessSlotInputHook_Char(ih, char) {
    global FolderSlotSearchById, ProcessSlotInputHook

    ; ASCII 27 is Escape - intercept it so it never gets drawn as a square
    if (char != "" && Ord(char) = 27) {
        ToolTip("ABORTED")
        SetTimer(() => ToolTip(), -500)
        ih.Stop()
        return
    }

    InputFirstChar := SubStr(ih.Input, 1, 1)
    FolderSlotSearchById := IsInteger(InputFirstChar)

    if (FolderSlotSearchById) {
        ToolTip("FolderSlot ID: " . ih.Input)
        ih.KeyOpt("{Space}", "E")
    } else {
        ToolTip("FolderSlot label: " . ih.Input)
        ih.KeyOpt("{Space}", "-E")
    }
}

ProcessSlotInputHook_KeyDown(ih, vk, sc) {
    global FolderSlotSearchById
    if (vk = 8) { ; Backspace
        ProcessSlotInputHook_Char(ih, "")
    } else if (vk = 32) { ; Space
        if (FolderSlotSearchById) {
            ih.Stop()
        }
    } else if (vk = 27) { ; Esc
        ToolTip("ABORTED")
        SetTimer(() => ToolTip(), -500)
        ih.Stop()
    } else if (vk = 9) { ; Tab
        ih.Stop()
    }
}

ProcessSlotInputHook_End(ih) {
	SetTimer(() => ToolTip(), -500)
}
; END Functions to process input hooks, which are used by slot-based functions

; BEGIN Functions to process dynamic input variables, will be used by several functions to process a list of inputs and replace them over a base string
ProcessVariableInputString(MaxLoopCount, IniFileSection, IniFileKeyPreffix, IniFileKeySuffix, NameDescription, BaseString) {
	; <== {PLACEHOLDER VARIABLE ENABLED} ==>
	; To keep maximum compatibility, IniFileKeyPreffix and IniFileKeySuffix will be used optionally, since there are INI file sections with the format
	; Variable_numID  and also PROGRAM-Varaible (with no numeric ID)
	; This function will receive loop count, an INI file section to go through variables, and then it will replace and sanitize the base string provided
	; Also, this function will error out with the string FUNCTION_EXITED_WITH_ERROR:%ErrorLevel% (Error level will be 1 on CANCEL, or 2 on TIMEOUT)
	; if the user pressed one of these buttons, code that use this function should validate this error string so it stops executing any other code afterwards 

	; NameInput%a_index% will be MANDATORY, even if it does not contains any RegExDeleteFromInput or RegExInsertInput with values, 
	; and EVEN if it use a special reserved word like DATE_NOW() or TIME_NOW().
	; IniRead, MaxFolderSlots, %IniSettingsFilePath%, GeneralSettings, %IniFileKeyPreffix%-MaxFolderSlots

	; MsgBox(MaxLoopCount) ; [HGE] (DEBUG) Uncomment_for_tests
	; MsgBox(IniFileSection) ; [HGE] (DEBUG) Uncomment_for_tests
	; MsgBox(IniFileKeyPreffix) ; [HGE] (DEBUG) Uncomment_for_tests
	; MsgBox(IniFileKeySuffix) ; [HGE] (DEBUG) Uncomment_for_tests
	; MsgBox(BaseString) ; [HGE] (DEBUG) Uncomment_for_tests
	SanitizedString := BaseString

	Loop MaxLoopCount {
		NameInput := IniRead(IniSettingsFilePath, IniFileSection, IniFileKeyPreffix . "NameInput" . A_Index . IniFileKeySuffix, "ERROR")
		RegExDeleteFromInput := IniRead(IniSettingsFilePath, IniFileSection, IniFileKeyPreffix . "RegExDeleteFromInput" . A_Index . IniFileKeySuffix, "")
		RegExInsertInput := IniRead(IniSettingsFilePath, IniFileSection, IniFileKeyPreffix . "RegExInsertInput" . A_Index . IniFileKeySuffix, "")

		SanitizedString := ReplacePlaceholderStrings(SanitizedString)

		if (NameInput == "ERROR")
			break

		IB := InputBox("Enter " . NameInput . " for " . NameDescription, WinEnvName)
		if (IB.Result != "OK") {
			ErrorLevelCode := (IB.Result = "Cancel") ? 1 : 2
			return "FUNCTION_EXITED_WITH_ERROR:" . ErrorLevelCode
		}

		RegExCleanedInput := RegExReplace(IB.Value, RegExDeleteFromInput)
		SanitizedString := RegExReplace(SanitizedString, RegExInsertInput, RegExCleanedInput)
	}

	return SanitizedString
}

CleanUpPathString(BaseString, LeftTrim := true, RightTrim := true, SanitizeChar := "\") {
	; This function will remove left and rigt white spaces and tabs, also it will remove a single leading and trailing SanitizeChar from the BaseString declared 
	BaseString := Trim(BaseString)

	if (BaseString != "") {
		if (LeftTrim && SubStr(BaseString, 1, 1) == SanitizeChar)
			BaseString := SubStr(BaseString, 2)

		if (RightTrim && SubStr(BaseString, -1) == SanitizeChar)
			BaseString := SubStr(BaseString, 1, -1)
	}

	return BaseString
}

ToggleAlwaysOnTop() {
	MouseGetPos(, , &AppWin)
	if (!AppWin)
		return

	AppWinStatus := WinGetExStyle("ahk_id " . AppWin)
	WinResult := AppWinStatus & 0x8
	WinSetAlwaysOnTop(-1, "ahk_id " . AppWin)

	if (WinResult = 0) {
		WinActivate("ahk_id " . AppWin)
		ToolTip("Always on top enabled")
	} else {
		ToolTip("Always on top disabled")
	}
	SetTimer(() => ToolTip(), -500)
}

WrittenPaste() {
	SendText(A_Clipboard)
}

SearchAndClose(WindowTitle, CloseCommand) {
	Loop {
		if WinExist(WindowTitle) {
			WinActivate(WindowTitle)
			if !WinWaitActive(WindowTitle, , 3) {
				MsgBox("No more windows with the title: `n`"" . WindowTitle . "`"", WinEnvName . "No more windows", 64)
				return
			}

			switch CloseCommand {
				case "Alt+F4":
					Send("!{F4}")
				case "Control+Q":
					Send("^q")
			}
			Sleep(100)
		} else {
			MsgBox("No more windows with the title: `n`"" . WindowTitle . "`"", WinEnvName . "No more windows", 64)
			return
		}
	}
}

AddIPtoRoute() {
	global ClientIP
	VpnName := IniRead(IniSettingsFilePath, "VPNSettings", "VpnName", "")
	IB := InputBox("This will add the IP to the IP route for the " . VpnName, WinEnvName . "Enter the client's IP or FQDN")
	if (IB.Result != "OK")
		return

	ClientServer := IB.Value
	if ValidateIP(Trim(ClientServer)) {
		ClientIP := ClientServer
		RunAddCommand(ClientIP, Mask, Gateway)
	} else {
		ClientIP := FQDN_to_IP(Trim(ClientServer))
		PingResult := FQDN_to_IP(ClientServer)
		if (PingResult == "NO_ERROR") {
			RunAddCommand(ClientIP, Mask, Gateway)
			A_Clipboard := ClientIP
		} else {
			MsgBox(PingResult, WinEnvName . "Invalid IP or FQDN", 0)
		}
	}
}

RunAddCommand(IP, Mask, Gateway) {
	try RunWait('*runas ' . A_ComSpec . ' /c "route add ' . IP . ' MASK ' . Mask . ' ' . Gateway . ' > route_add.result"', , "Hide")
	
	IPAddResult := ""
	if FileExist("route_add.result") {
		try {
			IPAddResult := FileRead("route_add.result")
			FileDelete("route_add.result")
		}
	}

	if (IPAddResult == "")
		MsgBox("IP could not be added, probably it's already in Route Table", WinEnvName)
	else
		MsgBox("IP address added " . IPAddResult, WinEnvName)
}

ValidateIP(IPAddress) {
	if (StrLen(IPAddress) > 15 || InStr(IPAddress, " "))
		return false

	Octets := StrSplit(IPAddress, ".")
	if (Octets.Length != 4)
		return false

	for _, octet in Octets {
		if (!IsInteger(octet) || Integer(octet) < 0 || Integer(octet) > 255)
			return false
	}

	if (Integer(Octets[1]) < 1)
		return false

	return true
}

FQDN_to_IP(FQDN) { 
	; Convert FQDN to IP (may work almost always...)
	; FQDN=http://www.google.com
	; FQDN=192.168.122.1
	; FQDN=HeaderGarble http://www.yahoo.co.uk/forum/posting.php?mode=newtopic&f=1EndingGarbleEtc 
	global ClientIP
	FQDN := RegExReplace(FQDN, "i)^.*https?:\/\/", "")
	FQDN := RegExReplace(FQDN, "i):.*|\/.*|\?.*", "")

	try RunWait('*runas ' . A_ComSpec . ' /c "ping ' . FQDN . ' -n 1 -w 300 > ping.result"', , "Hide")

	PingResult := ""
	if FileExist("ping.result") {
		try {
			PingResult := FileRead("ping.result")
			FileDelete("ping.result")
		}
	}

	if RegExMatch(PingResult, "Request timed out\.")
		return "Request timed out."

	if RegExMatch(PingResult, "Ping request could not find host")
		return "Request could not find host."

	if RegExMatch(PingResult, "Reply from") {
		if RegExMatch(PingResult, "Ping statistics for (.*?):", &IpMatch) {
			ClientIP := IpMatch[1]
		}
		return "NO_ERROR"
	}

	return "OTHER_ERROR"
}

RunWithNoElevation(Target, Arguments, WorkingDirectory) {
	static TASK_TRIGGER_REGISTRATION := 7
	static TASK_ACTION_EXEC := 0
	static TASK_CREATE := 2
	static TASK_RUNLEVEL_LUA := 0
	static TASK_LOGON_INTERACTIVE_TOKEN := 3

	objService := ComObject("Schedule.Service")
	objService.Connect()

	objFolder := objService.GetFolder("")
	objTaskDefinition := objService.NewTask(0)

	principal := objTaskDefinition.Principal
	principal.LogonType := TASK_LOGON_INTERACTIVE_TOKEN
	principal.RunLevel := TASK_RUNLEVEL_LUA

	colTasks := objTaskDefinition.Triggers
	objTrigger := colTasks.Create(TASK_TRIGGER_REGISTRATION)
	endTime := DateAdd(A_Now, 1, "Minutes")
	objTrigger.EndBoundary := FormatTime(endTime, "yyyy-MM-dd'T'HH:mm:ss")

	colActions := objTaskDefinition.Actions
	objAction := colActions.Create(TASK_ACTION_EXEC)
	objAction.ID := "7plus run"
	objAction.Path := Target
	objAction.Arguments := Arguments
	objAction.WorkingDirectory := WorkingDirectory ? WorkingDirectory : A_WorkingDir

	objInfo := objTaskDefinition.RegistrationInfo
	objInfo.Author := "7plus"
	objInfo.Description := "Runs a program as non-elevated user"

	objSettings := objTaskDefinition.Settings
	objSettings.Enabled := true
	objSettings.Hidden := false
	objSettings.DeleteExpiredTaskAfter := "PT0S"
	objSettings.StartWhenAvailable := true
	objSettings.ExecutionTimeLimit := "PT0S"
	objSettings.DisallowStartIfOnBatteries := false
	objSettings.StopIfGoingOnBatteries := false

	objFolder.RegisterTaskDefinition("", objTaskDefinition, TASK_CREATE, "", "", TASK_LOGON_INTERACTIVE_TOKEN)
}

ShowOrRunProgram(ProgramNameId) {
	AhkExeName   := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOrRunProgram", ProgramNameId . "-AhkExeName", "ERROR"))
	AhkGroupName := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOrRunProgram", ProgramNameId . "-AhkGroupName", "ERROR"))
	ProgramName  := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOrRunProgram", ProgramNameId . "-ProgramName", "ERROR"))
	CommandExe   := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOrRunProgram", ProgramNameId . "-CommandExe", "ERROR"))
	CommandPath  := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOrRunProgram", ProgramNameId . "-CommandPath", "ERROR"))
	CommandArgs  := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOrRunProgram", ProgramNameId . "-CommandArgs", "ERROR"))

	if (AhkExeName == "ERROR" || AhkGroupName == "ERROR" || ProgramName == "ERROR" || CommandExe == "ERROR" || CommandPath == "ERROR" || CommandArgs == "ERROR") {
		MsgBox('ERROR... Missing parameters for ShowOrRunProgram function check the "' . IniSettingsFileName . '" file')
		return
	}

	SetTitleMatchMode(2)
	if WinExist(AhkExeName) {
		GroupAdd(AhkGroupName, AhkExeName)
		GroupActivate(AhkGroupName)
	} else {
		ans := MsgBox("No window with that title found, open new instance?", WinEnvName . "Launch " . ProgramName . "?", 36)
		if (ans = "Yes") {
			if (RunScriptAsAdmin = "yes")
				RunWithNoElevation(CommandExe, CommandArgs, CommandPath)
			else
				Run('"' . CommandExe . '" ' . CommandArgs)
		}
	}
}

ShowOpenWebSiteWithInput(WebSiteWithInputNameId) {
	AhkSearchWindowTitle := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-AhkSearchWindowTitle", "DO_NOT_SEARCH"))
	AhkGroupName         := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-AhkGroupName", "DO_NOT_GROUP"))
	SiteName             := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-SiteName", "ERROR"))
	OpenWebSiteOperation := IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-OpenWebSiteOperation", "ERROR")
	BaseUrl              := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-BaseUrl", "ERROR"))

	ErrorCounter := 0
	ErrorString := ""

	; [BEGIN] Error validation for both types of OpenWebSiteOperation
		if (SiteName == "ERROR") {
			ErrorCounter++
			ErrorString .= "- SiteName not defined on ini file `n"
		}
		if (BaseUrl == "ERROR") {
			ErrorCounter++
			ErrorString .= "- BaseUrl not defined on ini file `n"
		}
		if (OpenWebSiteOperation == "ERROR") {
			ErrorCounter++
			ErrorString .= "- OpenWebSiteOperation not defined on ini file `n"
		}
	; [END] Error validation for both types of OpenWebSiteOperation

	BrowserRawArgs := ""
	BrowserExe := ""
	BrowserPath := ""

	if (OpenWebSiteOperation = "Open_Website") {
		; [BEGIN] Set browser profile in [ShowOpenWebSiteWithInput] this will indicate fields to load from [BrowsersProfiles]
		BrowserProfile := IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-BrowserProfile", "ERROR")
		if (BrowserProfile == "ERROR") {
			; Attempt to load default profile defined at [GeneralSettings] before finally declaring error
			BrowserProfile := IniRead(IniSettingsFilePath, "GeneralSettings", "BrowsersProfile-DefaultProfile", "ERROR")
			if (BrowserProfile == "ERROR") {
				ErrorCounter++
				ErrorString .= "- Default BrowserProfile not defined on [GeneralSettings] section or at [BrowsersProfiles] section `n"
			}
		}
		; Sanitize string with ReplacePlaceholderStrings()
		BrowserProfile := ReplacePlaceholderStrings(BrowserProfile)

		OpenTarget := IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-OpenTarget", "New_Tab")
		if (OpenTarget == "ERROR")
			OpenTarget := "New_Tab"

		BrowserExe := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "BrowsersProfiles", BrowserProfile . "-DefinedBrowserExe", "ERROR"))
		BrowserPath := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "BrowsersProfiles", BrowserProfile . "-DefinedBrowserPath", "ERROR"))
		BrowserUserProfile := ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "BrowsersProfiles", BrowserProfile . "-DefinedBrowserUserProfile", ""))
		if (BrowserUserProfile == "ERROR")
			BrowserUserProfile := ""

		NewWindowArg := IniRead(IniSettingsFilePath, "BrowsersProfiles", BrowserProfile . "-DefinedBrowserNewWindowArg", "")
		if (NewWindowArg == "ERROR")
			NewWindowArg := ""

		NewTabArg := IniRead(IniSettingsFilePath, "BrowsersProfiles", BrowserProfile . "-DefinedBrowserNewTabArg", "")
		if (NewTabArg == "ERROR")
			NewTabArg := ""

		if (BrowserExe == "ERROR") {
			ErrorCounter++
			ErrorString .= "- BrowserExe from BrowserProfile *" . BrowserProfile . "* not defined on [BrowsersProfiles] section at ini file `n"
		}
		if (BrowserPath == "ERROR") {
			ErrorCounter++
			ErrorString .= "- BrowserPath from BrowserProfile *" . BrowserProfile . "* not defined on [BrowsersProfiles] section at ini file `n"
		}

		if (ErrorCounter > 0) {
			MsgBox("Function aborted, .ini file contains the following errors: `n" . ErrorString, WinEnvName . "Please check ini file", 48)
			return
		}

		BrowserRawArgs := BrowserUserProfile
		Loop MaxBrowserArguments {
			ArgVal := IniRead(IniSettingsFilePath, "BrowsersProfiles", BrowserProfile . "-DefinedBrowserArguments" . A_Index, "ERROR")
			ArgVal := ReplacePlaceholderStrings(ArgVal)
			if (ArgVal == "ERROR" || ArgVal == "")
				break
			BrowserRawArgs .= ArgVal
		}

		if (OpenTarget == "New_Window")
			BrowserRawArgs .= NewWindowArg
		else if (OpenTarget == "New_Tab")
			BrowserRawArgs .= NewTabArg
	}

	if (ErrorCounter > 0) {
		MsgBox("Function aborted, .ini file contains the following errors: `n" . ErrorString, WinEnvName . "Please check ini file", 48)
		return
	}

	AskWebSiteWithInput() {
		BrowserURL := BaseUrl
		Loop MaxOpenWebSiteInputs {
			; This function will take arguments from ini file, sequentially starting from 1, 
			;  until it finds no continuous N argument or until %MaxOpenWebSiteInputs%
			NameInputVal := IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-NameInput" . A_Index, "ERROR")
			NameInputVal := ReplacePlaceholderStrings(NameInputVal)

			RegExDeleteVal := IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-RegExDeleteFromInput" . A_Index, "")
			RegExInsertVal := IniRead(IniSettingsFilePath, "ShowOpenWebSiteWithInput", WebSiteWithInputNameId . "-RegExInsertInput" . A_Index, "")

			if (NameInputVal == "ERROR")
				break

			IB := InputBox("Enter " . NameInputVal . " for " . SiteName . " URL", WinEnvName)
			if (IB.Result != "OK")
				return

			UrlInputClean := ReplacePlaceholderStrings(IB.Value)
			CleanUrlInput := RegExReplace(UrlInputClean, RegExDeleteVal)
			BrowserURL := RegExReplace(BrowserURL, RegExInsertVal, CleanUrlInput)
		}

		if (OpenWebSiteOperation = "Copy_URL") {
			A_Clipboard := BrowserURL
			MsgBox("Formatted URL copied to clipboard", WinEnvName, 64)
		} else if (OpenWebSiteOperation = "Open_Website") {
			; By default this will replace the placeholder {BASE_URL_REPLACE_HERE} at the ini file, make sure you put the same placeholder or modify the code if you prefer
			BrowserArgs := RegExReplace(BrowserRawArgs, "i)\{BASE_URL_REPLACE_HERE\}", BrowserURL)
			; Work-around not to run tasks as administrator since the Script itself needs to be run like that for other tasks 
				; WARNING: RunWithNoElevation() may trigger alerts on some Antivirus software flagging it as:
				; 	- Trojan.Multi.GenAutorunTask.b
				; 	- PDM:Trojan.Win32.GenAutorunSchedulerTaskRun.b
				; This is due to the function using svchost.exe to "program" the task to start the desired application or process.
			if (RunScriptAsAdmin = "yes")
				RunWithNoElevation(BrowserExe, BrowserArgs, BrowserPath)
			else
				Run('"' . BrowserExe . '" ' . BrowserArgs)
		}
	}

	SetTitleMatchMode(2)
	if (WinExist(AhkSearchWindowTitle) && AhkSearchWindowTitle != "DO_NOT_SEARCH") {
		GroupAdd(AhkGroupName, AhkSearchWindowTitle)
		GroupActivate(AhkGroupName)

		if (OpenWebSiteOperation = "Copy_URL")
			AskWebSiteWithInput()
	} else {
		if (AhkSearchWindowTitle = "DO_NOT_SEARCH") {
			AskWebSiteWithInput()
		} else {
			ans := MsgBox("No window with that title found, open new instance?", WinEnvName . "Open " . SiteName . "?", 36)
			if (ans = "Yes")
				AskWebSiteWithInput()
		}
	}
}

ProcessFolderSlot_X(IdOrLabel := "") {
	global FolderSlotSearchById, ProcessSlotInputHook

	MaxSlots := IniRead(IniSettingsFilePath, "GeneralSettings", "CreateOpenFolder_X-MaxFolderSlots", "20")
	MaxSlots := (MaxSlots == "ERROR" || !IsInteger(MaxSlots)) ? 20 : Integer(MaxSlots)

	FolderSlot := ""

	; BEGIN code to call slot directly is defined via hotkey
	if (IdOrLabel != "") {
		FolderSlot := Trim(IdOrLabel)
		FolderSlotSearchById := IsInteger(FolderSlot)
	} else {
		ToolTip("Type FolderSlot ID or label: ")
		FolderSlotSearchById := false
	; END code to call slot directly is defined via hotkey

		ProcessSlotInputHook := InputHook("L30T20", "{Enter}{Tab}")
		ProcessSlotInputHook.OnChar := ProcessSlotInputHook_Char
		ProcessSlotInputHook.OnKeyDown := ProcessSlotInputHook_KeyDown
		ProcessSlotInputHook.OnEnd := ProcessSlotInputHook_End
		ProcessSlotInputHook.KeyOpt("{Backspace}{space}{tab}", "N")
		ProcessSlotInputHook.KeyOpt("{Esc}", "NS")
		ProcessSlotInputHook.Start()

		EndReason := ProcessSlotInputHook.Wait()

		if (EndReason = "Stopped")
			return

		ToolTip()
		FolderSlot := ProcessSlotInputHook.Input
	}

	FolderSlot := Trim(FolderSlot)
	if (FolderSlot = "")
		return

	if (FolderSlot = "e") {
		FolderSlotsDescription := "=== Currently set folder Slots === `n`n"
		FolderSlotCounter := 0

		Loop MaxSlots {
			SlotIdx := (A_Index == MaxSlots) ? 0 : A_Index
			SlotLabel := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "FolderLabel_" . SlotIdx, "")
			LocName   := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "LocationName_" . SlotIdx, "ERROR")
			OpName    := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "FolderOperation_" . SlotIdx, "")

			if (LocName != "ERROR") {
				FolderSlotCounter++
				FolderSlotsDescription .= " - Slot: [" . SlotIdx . "] -- Label: [" . SlotLabel . "]`n    Name: " . LocName . " -- Operation: " . OpName . "`n"
			}
		}

		FolderSlotsDescription .= "`nTotal folders: (" . FolderSlotCounter . ")"

		if (FolderSlotCounter < 20) {
			MsgBox(FolderSlotsDescription, WinEnvName . "List of set up folder slots", 32)
		} else {
			A_Clipboard := FolderSlotsDescription
			MsgBox("List of set up folder slots is too long, full list was copied to clipboard", WinEnvName, 32)
		}
		return
	}

	ValidateFolderData(BaseFolderPath, LocationName, FolderOperation, SlotID) {
		if (BaseFolderPath == "ERROR") {
			MsgBox('ERROR... SLOT "' . FolderSlot . '" base folder path not defined, check the "' . IniSettingsFileName . '" file under `n[CreateOpenFolder_X] --> BaseFolderPath_xx')
			return
		}

		if (!FileExist(BaseFolderPath)) {
			MsgBox('ERROR... SLOT "' . FolderSlot . '" `n' . BaseFolderPath . '`nBase folder directory not found, check the "' . IniSettingsFileName . '" file under `n[CreateOpenFolder_X] --> BaseFolderPath_xx')
			return
		}

		if (BaseFolderPath == "") {
			MsgBox('SLOT ' . FolderSlot . ' is empty, set it on the "' . IniSettingsFileName . '" file')
			return
		}

		if (LocationName == "")
			LocationName := FolderSlot

		if (FolderOperation == "")
			FolderOperation := "Open_Folder"

		FolderString := ""
		FileNameString := ""

		if (FolderOperation == "Open_Create_Folder_And_File") {
			MaxInputs := IniRead(IniSettingsFilePath, "GeneralSettings", "CreateOpenFolder_X-MaxOpenCreateFolderAndFileInputs", "10")
			MaxInputs := (MaxInputs == "ERROR" || !IsInteger(MaxInputs)) ? 10 : Integer(MaxInputs)

			VariableFolderPath := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "Folder-VariableFolderPath_" . SlotID, "")
			VariableFileName   := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "File-CreateWithName_" . SlotID, "ERROR")

			FolderString := ProcessVariableInputString(MaxInputs, "CreateOpenFolder_X", "Folder-", "_" . SlotID, LocationName, VariableFolderPath)
			if (FolderString == "FUNCTION_EXITED_WITH_ERROR:1")
				return

			if (VariableFileName == "ERROR") {
				FileNameString := "ERROR"
			} else {
				FileNameString := ProcessVariableInputString(MaxInputs, "CreateOpenFolder_X", "File-", "_" . SlotID, LocationName, VariableFileName)
				if (FileNameString == "FUNCTION_EXITED_WITH_ERROR:1")
					return
			}
		}

		CreateOpenFolder(BaseFolderPath, LocationName, FolderOperation, FolderString, FileNameString, SlotID)
	}

	if (FolderSlotSearchById) {
		SlotID := FolderSlot
		BasePath := CleanUpPathString(ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "BaseFolderPath_" . FolderSlot, "ERROR")))
		LocName  := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "LocationName_" . FolderSlot, "")
		FoldOp   := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "FolderOperation_" . FolderSlot, "")

		ValidateFolderData(BasePath, LocName, FoldOp, SlotID)
	} else {
		FolderSlotLabelFound := false
		Loop MaxSlots {
			SlotIdx := (A_Index == MaxSlots) ? 0 : A_Index
			SlotLabel := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "FolderLabel_" . SlotIdx, "")

			if (SlotLabel = FolderSlot) {
				SlotID := SlotIdx
				BasePath := CleanUpPathString(ReplacePlaceholderStrings(IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "BaseFolderPath_" . SlotIdx, "ERROR")))
				LocName  := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "LocationName_" . SlotIdx, "")
				FoldOp   := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "FolderOperation_" . SlotIdx, "")

				FolderSlotLabelFound := true
				ValidateFolderData(BasePath, LocName, FoldOp, SlotID)
				break
			}
		}

		if (!FolderSlotLabelFound) {
			MsgBox("Folder slot not found, please check spelling or enter 'e' to show list of all folder slots.", WinEnvName . "Not found", 48)
		}
	}
}

CreateOpenFolder(BaseFolderPath, LocationName, FolderOperation, Folder_VariableFolderPath := "", File_CreateWithName := "", FolderSlotID := "") {
	BaseFolderPath := CleanUpPathString(ReplacePlaceholderStrings(BaseFolderPath))
	Folder_VariableFolderPath := CleanUpPathString(ReplacePlaceholderStrings(Folder_VariableFolderPath))
	File_CreateWithName := CleanUpPathString(ReplacePlaceholderStrings(File_CreateWithName))

	FolderFullPath := ""
	FolderName := ""

	if (FolderOperation == "Open_Create") {
		IB := InputBox("Folder will be created or opened, if it does not exist it will be created at `n`n " . BaseFolderPath, WinEnvName . "Enter name for " . LocationName)
		if (IB.Result != "OK")
			return

		FolderName := Trim(IB.Value)
		if (FolderName == "")
			return

		FolderFullPath := BaseFolderPath . "\" . FolderName
	} else if (FolderOperation == "Open_Folder") {
		PathArray := StrSplit(BaseFolderPath, "\")
		FolderName := PathArray[PathArray.Length]
		FolderFullPath := BaseFolderPath
	} else if (FolderOperation == "Open_Create_Folder_And_File") {
		TempFolder := (Folder_VariableFolderPath != "" && Folder_VariableFolderPath != "ERROR")
			? BaseFolderPath . "\" . Folder_VariableFolderPath
			: BaseFolderPath

		PathArray := StrSplit(TempFolder, "\")
		FolderName := PathArray[PathArray.Length]
		FolderFullPath := TempFolder
	}

	if InStr(FileExist(FolderFullPath), "D") {
		A_Clipboard := FolderFullPath

		if WinWait(FolderName . " ahk_exe explorer.exe", , 0.5) {
			WinActivate(FolderName . " ahk_exe explorer.exe")
			if (FolderOperation == "Open_Create_Folder_And_File" && File_CreateWithName != "ERROR") {
				CheckCreateOpenFile(FolderFullPath, File_CreateWithName, LocationName, false, false, FolderSlotID)
			}
		} else {
			if (FolderOperation == "Open_Folder") {
				ans := MsgBox("Open [" . LocationName . "] `nPath: " . FolderFullPath . " `nNo window with that title found, open?", WinEnvName . "Open Folder", 36)
				if (ans = "Yes")
					; NOTE: Check RunWithNoElevation() warnings if this ever gets implemented
					Run('explorer.exe "' . FolderFullPath . '"')
			} else if (FolderOperation == "Open_Create") {
				Run('explorer.exe "' . FolderFullPath . '"')
			} else if (FolderOperation == "Open_Create_Folder_And_File") {
				Run('explorer.exe "' . FolderFullPath . '"')
				Sleep(1200)
				if (File_CreateWithName != "ERROR") ; Filename not set on .ini file
					CheckCreateOpenFile(FolderFullPath, File_CreateWithName, LocationName, false, false, FolderSlotID)
			}
		}
	} else if (FolderOperation == "Open_Create") {
		DirCreate(FolderFullPath)
		Run('explorer.exe "' . FolderFullPath . '"')
		A_Clipboard := FolderFullPath
	} else if (FolderOperation == "Open_Create_Folder_And_File") {
		OpenCreateMessage := (File_CreateWithName == "ERROR")
			? "Directory path does not exist: `n" . FolderFullPath . " `nProceed?"
			: "Directory path does not exist: `n" . FolderFullPath . " `n`nAlso new file '" . File_CreateWithName . "' will be created`nProceed?"

		ans := MsgBox(OpenCreateMessage, WinEnvName . "Create new directory?", 36)
		if (ans = "Yes") {
			DirCreate(FolderFullPath)
			Run('explorer.exe "' . FolderFullPath . '"')
			A_Clipboard := FolderFullPath
			Sleep(1200)

			if (File_CreateWithName != "ERROR")
				CheckCreateOpenFile(FolderFullPath, File_CreateWithName, LocationName, false, false, FolderSlotID)
		}
	}
}

CheckCreateOpenFile(FolderPath, CreatedFileName, LocationName := "No name", ConfirmFileCreation := false, ConfirmFileOpening := false, FolderSlotID := "") {
	FolderPath := CleanUpPathString(ReplacePlaceholderStrings(FolderPath))
	CreatedFileName := CleanUpPathString(ReplacePlaceholderStrings(CreatedFileName))
	FullFileName := FolderPath . "\" . CreatedFileName

	if (FileExist(FullFileName)) {
		if (ConfirmFileOpening) {
			ans := MsgBox(CreatedFileName . " already exists at: `n" . FolderPath . " `nProceed?", WinEnvName . "Open file?", 36)
			if (ans = "No")
				return
		}
	} else {
		if (ConfirmFileCreation) {
			ans := MsgBox(CreatedFileName . " does not exist at: `n" . FolderPath . " `nProceed?", WinEnvName . "Create new file?", 36)
			if (ans = "No")
				return
		}

		FileContents := ""
		Loop {
			FileCurrentLine := IniRead(IniSettingsFilePath, "CreateOpenFolder_X", "File-CreateWithContents" . A_Index . "_" . FolderSlotID, "ERROR")
			if (FileCurrentLine == "ERROR")
				break

			FileCurrentLine := StrReplace(FileCurrentLine, "\n", "`n")
			FileCurrentLine := ReplacePlaceholderStrings(FileCurrentLine)
			FileContents .= FileCurrentLine . "`n"
		}

		FileAppend(FileContents, FullFileName)

		if (ConfirmFileOpening) {
			ans := MsgBox(CreatedFileName . " was created at: `n" . FolderPath . " `nProceed?", WinEnvName . "Open created file?", 36)
			if (ans = "No")
				return
		}
	}

	Run('"' . FullFileName . '"')
}

ProcessRegExReplaceText_X(IdOrLabel := "") {
	global FolderSlotSearchById, ProcessSlotInputHook

	MaxSlots := IniRead(IniSettingsFilePath, "GeneralSettings", "RegExReplaceText_X-MaxReplaceTextSlots", "20")
	MaxSlots := (MaxSlots == "ERROR" || !IsInteger(MaxSlots)) ? 20 : Integer(MaxSlots)

	ReplaceTextSlot := ""

	if (IdOrLabel != "") {
		ReplaceTextSlot := Trim(IdOrLabel)
		FolderSlotSearchById := IsInteger(ReplaceTextSlot)
	} else {
		ToolTip("Type ReplaceTextSlot ID or label: ")
		FolderSlotSearchById := false

		ProcessSlotInputHook := InputHook("L30T20", "{Enter}{Tab}")
		ProcessSlotInputHook.OnChar := ProcessSlotInputHook_Char
		ProcessSlotInputHook.OnKeyDown := ProcessSlotInputHook_KeyDown
		ProcessSlotInputHook.OnEnd := ProcessSlotInputHook_End
		ProcessSlotInputHook.KeyOpt("{Backspace}{space}{tab}", "N")
		ProcessSlotInputHook.KeyOpt("{Esc}", "NS")
		ProcessSlotInputHook.Start()

		EndReason := ProcessSlotInputHook.Wait()

		if (EndReason = "Stopped")
			return

		ToolTip()
		ReplaceTextSlot := ProcessSlotInputHook.Input
	}

	ReplaceTextSlot := Trim(ReplaceTextSlot)
	if (ReplaceTextSlot = "")
		return

	if (ReplaceTextSlot = "e") {
		ReplaceTextSlotsDescription := "=== Currently set ReplaceText Slots === `n`n"
		SlotCounter := 0

		Loop MaxSlots {
			SlotIdx := (A_Index == MaxSlots) ? 0 : A_Index
			TxtLabel := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextLabel_" . SlotIdx, "")
			TxtName  := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextName_" . SlotIdx, "ERROR")
			TxtDesc  := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextDescription_" . SlotIdx, "")
			TxtOp    := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextOperation_" . SlotIdx, "")

			if (TxtName != "ERROR") {
				SlotCounter++
				ReplaceTextSlotsDescription .= " - Slot: [" . SlotIdx . "] -- Label: [" . TxtLabel . "]`n    Name: " . TxtName . " -- Description: " . TxtDesc . "`n"
			}
		}

		ReplaceTextSlotsDescription .= "`nTotal slots: (" . SlotCounter . ")"

		if (SlotCounter < 20) {
			MsgBox(ReplaceTextSlotsDescription, WinEnvName . "List of set up folder slots", 32)
		} else {
			A_Clipboard := ReplaceTextSlotsDescription
			MsgBox("List of set up ReplaceText slots is too long, full list was copied to clipboard", WinEnvName, 32)
		}
		return
	}

	ValidateAndRunTextReplace(TxtName, TxtDesc, RegExStr, ReplaceStr, TxtOp) {
		if (TxtName == "ERROR") {
			MsgBox('SLOT ReplaceTextName is empty, set it on the "' . IniSettingsFileName . '" file under `n[RegExReplaceText_X] --> ReplaceTextName_xx')
			return
		}

		if (TxtDesc == "ERROR")
			TxtDesc := "Not defined"

		if (RegExStr == "") {
			MsgBox('SLOT ReplaceTextRegExString is empty, set it on the "' . IniSettingsFileName . '" file')
			return
		}

		if (TxtOp == "")
			TxtOp := "Copy_to_clipboard"

		RunRegExReplaceText(TxtName, TxtDesc, RegExStr, ReplaceStr, TxtOp)
	}

	if (FolderSlotSearchById) {
		TxtName    := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextName_" . ReplaceTextSlot, "ERROR")
		TxtDesc    := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextDescription_" . ReplaceTextSlot, "")
		RegExStr   := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextRegExString_" . ReplaceTextSlot, "")
		ReplaceStr := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextReplaceString_" . ReplaceTextSlot, "")
		TxtOp      := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextOperation_" . ReplaceTextSlot, "")

		ValidateAndRunTextReplace(TxtName, TxtDesc, RegExStr, ReplaceStr, TxtOp)
	} else {
		Found := false
		Loop MaxSlots {
			SlotIdx := (A_Index == MaxSlots) ? 0 : A_Index
			TxtLabel := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextLabel_" . SlotIdx, "")

			if (TxtLabel = ReplaceTextSlot) {
				TxtName    := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextName_" . SlotIdx, "ERROR")
				TxtDesc    := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextDescription_" . SlotIdx, "")
				RegExStr   := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextRegExString_" . SlotIdx, "")
				ReplaceStr := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextReplaceString_" . SlotIdx, "")
				TxtOp      := IniRead(IniSettingsFilePath, "RegExReplaceText_X", "ReplaceTextOperation_" . SlotIdx, "")

				Found := true
				ValidateAndRunTextReplace(TxtName, TxtDesc, RegExStr, ReplaceStr, TxtOp)
				break
			}
		}

		if (!Found) {
			MsgBox("ReplaceText slot not found, please check spelling or enter 'e' to show list of all ReplaceText slots.", WinEnvName . "Not found", 48)
		}
	}
}

RunRegExReplaceText(ReplaceTextName, ReplaceTextDescription, RegExString, ReplaceString, ReplaceTextOperation) {
	IB := InputBox("Description: " . ReplaceTextDescription, WinEnvName . "Enter text for " . ReplaceTextName . " text replace:")
	if (IB.Result != "OK")
		return

	BaseText := IB.Value
	ReplaceString := ReplacePlaceholderStrings(ReplaceString)

	try {
		ReplacedText := RegExReplace(BaseText, RegExString, ReplaceString)
	} catch as err {
		MsgBox("Regex error: " . err.Message)
		return
	}

	if (ReplaceTextOperation == "Copy_to_clipboard") {
		A_Clipboard := ReplacedText
	} else if (ReplaceTextOperation == "Simulate_Typing") {
		SendText(ReplacedText)
	}
}