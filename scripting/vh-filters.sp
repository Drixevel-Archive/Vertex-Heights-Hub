/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[Vertex Heights] :: Filters"
#define PLUGIN_AUTHOR "Drixevel"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "https://vertexheights.com/"

#define MAX_EXPRESSION_LENGTH 512
#define MATCH_SIZE 64

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-colors>

#include <vertexheights>

#include <sdktools>
#include <regex>

#undef REQUIRE_PLUGIN
#include <tf2>
#include <discord>
#define REQUIRE_PLUGIN

/*****************************/
//Globals

enum
{
	NAME = 0,
	CHAT,
	COMMAND,
	TRIGGER_COUNT
}

ArrayList g_aSections[TRIGGER_COUNT];

ConVar g_cvarStatus;
ConVar g_cvarConfigPath;
ConVar g_cvarCheckChat;
ConVar g_cvarCheckCommands;
ConVar g_cvarCheckNames;
ConVar g_cvarUnnamedPrefix;
ConVar g_cvarNameChannel;
ConVar g_cvarChatChannel;
ConVar g_cvarHostName;

Regex g_rRegexCaptures;
StringMap g_smClientLimits[TRIGGER_COUNT][MAXPLAYERS+1];

bool g_bLate;
bool g_bChanged[MAXPLAYERS+1];
bool g_bDiscord;

char g_sConfigPath[PLATFORM_MAX_PATH];
char g_sNameChannel[128];
char g_sChatChannel[128];
char g_sOldName[MAXPLAYERS+1][MAX_NAME_LENGTH];
char g_sUnfilteredName[MAXPLAYERS+1][MAX_NAME_LENGTH];
char g_sPrefix[MAX_NAME_LENGTH];
char g_sHostName[32];
char g_sRed[12] = "\x07FF4040";
char g_sBlue[12] = "\x0799CCFF";
char g_sLightGreen[12] = "\x0799FF99";

EngineVersion g_EngineVersion;

char g_sRandomNames[][] =
{
	"Steve",
	"John",
	"James",
	"Robert",
	"David",
	"Mike",
	"Daniel",
	"Kevin",
	"Ryan",
	"Gary",
	"Larry",
	"Frank",
	"Jerry",
	"Greg",
	"Doug",
	"Carl",
	"Gerald",
	"Goose",
	"Billy",
	"Bobby",
	"Brooke",
	"Bort"
};

enum struct Section
{
	char Name[128];
	ArrayList Regexes;
	StringMap Rules;

	void Initialize(const char[] name)
	{
		strcopy(this.Name, sizeof(Section::Name), name);
		this.Regexes = new ArrayList();
		this.Rules = new StringMap();
	}

