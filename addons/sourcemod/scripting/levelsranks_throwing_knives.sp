#pragma semicolon 1
#include <throwing_knives_core>

#pragma newdecls required
#include <sourcemod>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iTKCount,
		g_iTKLevel[64],
		g_iTKnivesCount[64];

public Plugin myinfo = {name = "[LR] Module - Throwing Knives", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO, Engine_CSS: LogMessage("[%s Throwing Knives] Запущен успешно", PLUGIN_NAME);
		default: SetFailState("[%s Throwing Knives] Плагин работает только на CS:GO и CS:S", PLUGIN_NAME);
	}
}

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
}

public void OnMapStart() 
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/throwing_knives.ini");
	KeyValues hLR_TK = new KeyValues("LR_Throwing_Knives");

	if(!hLR_TK.ImportFromFile(sPath) || !hLR_TK.GotoFirstSubKey())
	{
		SetFailState("[%s Throwing Knives] : фатальная ошибка - файл не найден (%s)", PLUGIN_NAME, sPath);
	}

	hLR_TK.Rewind();

	if(hLR_TK.JumpToKey("Settings"))
	{
		g_iTKCount = 0;
		hLR_TK.GotoFirstSubKey();

		do
		{
			g_iTKnivesCount[g_iTKCount] = hLR_TK.GetNum("count", 1);
			g_iTKLevel[g_iTKCount] = hLR_TK.GetNum("level", 0);
			g_iTKCount++;
		}
		while(hLR_TK.GotoNextKey());
	}
	else SetFailState("[%s Throwing Knives] : фатальная ошибка - секция Settings не найдена", PLUGIN_NAME);
	delete hLR_TK;
}

public void PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{	
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(iClient))
	{
		int iRank = LR_GetClientRank(iClient);
		TKC_SetClientKnives(iClient, 0);

		for(int i = g_iTKCount - 1; i >= 0; i--)
		{
			if(iRank >= g_iTKLevel[i])
			{
				TKC_SetClientKnives(iClient, g_iTKnivesCount[i]);
				break;
			}
		}
	}
}