	void Destroy()
	{
		delete this.Regexes;
		delete this.Rules;
	}
}

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("vh-filters");

	CreateNative("VH_FilterMessage", Native_FilterMessage);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvarStatus = CreateConVar("sm_regex_allow", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarConfigPath = CreateConVar("sm_regex_config_path", "configs/regextriggers/", "Location to store the regex filters at.", FCVAR_NONE);
	g_cvarCheckChat = CreateConVar("sm_regex_check_chat", "1", "Filter out and check chat messages.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarCheckCommands = CreateConVar("sm_regex_check_commands", "1", "Filter out and check commands.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarCheckNames = CreateConVar("sm_regex_check_names", "1", "Filter out and check names.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarUnnamedPrefix = CreateConVar("sm_regex_prefix", "", "Prefix for random name when player has become unnamed", FCVAR_NONE);
	g_cvarHostName = FindConVar("hostname");

	// Discord
	g_cvarNameChannel = CreateConVar("sm_regex_channelname", "", "Key name from discord.cfg for name relay", FCVAR_NONE);
	g_cvarChatChannel = CreateConVar("sm_regex_channelchat", "", "Key name from discord.cfg for chat relay", FCVAR_NONE);

	g_cvarUnnamedPrefix.AddChangeHook(cvarChanged_Prefix);
	g_cvarNameChannel.AddChangeHook(cvarChanged_NameChannel);
	g_cvarChatChannel.AddChangeHook(cvarChanged_ChatChannel);
	g_cvarHostName.AddChangeHook(cvarChanged_Hostname);

	g_cvarUnnamedPrefix.GetString(g_sPrefix, sizeof(g_sPrefix));
	g_cvarNameChannel.GetString(g_sNameChannel, sizeof(g_sNameChannel));
	g_cvarChatChannel.GetString(g_sChatChannel, sizeof(g_sChatChannel));
	g_cvarConfigPath.GetString(g_sConfigPath, sizeof(g_sConfigPath));

	BuildPath(Path_SM, g_sConfigPath, sizeof(g_sConfigPath), g_sConfigPath);
	Format(g_sConfigPath, sizeof(g_sConfigPath), "%sregextriggers.cfg", g_sConfigPath);

	if (!FileExists(g_sConfigPath)) {
		SetFailState("Error finding file: %s", g_sConfigPath);
	}

	HookUserMessage(GetUserMessageId("SayText2"), hookUserMessage, true);
	HookEvent("player_connect_client", eventPlayerConnect, EventHookMode_Pre);
	HookEvent("player_connect", eventPlayerConnect, EventHookMode_Pre);
	HookEvent("player_changename", eventOnChangeName, EventHookMode_Pre);

	LoadTranslations("common.phrases");

	for (int i = 0; i < TRIGGER_COUNT; i++) {
		g_aSections[i] = new ArrayList(sizeof(Section));

		for (int j = 1; j <= MaxClients; j++) {
			g_smClientLimits[i][j] = new StringMap();
		}
	}

	g_rRegexCaptures = new Regex("\\\\\\d+");

	// 5 second delay to ease OnPluginStart workload
	CreateTimer(5.0, timerLoadExpressions);

	g_EngineVersion = GetEngineVersion();

	if (g_EngineVersion == Engine_CSGO) {
		strcopy(g_sRed, sizeof(g_sRed), " \x02");
		strcopy(g_sLightGreen, sizeof(g_sLightGreen), " \x04");
	}

	if (g_bLate) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsValidClient(i)) {
				Format(g_sOldName[i], sizeof(g_sOldName[]), "%N", i);
				Format(g_sUnfilteredName[i], sizeof(g_sUnfilteredName[]), "%N", i);
			}
		}
	}
}

public void OnAllPluginsLoaded() {
	if ((g_bDiscord = LibraryExists("discord"))) {
		char hostname[64];
		g_cvarHostName.GetString(hostname, sizeof(hostname));
		strcopy(g_sHostName, sizeof(g_sHostName), hostname);
	}
}

public void OnMapEnd() {
	for (int i = 1; i <= MaxClients; i++) {
		ClearData(i);
	}
}

public void OnClientAuthorized(int client, const char[] auth) {
	if (!g_cvarStatus.BoolValue) {
		return;
	}

	ClearData(client);
	ConnectNameCheck(client);	
}

public void OnClientDisconnect(int client) {
	ClearData(client);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] args) {
	if (!g_cvarStatus.BoolValue || !g_cvarCheckChat.BoolValue || IsChatTrigger()) {
		return Plugin_Continue;
	}
	
	if (strlen(args) == 0 || client == 0) {
		return Plugin_Continue;
	}

	return CheckClientMessage(client, command, args);
}

public Action OnClientCommand(int client, int argc) {
	if (!g_cvarStatus.BoolValue || !g_cvarCheckCommands.BoolValue || client == 0) {
		return Plugin_Continue;
	}
	
	char command[256];
	GetCmdArgString(command, sizeof(command));
	
	if (strlen(command) == 0 || StrContains(command, "say") == 0) {
		return Plugin_Continue;
	}

	char args[256];
	GetCmdArgString(args, sizeof(args));

	return CheckClientCommand(client, command);
}

// =================== ConVar Hook

void cvarChanged_Prefix(ConVar convar, const char[] oldValue, const char[] newValue) {
	strcopy(g_sPrefix, sizeof(g_sPrefix), newValue);
}

void cvarChanged_NameChannel(ConVar convar, const char[] oldValue, const char[] newValue) {
	strcopy(g_sNameChannel, sizeof(g_sNameChannel), newValue);
}

void cvarChanged_ChatChannel(ConVar convar, const char[] oldValue, const char[] newValue) {
	strcopy(g_sChatChannel, sizeof(g_sChatChannel), newValue);
}

void cvarChanged_Hostname(ConVar convar, const char[] oldValue, const char[] newValue) {
		strcopy(g_sHostName, sizeof(g_sHostName), newValue);
}

// =================== Hooks

public Action eventPlayerConnect(Event event, const char[] name, bool dontBroadcast) {
	event.BroadcastDisabled = true;
	return Plugin_Continue;
}

public Action hookUserMessage(UserMsg msg_hd, BfRead bf, const int[] players, int playersNum, bool reliable, bool init) {
	char sMessage[96];
	bf.ReadString(sMessage, sizeof(sMessage));
	bf.ReadString(sMessage, sizeof(sMessage));

	return (StrContains(sMessage, "Name_Change") != -1) ? Plugin_Handled : Plugin_Continue;
}

public Action eventOnChangeName(Event event, const char[] name, bool dontBroadcast) {
	/* This event hook is a bit hacky because it's called each time the name is changed,
	 * including the name changes triggered by the plugin. Because of this, it can cause
	 * loops to occur. Some of the checks that occur here are to prevent that from happening.
	 * If the player name matches a filter, g_bChanged will be true and CheckClientName will
	 * set the players name, retriggering this hook. CheckClientName will be called again,
	 * however, the second time, it will only announce the name change to the server. */

	if (!g_cvarStatus.BoolValue || !g_cvarCheckNames.BoolValue) {
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	char currentName[MAX_NAME_LENGTH];
	event.GetString("oldname", currentName, sizeof(currentName));

	char newName[MAX_NAME_LENGTH];
	event.GetString("newname", newName, sizeof(newName));

	// If stored old name or current name equal to new name, don't do anything.
	if (StrEqual(g_sOldName[client], newName) || StrEqual(currentName, newName)) {
		g_bChanged[client] = false;
		return Plugin_Continue;
	}

	// If name is unchanged, store it so we can use it for discord relay.
	if (!g_bChanged[client]) {
		strcopy(g_sUnfilteredName[client], sizeof(g_sUnfilteredName[]), newName);
	}

	CheckClientName(client, newName, sizeof(newName));
	// Dont think this is needed.
	event.SetString("newname", newName);

	return Plugin_Continue;
}

// =================== Timers

Action timerLoadExpressions(Handle timer) {
	LoadRegexConfig(g_sConfigPath);
}

Action timerForgive(Handle timer, DataPack dp) {
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());

	if (!client) {
		delete dp;
		return;
	}

	int index = dp.ReadCell();

	char sectionName[128];
	dp.ReadString(sectionName, sizeof(sectionName));

	delete dp;

	int count;
	if (g_smClientLimits[index][client].GetValue(sectionName, count) && count > 0) {
		g_smClientLimits[index][client].SetValue(sectionName, --count);
	}
}

// =================== Config Loading

void LoadRegexConfig(const char[] config) {
	if (!FileExists(config)) {
		ThrowError("Error finding file: %s", config);
	}
	
	KeyValues kv = new KeyValues("RegexFilters");
	kv.ImportFromFile(config);

	if (!kv.GotoFirstSubKey()) {
		ThrowError("Error reading config at %s. No first sub key.", config);
	}

	do {
		char sectionName[128];
		kv.GetSectionName(sectionName, sizeof(sectionName));

		Section section[TRIGGER_COUNT];
		section[NAME].Initialize(sectionName);
		section[CHAT].Initialize(sectionName);
		section[COMMAND].Initialize(sectionName);

		if (!kv.GotoFirstSubKey(false)) {
			LogError("Config section %s has no keys", sectionName);
			continue;
		}

		char key[128];
		do {
			kv.GetSectionName(key, sizeof(key));

			char buffer[128];

			if (StrEqual(key, "namepattern")) {
				kv.GetString(NULL_STRING, buffer, sizeof(buffer));
				RegisterExpression(buffer, section[NAME]);
			}
			else if (StrEqual(key, "chatpattern")) {
				kv.GetString(NULL_STRING, buffer, sizeof(buffer));
				RegisterExpression(buffer, section[CHAT]);				
			}
			else if (StrEqual(key, "cmdpattern")) {
				kv.GetString(NULL_STRING, buffer, sizeof(buffer));
				RegisterExpression(buffer, section[COMMAND]);				
			}
			else if (StrEqual(key, "replace")) {
				ArrayList replacements;

				for (int i = 0; i < TRIGGER_COUNT; i++) {
					if (!section[i].Rules.GetValue("replace", replacements)) {
						replacements = new ArrayList(ByteCountToCells(sizeof(buffer)));
						section[i].Rules.SetValue("replace", replacements);
					}

					kv.GetString(NULL_STRING, buffer, sizeof(buffer));
					replacements.PushString(buffer);
				}
			}
			else if (StrEqual(key, "block") || StrEqual(key, "limit") || StrEqual(key, "relay")) {
				UpdateRuleValue(section, key, kv.GetNum(NULL_STRING));
			}
			else if (StrEqual(key, "forgive")) {
				UpdateRuleValue(section, key, kv.GetFloat(NULL_STRING));
			}
			else if (StrEqual(key, "action") || StrEqual(key, "warn") || StrEqual(key, "punish")) {
				kv.GetString(NULL_STRING, buffer, sizeof(buffer));
				UpdateRuleString(section, key, buffer);
			}
			else if (StrEqual(key, "immunity")) {
				kv.GetString(NULL_STRING, buffer, sizeof(buffer));
				UpdateRuleValue(section, key, ReadFlagString(buffer));
			}

		} while (kv.GotoNextKey(false));

		// for each section type ...
		for (int i = 0; i < TRIGGER_COUNT; i++) {
			// if section has at least one regex and rule ...
			if (section[i].Regexes.Length && section[i].Rules.Size) {
				// push it to its respective arraylist ...
				g_aSections[i].PushArray(section[i], sizeof(section[]));
			}
			// otherwise ...
			else {
				// destroy the section Handles.
				section[i].Destroy();
			}
		}

		kv.GoBack();
	} while (kv.GotoNextKey());

	delete kv;
}

void UpdateRuleValue(Section section[TRIGGER_COUNT], const char[] key, any value) {
	for (int i = 0; i < TRIGGER_COUNT; i++) {
		section[i].Rules.SetValue(key, value);
	}
}

void UpdateRuleString(Section section[TRIGGER_COUNT], const char[] key, const char[] value) {
	for (int i = 0; i < TRIGGER_COUNT; i++) {
		section[i].Rules.SetString(key, value);
	}
}

void RegisterExpression(const char[] key, Section section) {
	char expression[MAX_EXPRESSION_LENGTH];
	int flags = ParseExpression(key, expression, sizeof(expression));

	if (flags == -1) {
		return;
	}

	char error[128];
	RegexError errorcode;
	Regex regex = new Regex(expression, flags, error, sizeof(error), errorcode);
	
	if (regex == null) {
		LogError("Error compiling expression '%s' with flags '%i': [%i] %s", expression, flags, errorcode, error);
		return;
	}

	section.Regexes.Push(regex);
}

int ParseExpression(const char[] key, char[] expression, int size) {
	strcopy(expression, size, key);
	TrimString(expression);
	
	int flags;
	int a;
	int b;
	int c;
	
	if (expression[strlen(expression) - 1] == '\'') {
		for (; expression[flags] != '\0'; flags++) {
			if (expression[flags] == '\'') {
				a++;
				b = c;
				c = flags;
			}
		}
		
		if (a < 2) {
			LogError("Regex Filter line malformed: %s", key);
			return -1;
		}
		else {
			expression[b] = '\0';
			expression[c] = '\0';
			flags = FindRegexFlags(expression[b + 1]);
			
			TrimString(expression);
			
			if (a > 2 && expression[0] == '\'') {
				strcopy(expression, strlen(expression) - 1, expression[1]);
			}
		}
	}
	
	return flags;
}

int FindRegexFlags(const char[] flags) {
	char sBuffer[7][16];
	ExplodeString(flags, "|", sBuffer, 7, 16);
	
	int new_flags;
	for (int i = 0; i < 7; i++) {
		if (sBuffer[i][0] == '\0') {
			continue;
		}
		if (StrEqual(sBuffer[i], "CASELESS")) {
			new_flags |= PCRE_CASELESS;
		}
		else if (StrEqual(sBuffer[i], "MULTILINE")) {
			new_flags |= PCRE_MULTILINE;
		}
		else if (StrEqual(sBuffer[i], "DOTALL")) {
			new_flags |= PCRE_DOTALL;
		}
		else if (StrEqual(sBuffer[i], "EXTENDED")) {
			new_flags |= PCRE_EXTENDED;
		}
		else if (StrEqual(sBuffer[i], "UNGREEDY")) {
			new_flags |= PCRE_UNGREEDY;
		}
		else if (StrEqual(sBuffer[i], "UTF8")) {
			new_flags |= PCRE_UTF8;
		}
		else if (StrEqual(sBuffer[i], "NO_UTF8_CHECK")) {
			new_flags |= PCRE_NO_UTF8_CHECK;
		}
	}
	
	return new_flags;
}

// =================== Internal Functions

void ClearData(int client) {
	g_bChanged[client] = false;
	g_sOldName[client][0] = '\0';
	g_sUnfilteredName[client][0] = '\0';

	for (int i = 0; i < TRIGGER_COUNT; i++) {
		g_smClientLimits[i][client].Clear();
	}
}

void ParseAndExecute(int client, char[] command, int size) {
	char buffer[32];
	FormatEx(buffer, sizeof(buffer), "%i", GetClientUserId(client));
	ReplaceString(command, size, "%u", buffer);

	FormatEx(buffer, sizeof(buffer), "%i", client);
	ReplaceString(command, size, "%i", buffer);

	FormatEx(buffer, sizeof(buffer), "%N", client);
	ReplaceString(command, size, "%n", buffer);

	ServerCommand(command);
}

bool LimitClient(int client, int type, const char[] sectionName, int limit, StringMap rules) {
	if (type >= TRIGGER_COUNT) {
		LogError("Invalid type %i. Expected in range of (0, %i)", type, TRIGGER_COUNT-1);
		return false;
	}

	char buffer[128];
	int clientLimitCount;
	g_smClientLimits[type][client].GetValue(sectionName, clientLimitCount);
	g_smClientLimits[type][client].SetValue(sectionName, ++clientLimitCount);

	CPrintToChat(
		  client
		, "\x01[%sFilter\x01] Max limit for this trigger is set to %s%i\x01. Current: %s%i."
		, g_sRed
		, g_sLightGreen
		, limit
		, g_sLightGreen
		, clientLimitCount
	);

	float forgive;
	if (rules.GetValue("forgive", forgive)) {
		DataPack dp = new DataPack();
		dp.WriteCell(GetClientUserId(client));
		dp.WriteCell(type);
		dp.WriteString(sectionName);
		CreateTimer(forgive, timerForgive, dp);

		CPrintToChat(client, "\x01[%sFilter\x01] Forgiven in %s%0.1f\x01 seconds", g_sRed, g_sLightGreen, forgive);
	}

	if (clientLimitCount >= limit && rules.GetString("punish", buffer, sizeof(buffer))) {
		CPrintToChat(client, "\x01[%sFilter\x01] You have hit the limit of %s%i", g_sRed, g_sLightGreen, limit);

		ParseAndExecute(client, buffer, sizeof(buffer));

		if (!IsClientConnected(client)) {
			return false;
		}
	}

	return true;
}

void ReplaceText(Regex regex, int matchCount, ArrayList replaceList, char[] text, int size) {
	int captureCount = regex.CaptureCount();
	char[][][] matches = new char[matchCount][captureCount][MATCH_SIZE];

	char buffer[MATCH_SIZE];
	char buffer2[8];
	// for each match
	for (int j = 0; j < matchCount; j++) {
		// Get random replacement text
		char replacement[128];
		replaceList.GetString(GetRandomInt(0, replaceList.Length-1), replacement, sizeof(replacement));

		for (int k = 0; k < captureCount; k++) {
			// Store all captures in dynamic char array, where 0 is the entire match
			regex.GetSubString(k, matches[j][k], MATCH_SIZE, j);
		}

		// check if there are capture group characters in replacement text (eg:\0, \1, \2)
		int charcount = g_rRegexCaptures.MatchAll(replacement);
		// if there are ...
		if (charcount > 0) {
			// make a loop for each character
			for (int k = 0; k < charcount; k++) {
				// extract it from substring and store in buffer
				g_rRegexCaptures.GetSubString(0, buffer, sizeof(buffer), k);

				// copy buffer integer to buffer2
				strcopy(buffer2, sizeof(buffer2), buffer[1]);

				// convert to index
				int index = StringToInt(buffer2);

				if (index >= captureCount || index < 1) {
					continue;
				}

				ReplaceString(replacement, sizeof(replacement), buffer, matches[j][index]);
			}
		}

		ReplaceString(text, size, matches[j][0], replacement);
	}
}

void AnnounceNameChange(int client, char[] newName, bool connecting = false) {
	if (connecting) {
		CPrintToChatAll("%s connected", newName);
	}
	else if (!StrEqual(g_sOldName[client], newName)) {

		char color[10];
		if (g_EngineVersion == Engine_TF2) {
			switch (GetClientTeam(client)) {
				case TFTeam_Red: {
					strcopy(color, sizeof(color), g_sRed);
				}
				case TFTeam_Blue: {
					strcopy(color, sizeof(color), g_sBlue);
				}
			}	
		}

		CPrintToChatAll("\x01* %s%s\x01 changed name to %s%s", color, g_sOldName[client], color, newName);
	}

	g_bChanged[client] = false;
	strcopy(g_sOldName[client], MAX_NAME_LENGTH, newName);
}

void ConnectNameCheck(int client) {
	if (IsFakeClient(client) || !g_cvarCheckNames.BoolValue) {
		return;
	}

	char clientName[MAX_NAME_LENGTH];
	Format(clientName, sizeof(clientName), "%N", client);
	Format(g_sUnfilteredName[client], sizeof(g_sUnfilteredName[]), "%N", client);

	CheckClientName(client, clientName, sizeof(clientName), true);
}

void CheckClientName(int client, char[] newName, int size, bool connecting = false) {
	if (!(0 < client <= MaxClients) || IsFakeClient(client)) {
		return;
	}

	// If name has already been checked, try to announce
	if (g_bChanged[client]) {
		AnnounceNameChange(client, newName, connecting);
		return;
	}

	ArrayList nameSections = g_aSections[NAME];

	int begin;
	int end = nameSections.Length;

	Section nameSection;

	char sectionName[128];
	ArrayList regexList;
	StringMap rules;

	Regex regex;
	RegexError errorcode;

	int matchCount;
	int immunityFlag;
	char buffer[256];
	int limit;
	bool relay;
	ArrayList replaceList;
	bool replaced;

	while (begin != end) {
		nameSections.GetArray(begin, nameSection, sizeof(Section));
		
		rules = nameSection.Rules;

		if (rules.GetValue("immunity", immunityFlag) && CheckCommandAccess(client, "", immunityFlag, true)) {
			begin++;
			continue;
		}

		strcopy(sectionName, sizeof(sectionName), nameSection.Name);

		regexList = nameSection.Regexes;
		int len = regexList.Length;
		for (int i = 0; i < len; i++) {
			regex = regexList.Get(i);

			matchCount = regex.MatchAll(newName, errorcode);
			if (matchCount < 1 || errorcode != REGEX_ERROR_NONE) {
				continue;
			}

			if (rules.GetString("warn", buffer, sizeof(buffer))) {
				CPrintToChat(client, "\x01[%sFilter\x01] %s%s", g_sRed, g_sLightGreen, buffer);
			}

			if (rules.GetString("action", buffer, sizeof(buffer))) {
				ParseAndExecute(client, buffer, sizeof(buffer));
			}

			if (rules.GetValue("limit", limit)) {
				bool result = LimitClient(client, NAME, sectionName, limit, rules);

				if (!result) {
					return;
				}
			}

			rules.GetValue("relay", relay);

			if (rules.GetValue("replace", replaceList)) {
				g_bChanged[client] = true;
				replaced = true;

				ReplaceText(regex, matchCount, replaceList, newName, size);
			}

			if (newName[0] == '\0') {
				break;
			}

			if (replaced) {
				begin = -1;
				replaced = false;
				break;
			}
		}

		if (newName[0] == '\0') {
			break;
		}

		begin++;
	}

	if (g_bChanged[client]) {
		if (StrEqual(g_sOldName[client], newName)) {
			g_bChanged[client] = false;
		}

		if (newName[0] == '\0') {
			int randomnum = GetRandomInt(0, sizeof(g_sRandomNames)-1);
			FormatEx(newName, MAX_NAME_LENGTH, "%s%s", g_sPrefix, g_sRandomNames[randomnum]);
		}

		if (relay && g_bDiscord) {
			Discord_EscapeString(g_sUnfilteredName[client], sizeof(g_sUnfilteredName[]));
			Discord_EscapeString(newName, MAX_NAME_LENGTH);
			char output[192];
			Format(output, sizeof(output), "**%s** `%s`  -->  `%s`", g_sHostName, g_sUnfilteredName[client], newName);
			Discord_SendMessage(g_sNameChannel, output);
		}

		SetClientName(client, newName);

		// If client is not in game, SetClientName does not retrigger name change event.
		// so it is safe to go ahead and announce the name change.
		if (connecting && !IsClientInGame(client)) {
			AnnounceNameChange(client, newName, connecting);
			return;
		}
	}
	else if (relay && g_bDiscord) {
		Discord_EscapeString(g_sUnfilteredName[client], sizeof(g_sUnfilteredName[]));
		Discord_EscapeString(newName, MAX_NAME_LENGTH);
		char output[192];
		Format(output, sizeof(output), "**%s** `%s`  -->  `%s`", g_sHostName, g_sUnfilteredName[client], newName);
		Discord_SendMessage(g_sNameChannel, output);
	}

	AnnounceNameChange(client, newName, connecting);
}

public int Native_FilterMessage(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] command = new char[size];
	GetNativeString(2, command, size);

	GetNativeStringLength(3, size); size++;
	
	char[] text = new char[size];
	GetNativeString(3, text, size);

	return view_as<any>(CheckClientMessage(client, command, text));
}

Action CheckClientMessage(int client, const char[] command, const char[] text) {
	char message[128];
	strcopy(message, sizeof(message), text);

	ArrayList chatSections = g_aSections[CHAT];

	int begin;
	int end = chatSections.Length;

	Section chatSection;

	StringMap rules;
	int immunityFlag;

	char sectionName[128];
	ArrayList regexList;

	int matchCount;

	Regex regex;
	RegexError errorcode;
	
	char buffer[256];
	int limit;
	int relay;
	bool block;
	ArrayList replaceList;
	bool replaced;
	bool changed;

	while (begin != end) {
		chatSections.GetArray(begin, chatSection, sizeof(chatSection));

		rules = chatSection.Rules;

		if (rules.GetValue("immunity", immunityFlag) && CheckCommandAccess(client, "", immunityFlag, true)) {
			begin++;
			continue;
		}

		strcopy(sectionName, sizeof(sectionName), chatSection.Name);

		regexList = chatSection.Regexes;

		for (int i = 0; i < regexList.Length; i++) {
			regex = regexList.Get(i);

			matchCount = regex.MatchAll(message, errorcode);
			if (matchCount < 1 || errorcode != REGEX_ERROR_NONE) {
				continue;
			}

			if (rules.GetString("warn", buffer, sizeof(buffer))) {
				CPrintToChat(client, "\x01[%sFilter\x01] %s%s", g_sRed, g_sLightGreen, buffer);
			}

			if (rules.GetString("action", buffer, sizeof(buffer))) {
				ParseAndExecute(client, buffer, sizeof(buffer));
			}

			if (rules.GetValue("limit", limit)) {
				bool result = LimitClient(client, CHAT, sectionName, limit, rules);

				if (!result) {
					return Plugin_Handled;
				}
			}

			rules.GetValue("relay", relay);

			if (rules.GetValue("block", block) && block) {
				if (relay && g_bDiscord) {
					char clientName[MAX_NAME_LENGTH];
					GetClientName(client, clientName, sizeof(clientName));

					Discord_EscapeString(clientName, sizeof(clientName));
					Discord_EscapeString(message, sizeof(message));

					char output[256];
					if (changed) {
						Format(output, sizeof(output), "**%s** %s: `%s` --> `%s` **Blocked**", g_sHostName, clientName, text, message);
					}
					else {
						Format(output, sizeof(output), "**%s** %s: `%s`", g_sHostName, clientName, message);
					}

					Discord_SendMessage(g_sChatChannel, output);
				}

				return Plugin_Handled;
			}

			if (rules.GetValue("replace", replaceList)) {
				replaced = true;
				changed = true;

				ReplaceText(regex, matchCount, replaceList, message, sizeof(message));
			}

			if (message[0] == '\0') {
				return Plugin_Handled;
			}

			if (replaced) {
				begin = -1;
				replaced = false;
				break;
			}
		}

		++begin;
	}

	if (changed) {
		if (relay && g_bDiscord) {
			char originalmessage[256];
			strcopy(originalmessage, sizeof(originalmessage), text);
			
			char clientName[MAX_NAME_LENGTH];
			Format(clientName, sizeof(clientName), "%N", client);

			Discord_EscapeString(clientName, sizeof(clientName));
			Discord_EscapeString(originalmessage, sizeof(originalmessage));
			Discord_EscapeString(message, sizeof(message));

			char output[256];
			Format(output, sizeof(output), "**%s** %s: `%s`  -->  `%s`", g_sHostName, clientName, originalmessage, message);

			Discord_SendMessage(g_sChatChannel, output);
		}

		FakeClientCommand(client, "%s %s", command, message);
		return Plugin_Handled;
	}

	if (relay && g_bDiscord) {
		char clientName[MAX_NAME_LENGTH];
		Format(clientName, sizeof(clientName), "%N", client);

		Discord_EscapeString(clientName, sizeof(clientName));
		Discord_EscapeString(message, sizeof(message));

		char output[256];
		Format(output, sizeof(output), "**%s** %s: `%s`", g_sHostName, clientName, message);

		Discord_SendMessage(g_sChatChannel, output);
	}

	return Plugin_Continue;
}

Action CheckClientCommand(int client, char[] cmd) {
	char command[128];
	strcopy(command, sizeof(command), cmd);

	ArrayList commandSections = g_aSections[COMMAND];

	int begin;
	int end = commandSections.Length;

	Section commandSection;

	StringMap rules;
	int immunityFlag;

	char sectionName[128];
	ArrayList regexList;

	Regex regex;
	RegexError errorcode;

	int matchCount;
	char buffer[128];
	int limit;
	bool relay;
	bool block;
	ArrayList replaceList;
	bool replaced;
	bool changed;

	while (begin != end) {
		commandSections.GetArray(begin, commandSection, sizeof(commandSection));

		rules = commandSection.Rules;

		if (rules.GetValue("immunity", immunityFlag) && CheckCommandAccess(client, "", immunityFlag, true)) {
			begin++;
			continue;
		}

		strcopy(sectionName, sizeof(sectionName), commandSection.Name);

		regexList = commandSection.Regexes;

		for (int i = 0; i < regexList.Length; i++) {
			regex = regexList.Get(i);

			matchCount = regex.MatchAll(command, errorcode);
			if (matchCount <= 0 || errorcode != REGEX_ERROR_NONE) {
				begin++;
				continue;
			}

			if (rules.GetString("warn", buffer, sizeof(buffer))) {
				CPrintToChat(client, "\x01[%sFilter\x01] %s%s", g_sRed, g_sLightGreen, buffer);
			}

			if (rules.GetString("action", buffer, sizeof(buffer))) {
				ParseAndExecute(client, buffer, sizeof(buffer));
			}

			if (rules.GetValue("limit", limit)) {
				bool result = LimitClient(client, COMMAND, sectionName, limit, rules);

				if (!result) {
					return Plugin_Handled;
				}
			}

			rules.GetValue("relay", relay);

			if (rules.GetValue("block", block) && block) {
				if (relay && g_bDiscord) {
					char clientName[MAX_NAME_LENGTH];
					GetClientName(client, clientName, sizeof(clientName));

					Discord_EscapeString(clientName, sizeof(clientName));
					Discord_EscapeString(command, sizeof(command));

					char output[256];
					if (changed) {
						Format(output, sizeof(output), "**%s** Command| %s: `%s` --> `%s` **Blocked**", g_sHostName, clientName, cmd, command);
					}
					else {
						Format(output, sizeof(output), "**%s** Command| %s: `%s`", g_sHostName, clientName, command);
					}

					Discord_SendMessage(g_sChatChannel, output);
				}

				return Plugin_Handled;			
			}

			if (rules.GetValue("replace", replaceList)) {
				i = -1;
				replaced = true;
				changed = true;

				ReplaceText(regex, matchCount, replaceList, command, sizeof(command));
			}

			if (command[0] == '\0') {
				return Plugin_Handled;
			}

			if (replaced) {
				begin = -1;
				replaced = false;
				break;
			}
		}

		begin++;
	}

	if (changed) {
		if (relay && g_bDiscord) {
			char originalCommand[256];
			strcopy(originalCommand, sizeof(originalCommand), cmd);
			
			char clientName[MAX_NAME_LENGTH];
			Format(clientName, sizeof(clientName), "%N", client);

			Discord_EscapeString(clientName, sizeof(clientName));
			Discord_EscapeString(originalCommand, sizeof(originalCommand));
			Discord_EscapeString(command, sizeof(command));

			char output[256];
			Format(output, sizeof(output), "**%s** Command| %s: `%s`  -->  `%s`", g_sHostName, clientName, originalCommand, command);

			Discord_SendMessage(g_sChatChannel, output);
		}

		FakeClientCommand(client, "%s", command);
		return Plugin_Handled;
	}

	if (relay && g_bDiscord) {
		char clientName[MAX_NAME_LENGTH];
		Format(clientName, sizeof(clientName), "%N", client);

		Discord_EscapeString(clientName, sizeof(clientName));
		Discord_EscapeString(command, sizeof(command));

		char output[256];
		Format(output, sizeof(output), "**%s** Command| %s: `%s`", g_sHostName, clientName, command);

		Discord_SendMessage(g_sChatChannel, output);
	}

	return Plugin_Continue;
}

stock void Discord_EscapeString(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "@", "＠");
	ReplaceString(string, maxlen, "'", "＇");
	ReplaceString(string, maxlen, "\"", "＂");
}

stock void Discord_SendMessage(const char[] channel, const char[] message)
{
	if (strlen(channel) > 0 && strlen(message) > 0)
	{

	}
}