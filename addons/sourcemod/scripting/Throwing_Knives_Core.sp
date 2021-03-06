#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <throwing_knives_core>

public Plugin:myinfo = 
{
	name = "[CS:S / CS:GO] Throwing Knives Core",
	author = "R1KO (original by meng, Bacardi)",
	version = "1.1.1 beta"
};

#define GAME_UNDEFINED	0
#define GAME_CSS_34		1
#define GAME_CSS			2
#define GAME_CSGO			3

new Engine_Version = GAME_UNDEFINED;

#define DMG_HEADSHOT		(1 << 30)

new 		g_iPointHurt;
new 		g_iDmgType;
new			g_iTrailSprite;
new			g_iBloodDecal;
new Handle:	g_hThrownKnives;
new Handle:	g_hTimerDelay[MAXPLAYERS+1];
new bool:	g_bHeadshot[MAXPLAYERS+1];
new			g_iPlayerKniveCount[MAXPLAYERS+1];

new			g_iRoundUsed[MAXPLAYERS+1];

new 		g_Cvar_iCount;
new 		g_Cvar_iRoundLimit;
new bool:	g_Cvar_bSteal;
new Float:	g_Cvar_fVelocity;
new Float:	g_Cvar_fDamage;
new Float:	g_Cvar_fHSDamage;
new Float:	g_Cvar_fModelScale;
new Float:	g_Cvar_fGravity;
new Float:	g_Cvar_fElasticity;
new Float:	g_Cvar_fMaxLifeTime;
new bool:	g_Cvar_bTrails;

new bool:	g_Cvar_bFF;

new Handle:	g_hForward_OnKnifeThrow;
new Handle:	g_hForward_OnKnifesGiven;
new Handle:	g_hForward_OnKnifesTaken;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:sError[], err_max)
{
	g_hForward_OnKnifeThrow = CreateGlobalForward("TKC_OnKnifeThrow", ET_Hook, Param_Cell);
	g_hForward_OnKnifesGiven = CreateGlobalForward("TKC_OnKnifesGiven", ET_Hook, Param_Cell, Param_CellByRef, Param_Cell);
	g_hForward_OnKnifesTaken = CreateGlobalForward("TKC_OnKnifesTaken", ET_Hook, Param_Cell, Param_CellByRef, Param_Cell);

	CreateNative("TKC_GetClientKnives", Native_GetClientKnives);
	CreateNative("TKC_SetClientKnives", Native_SetClientKnives);
	CreateNative("TKC_GiveClientKnives", Native_GiveClientKnives);
	CreateNative("TKC_TakeClientKnives", Native_TakeClientKnives);
	CreateNative("TKC_IsEntityThrowingKnife", Native_IsEntityThrowingKnife);

	MarkNativeAsOptional("GuessSDKVersion"); 
	MarkNativeAsOptional("GetEngineVersion");

	RegPluginLibrary("throwing_knives_core");

	return APLRes_Success;
}

public OnPluginStart() 
{
	Engine_Version = GetCSGame();
	if (Engine_Version == GAME_UNDEFINED)
	{
		SetFailState("Game is not supported!");
	}

	decl Handle:hCvar;

	hCvar = FindConVar("mp_friendlyfire");
	HookConVarChange(hCvar, OnFFChange);
	g_Cvar_bFF = GetConVarBool(hCvar);

	hCvar = CreateConVar("tkc_count", "-1", "RU: Сколько ножей будет получать игрок при возрождении (0 - Не выдывать, -1 - Бесконечно).\n\
												EN: Amount of knives players spawn with (0 = Disable, -1 = Infinite).", _, true, -1.0);
	HookConVarChange(hCvar, OnCountChange);
	g_Cvar_iCount = GetConVarInt(hCvar);

	hCvar = CreateConVar("tkc_round_limit", "-1", "RU: Сколько ножей может бросить игрок за раунд (-1 - Не ограничено).\n\
												EN: How many can throw player a knife per round (-1 - No limit).", _, true, -1.0);
	HookConVarChange(hCvar, OnRoundLimitChange);
	g_Cvar_iRoundLimit = GetConVarInt(hCvar);

	hCvar = CreateConVar("tkc_steal", "1", "RU: Если включено атакующий получит ножи жертвы.\n\
												EN: If enabled, knife kills get the victims remaining knives.", _, true, 0.0, true, 1.0);
	HookConVarChange(hCvar, OnStealChange);
	g_Cvar_bSteal = GetConVarBool(hCvar);

	hCvar = CreateConVar("tkc_velocity", "2250", "RU: Скорость полёта ножа.\n\
												EN: Velocity (speed) adjustment.", _, true, 1.0);
	HookConVarChange(hCvar, OnVelocityChange);
	g_Cvar_fVelocity = GetConVarFloat(hCvar);

	hCvar = CreateConVar("tkc_damage", "57", "RU: Наносимый урон.\n\
												EN: Damage adjustment.", _, true, 1.0);
	HookConVarChange(hCvar, OnDamageChange);
	g_Cvar_fDamage = GetConVarFloat(hCvar);

	hCvar = CreateConVar("tkc_hsdamage", "127", "RU: Наносимый урон в голову.\n\
												EN: Headshot damage adjustment.", _, true, 0.0);
	HookConVarChange(hCvar, OnHSDamageChange);
	g_Cvar_fHSDamage = GetConVarFloat(hCvar);

	if (Engine_Version != GAME_CSS_34)
	{
		hCvar = CreateConVar("tkc_modelscale", "1.0", "RU: Значение размера ножа (1.0 - норма).\n\
												EN: Knife size scale (1.0 - normal).", _, true, 0.0);
		HookConVarChange(hCvar, OnModelScaleChange);
		g_Cvar_fModelScale = GetConVarFloat(hCvar);
	}

	hCvar = CreateConVar("tkc_gravity", "1.0", "RU: Значение силы тяжести ножа (1.0 - норма).\n\
												EN: Knife gravity scale (1.0 - normal).", _, true, 0.0);
	HookConVarChange(hCvar, OnGravityChange);
	g_Cvar_fGravity = GetConVarFloat(hCvar);

	hCvar = CreateConVar("tkc_elasticity", "0.2", "RU: Значение эластичности.\n\
												EN: Knife elasticity.", _, true, 0.0);
	HookConVarChange(hCvar, OnElasticityChange);
	g_Cvar_fElasticity = GetConVarFloat(hCvar);

	hCvar = CreateConVar("tkc_maxlifetime", "1.5", "RU: Максимальное время жизни ножа (1 - 30 сек).\n\
												EN: Knife max life time (1 - 30 sec).", _, true, 1.0, true, 30.0);
	HookConVarChange(hCvar, OnMaxLifeTimeChange);
	g_Cvar_fMaxLifeTime = GetConVarFloat(hCvar);

	hCvar = CreateConVar("tkc_trails", "1", "RU: Эффект траектории ножа.\n\
												EN: Knive leave trail effect", _, true, 0.0, true, 1.0);
	HookConVarChange(hCvar, OnTrailsChange);
	g_Cvar_bTrails = GetConVarBool(hCvar);

	AutoExecConfig(true, "ThrowingKnives_Core");

	g_hThrownKnives = CreateArray();

	HookEvent("player_spawn",	Event_PlayerSpawn);
	HookEvent("weapon_fire",	Event_WeaponFire);
	HookEvent("player_death",	Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	if (Engine_Version == GAME_CSGO)
	{
		g_iDmgType = DMG_SLASH|DMG_NEVERGIB;
	}
	else
	{
		g_iDmgType = DMG_BULLET|DMG_NEVERGIB;

		if (Engine_Version == GAME_CSS_34)
		{
			HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_PostNoCopy);
		}
	}
}

public OnFFChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])				g_Cvar_bFF = GetConVarBool(hCvar);
public OnCountChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])			g_Cvar_iCount = GetConVarInt(hCvar);
public OnRoundLimitChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])		g_Cvar_iRoundLimit = GetConVarInt(hCvar);
public OnStealChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])			g_Cvar_bSteal = GetConVarBool(hCvar);
public OnVelocityChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])		g_Cvar_fVelocity = GetConVarFloat(hCvar);
public OnDamageChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])			g_Cvar_fDamage = GetConVarFloat(hCvar);
public OnHSDamageChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])		g_Cvar_fHSDamage = GetConVarFloat(hCvar);
public OnModelScaleChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])		g_Cvar_fModelScale = GetConVarFloat(hCvar);
public OnGravityChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])			g_Cvar_fGravity = GetConVarFloat(hCvar);
public OnElasticityChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])		g_Cvar_fElasticity = GetConVarFloat(hCvar);
public OnMaxLifeTimeChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])	g_Cvar_fMaxLifeTime = GetConVarFloat(hCvar);
public OnTrailsChange(Handle:hCvar, const String:sOldValue[], const String:sNewValue[])			g_Cvar_bTrails = GetConVarBool(hCvar);

public OnMapStart()
{
	g_iTrailSprite = PrecacheModel(Engine_Version == GAME_CSGO ? "effects/blueblacklargebeam.vmt":"sprites/bluelaser1.vmt");
	/*
	if(Engine_Version == GAME_CSGO)
	{
		g_iTrailSprite = PrecacheModel("effects/blueblacklargebeam.vmt");
	}
	else
	{
		g_iTrailSprite = PrecacheModel("sprites/bluelaser1.vmt");
	}
	*/

	g_iBloodDecal = PrecacheDecal("sprites/blood.vmt");
}

public OnClientPutInServer(iClient)
{
	if(IsClientSourceTV(iClient) == false && IsClientReplay(iClient) == false)
	{
		SDKHookEx(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action:OnTakeDamage(iVictim, &iAttacker, &inflictor, &Float:damage, &damagetype)
{
	if(0 < inflictor <= MaxClients && inflictor == iAttacker && damagetype == g_iDmgType)
	{
		g_bHeadshot[iAttacker] = false;

		if(g_hTimerDelay[iAttacker] != INVALID_HANDLE)
		{
			KillTimer(g_hTimerDelay[iAttacker]);
			g_hTimerDelay[iAttacker] = INVALID_HANDLE;
		}
	}
}

public Event_RoundEnd(Handle:hEvent, const String:sEvName[], bool:bDontBroadcast)
{
	for(new i = 1; i <= MaxClients; ++i)
	{
		g_iPlayerKniveCount[i] = 0;
	}
}

public Event_PlayerSpawn(Handle:hEvent, const String:sEvName[], bool:bDontBroadcast)
{
	if(g_Cvar_iCount != 0)
	{
		new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

		if(g_Cvar_iCount == -1)
		{
			g_iPlayerKniveCount[iClient] = g_Cvar_iCount;
		}
		else
		{
			decl iCount, iDummy;
			iDummy = 
			iCount = g_Cvar_iCount;

			switch (Forward_OnKnifesGiven(iClient, iCount, KNIFES_BY_DEFAULT))
			{
				case Plugin_Continue:
				{
					iCount = iDummy;
				}
				case Plugin_Handled, Plugin_Stop:
				{
					return;
				}
			}

			g_iPlayerKniveCount[iClient] = iCount;
		}
		g_iRoundUsed[iClient] = 0;
	}
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:sEvName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(iClient && HasClientKnives(iClient))
	{
		decl String:sWeapon[20];
		GetEventString(hEvent, "weapon", sWeapon, sizeof(sWeapon));

		if(StrContains(sWeapon, "knife", false) != -1 || strcmp(sWeapon, "bayonet") == 0)
		{
			if(g_Cvar_bSteal && g_iPlayerKniveCount[iClient] != -1)
			{
				new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
				if(HasClientKnives(iVictim))
				{
					decl iDummy, iCount, Action:aResult;
					iCount = g_iPlayerKniveCount[iVictim];
					iDummy = iCount;

					aResult = Forward_OnKnifesTaken(iVictim, iCount, KNIFES_BY_STEAL);
					if(aResult > Plugin_Changed)
					{
						if(aResult == Plugin_Continue)
						{
							iCount = iDummy;
						}

						TakeClientKnives(iVictim, iCount);

						PrintHintText(iVictim, "Ножей осталось: %i", g_iPlayerKniveCount[iClient]);
					}

					aResult = Forward_OnKnifesGiven(iClient, iCount, KNIFES_BY_STEAL);
					if(aResult > Plugin_Changed)
					{
						if(aResult == Plugin_Continue)
						{
							iCount = iDummy;
						}

						GiveClientKnives(iClient, iCount);

						PrintHintText(iClient, "Ножей осталось: %i", g_iPlayerKniveCount[iClient]);
					}
				}
			}
			
			SetEventBool(hEvent, "headshot", g_bHeadshot[iClient]);
			g_bHeadshot[iClient] = false;
		}
	}

	return Plugin_Continue;
}

public Event_WeaponFire(Handle:hEvent, const String:sEvName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(HasClientKnives(iClient))
	{
		decl String:sWeapon[16];
		GetEventString(hEvent, "weapon", sWeapon, sizeof(sWeapon));
		
		if(StrContains(sWeapon, "knife", false) != -1 || strcmp(sWeapon[7], "bayonet") == 0)
		{
			if(g_Cvar_iRoundLimit != -1 && g_iRoundUsed[iClient] >= g_Cvar_iRoundLimit)
			{
				PrintHintText(iClient, "Достигнут лимит использований за раунд!");
				return;
			}
			
			if(Forward_OnKnifeThrow(iClient))
			{
				g_hTimerDelay[iClient] = CreateTimer(0.0, CreateKnife, iClient);
			}
		}
	}
}

public Action:CreateKnife(Handle:timer, any:iClient)
{
	g_hTimerDelay[iClient] = INVALID_HANDLE;
	if(IsClientInGame(iClient))
	{
		new slot_knife = GetPlayerWeaponSlot(iClient, 2);
		new iKnife = CreateEntityByName("smokegrenade_projectile");
		DispatchKeyValue(iKnife, "classname", "throwing_knife");

		if(DispatchSpawn(iKnife))
		{
			PushArrayCell(g_hThrownKnives, EntIndexToEntRef(iKnife));

			new iTeam = GetClientTeam(iClient);
			SetEntPropEnt(iKnife, Prop_Send, "m_hOwnerEntity", iClient);
			SetEntPropEnt(iKnife, Prop_Send, "m_hThrower", iClient);
			SetEntProp(iKnife, Prop_Send, "m_iTeamNum", iTeam);

			decl String:sBuffer[PLATFORM_MAX_PATH];
			if(slot_knife != -1)
			{
				GetEntPropString(slot_knife, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));
				if(ReplaceString(sBuffer, sizeof(sBuffer), "v_knife_", "w_knife_", true) != 1)
				{
					sBuffer[0] = '\0';
				}
				else if(Engine_Version == GAME_CSGO && ReplaceString(sBuffer, sizeof(sBuffer), ".mdl", "_dropped.mdl", true) != 1)
				{
					sBuffer[0] = '\0';
				}
			}

			if(FileExists(sBuffer, true) == false)
			{
				if(Engine_Version == GAME_CSGO)
				{
					switch(iTeam)
					{
						case 2:	strcopy(sBuffer, sizeof(sBuffer), "models/weapons/w_knife_default_t_dropped.mdl");
						case 3:	strcopy(sBuffer, sizeof(sBuffer), "models/weapons/w_knife_default_ct_dropped.mdl");
					}
				}
				else
				{
					strcopy(sBuffer, sizeof(sBuffer), "models/weapons/w_knife_t.mdl");
				}
			}

			SetEntProp(iKnife, Prop_Send, "m_nModelIndex", PrecacheModel(sBuffer));
			if(Engine_Version != GAME_CSS_34)
			{
				SetEntPropFloat(iKnife, Prop_Send, "m_flModelScale", g_Cvar_fModelScale);
			}
			SetEntPropFloat(iKnife, Prop_Send, "m_flElasticity", g_Cvar_fElasticity);
			SetEntPropFloat(iKnife, Prop_Data, "m_flGravity", g_Cvar_fGravity);

			decl Float:fOrigin[3], Float:fAngles[3], Float:sPos[3], Float:fPlayerVelocity[3], Float:fVelocity[3];
			GetClientEyePosition(iClient, fOrigin);
			GetClientEyeAngles(iClient, fAngles);

			GetAngleVectors(fAngles, sPos, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(sPos, 50.0);
			AddVectors(sPos, fOrigin, sPos);

			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fPlayerVelocity);
			GetAngleVectors(fAngles, fVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(fVelocity, g_Cvar_fVelocity);
			AddVectors(fVelocity, fPlayerVelocity, fVelocity);

			SetEntPropVector(iKnife, Prop_Data, "m_vecAngVelocity", Float:{4000.0, 0.0, 0.0});

			SetEntProp(iKnife, Prop_Data, "m_nNextThinkTick", -1);
			Format(sBuffer, sizeof(sBuffer), "!self,Kill,,%0.1f,-1", g_Cvar_fMaxLifeTime);
			DispatchKeyValue(iKnife, "OnUser1", sBuffer);
			AcceptEntityInput(iKnife, "FireUser1");

			if(g_Cvar_bTrails)
			{
				if(Engine_Version == GAME_CSGO)
				{
					TE_SetupBeamFollow(iKnife, g_iTrailSprite, 0, 0.5, 1.0, 0.1, 0, {255, 255, 255, 255});
				}
				else
				{
					TE_SetupBeamFollow(iKnife, g_iTrailSprite, 0, 0.5, 8.0, 1.0, 0, {255, 255, 255, 255});
				}

				TE_SendToAll();
			}

			TeleportEntity(iKnife, sPos, fAngles, fVelocity);
			SDKHookEx(iKnife, SDKHook_Touch, KnifeHit);

			++g_iRoundUsed[iClient];
			if(g_iPlayerKniveCount[iClient] != -1)
			{
				g_iPlayerKniveCount[iClient]--;
				PrintHintText(iClient, "Ножей осталось: %i", g_iPlayerKniveCount[iClient]);
			}
		}
	}

	return Plugin_Stop;
}

public Action:KnifeHit(iKnife, iVictim)
{
	if(0 < iVictim && iVictim <= MaxClients)
	{
		new iAttacker = GetEntPropEnt(iKnife, Prop_Send, "m_hThrower");
		
		/*
		decl String:sClassName[64];
		GetEntPropString(iKnife, Prop_Data, "m_iClassname", sClassName, sizeof(sClassName));
		PrintToChat(iAttacker, "m_iClassname: '%s'", sClassName);
		m_iClassname: 'throwing_knife'
		*/

		
		SetVariantString("csblood");
		AcceptEntityInput(iKnife, "DispatchEffect");
		AcceptEntityInput(iKnife, "Kill");

		if(!g_Cvar_bFF && GetClientTeam(iAttacker) == GetClientTeam(iVictim))
		{
			return Plugin_Continue;
		}

		decl Float:fVictimEye[3], Float:fDamagePosition[3], Float:fDamageForce[3];
		GetClientEyePosition(iVictim, fVictimEye);

		GetEntPropVector(iKnife, Prop_Data, "m_vecOrigin", fDamagePosition);
		GetEntPropVector(iKnife, Prop_Data, "m_vecVelocity", fDamageForce);

		if(GetVectorLength(fDamageForce) != 0.0)
		{
			new Float:distance = GetVectorDistance(fDamagePosition, fVictimEye);
			g_bHeadshot[iAttacker] = distance <= 15.0;

			decl iDmgType, Float:fDamage;
			iDmgType = g_iDmgType;

			if(g_bHeadshot[iAttacker])
			{
				fDamage = g_Cvar_fHSDamage;
				iDmgType |= DMG_HEADSHOT;
			}
			else
			{
				fDamage = g_Cvar_fDamage;
			}

			if(Engine_Version == GAME_CSS_34)
			{
				HurtClient(iVictim, iAttacker, fDamage, iDmgType, "weapon_knife");
			}
			else
			{
				new inflictor = GetPlayerWeaponSlot(iAttacker, 2);

				if(inflictor == -1)
				{
					inflictor = iAttacker;
				}

				SDKHooks_TakeDamage(iVictim, inflictor, iAttacker, fDamage, iDmgType, iKnife, fDamageForce, fDamagePosition);
			}

			TE_SetupBloodSprite(fDamagePosition, Float:{0.0, 0.0, 0.0}, {255, 0, 0, 255}, 1, g_iBloodDecal, g_iBloodDecal);
			TE_SendToAll(0.0);

			new ragdoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
			if(ragdoll != -1)
			{
				ScaleVector(fDamageForce, 50.0);
				fDamageForce[2] = FloatAbs(fDamageForce[2]);
				SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", fDamageForce);
				SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", fDamageForce);
			}
		}
	}
	else if(FindValueInArray(g_hThrownKnives, EntIndexToEntRef(iVictim)) != -1) // ножи столкнулись
	{
		SDKUnhook(iKnife, SDKHook_Touch, KnifeHit);
		decl Float:sPos[3], Float:dir[3];
		GetEntPropVector(iKnife, Prop_Data, "m_vecOrigin", sPos);
		TE_SetupArmorRicochet(sPos, dir);
		TE_SendToAll(0.0);

		DispatchKeyValue(iKnife, "OnUser1", "!self,Kill,,1.0,-1");
		AcceptEntityInput(iKnife, "FireUser1");
	}

	return Plugin_Continue;
}

public OnEntityDestroyed(iEntity)
{
	if(IsValidEdict(iEntity))
	{
		new index = FindValueInArray(g_hThrownKnives, EntIndexToEntRef(iEntity));
		if(index != -1)
		{
			RemoveFromArray(g_hThrownKnives, index);
		}
	}
}

public Event_RoundFreezeEnd(Handle:hEvent, const String:sEvName[], bool:bDontBroadcast)
{
	g_iPointHurt = CreateEntityByName("point_hurt");
	if ( IsValidEntity(g_iPointHurt) )
	{
		DispatchKeyValue(g_iPointHurt, "DamageTarget", 	"hurt");
	//	DispatchKeyValue(g_iPointHurt, "DamageType", 	"0");
		DispatchSpawn(g_iPointHurt);
	}
}

HurtClient(iClient, iAttacker, Float:fDamage, dmgtype, const String:sWeapon[])
{
	if (IsValidEntity(g_iPointHurt))
	{
		decl String:sBuffer[8];
		IntToString(dmgtype, sBuffer, sizeof(sBuffer));
		DispatchKeyValue(g_iPointHurt,	"DamageType", 	sBuffer);
		DispatchKeyValue(iClient, 			"targetname", 	"hurt");
		FloatToString(fDamage, sBuffer, sizeof(sBuffer));
		DispatchKeyValue(g_iPointHurt,	"damage", 		sBuffer);
		DispatchKeyValue(g_iPointHurt,	"classname", 	sWeapon);
		
		AcceptEntityInput(g_iPointHurt,	"hurt", 		iAttacker);
		DispatchKeyValue(iClient,			"targetname", 	"nohurt");
	}
}

GetClientKnives(iClient)
{
	return g_iPlayerKniveCount[iClient];
}

SetClientKnives(iClient, iCount)
{
	g_iPlayerKniveCount[iClient] = iCount;
}

bool:GiveClientKnives(iClient, iCount)
{
	if(g_iPlayerKniveCount[iClient] != -1)
	{
		g_iPlayerKniveCount[iClient] += iCount;
		return true;
	}

	return false;
}

bool:TakeClientKnives(iClient, iCount)
{
	if(g_iPlayerKniveCount[iClient] != -1)
	{
		g_iPlayerKniveCount[iClient] -= iCount;
	
		if(g_iPlayerKniveCount[iClient] < 0)
		{
			g_iPlayerKniveCount[iClient] = 0;
		}

		return true;
	}

	return false;
}

bool:HasClientKnives(iClient)
{
	return g_iPlayerKniveCount[iClient] == -1 || g_iPlayerKniveCount[iClient] > 0;
}
	
GetCSGame()
{
	if (GetFeatureStatus(FeatureType_Native, "GetEngineVersion") == FeatureStatus_Available) 
	{ 
		switch (GetEngineVersion()) 
		{ 
			case Engine_SourceSDK2006: return GAME_CSS_34; 
			case Engine_CSS: return GAME_CSS; 
			case Engine_CSGO: return GAME_CSGO; 
		} 
	} 
	else if (GetFeatureStatus(FeatureType_Native, "GuessSDKVersion") == FeatureStatus_Available) 
	{ 
		switch (GuessSDKVersion())
		{ 
			case SOURCE_SDK_EPISODE1: return GAME_CSS_34;
			case SOURCE_SDK_CSS: return GAME_CSS;
			case SOURCE_SDK_CSGO: return GAME_CSGO;
		}
	}
	return GAME_UNDEFINED;
}


bool:CheckClient(iClient, String:sError[], iLength)
{
	if (iClient < 1 || iClient > MaxClients)
	{
		FormatEx(sError, iLength, "Client index %i is invalid", iClient);
		return false;
	}
	else if (!IsClientInGame(iClient))
	{
		FormatEx(sError, iLength, "Client index %i is not in game", iClient);
		return false;
	}
	else if (IsFakeClient(iClient))
	{
		FormatEx(sError, iLength, "Client index %i is a bot", iClient);
		return false;
	}
	
	sError[0] = '\0';

	return true;
}

public Native_GetClientKnives(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	decl String:sError[64];
	if (!CheckClient(iClient, sError, sizeof(sError)))
	{
		ThrowNativeError(SP_ERROR_NATIVE, sError);
	}
	
	return GetClientKnives(iClient);
}

public Native_SetClientKnives(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	decl String:sError[64];
	if (!CheckClient(iClient, sError, sizeof(sError)))
	{
		ThrowNativeError(SP_ERROR_NATIVE, sError);
	}

	new iCount = GetNativeCell(2);
	if(iCount < -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid amount (%i)", iCount);
	}

	SetClientKnives(iClient, iCount);
}

public Native_GiveClientKnives(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	decl String:sError[64];
	if (!CheckClient(iClient, sError, sizeof(sError)))
	{
		ThrowNativeError(SP_ERROR_NATIVE, sError);
	}

	new iCount = GetNativeCell(2);
	if(iCount < 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid amount (%i)", iCount);
	}

	new iDummy = GetClientKnives(iClient);

	switch (Forward_OnKnifesGiven(iClient, iCount, KNIFES_BY_NATIVE))
	{
		case Plugin_Continue:
		{
			iCount = iDummy;
		}
		case Plugin_Handled, Plugin_Stop:
		{
			return false;
		}
	}
	
	return GiveClientKnives(iClient, iCount);
}

public Native_TakeClientKnives(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	decl String:sError[64];
	if (!CheckClient(iClient, sError, sizeof(sError)))
	{
		ThrowNativeError(SP_ERROR_NATIVE, sError);
	}

	new iCount = GetNativeCell(2);
	if(iCount < 1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid amount (%i)", iCount);
	}

	new iDummy = GetClientKnives(iClient);

	switch (Forward_OnKnifesTaken(iClient, iCount, KNIFES_BY_NATIVE))
	{
		case Plugin_Continue:
		{
			iCount = iDummy;
		}
		case Plugin_Handled, Plugin_Stop:
		{
			return false;
		}
	}

	return TakeClientKnives(iClient, iCount);
}

public Native_IsEntityThrowingKnife(Handle:hPlugin, iNumParams)
{
	new iEntity = GetNativeCell(1);

	if (iEntity < 1 || iEntity > 2048 || !IsValidEntity(iEntity))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Entity index %i is invalid", iEntity);
		return false;
	}

	return FindValueInArray(g_hThrownKnives, EntIndexToEntRef(iEntity)) != -1;
}

bool:Forward_OnKnifeThrow(iClient)
{
	new bool:bResult = true;
	
	Call_StartForward(g_hForward_OnKnifeThrow);
	Call_PushCell(iClient);
	Call_Finish(bResult);

	return bResult;
}

Action:Forward_OnKnifesGiven(iClient, &iCount, by_who)
{
	new Action:aResult = Plugin_Continue;
	
	Call_StartForward(g_hForward_OnKnifesGiven);
	Call_PushCell(iClient);
	Call_PushCellRef(iCount);
	Call_PushCell(by_who);
	Call_Finish(aResult);
	
	return aResult;
}

Action:Forward_OnKnifesTaken(iClient, &iCount, by_who)
{
	new Action:aResult = Plugin_Continue;
	
	Call_StartForward(g_hForward_OnKnifesTaken);
	Call_PushCell(iClient);
	Call_PushCellRef(iCount);
	Call_PushCell(by_who);
	Call_Finish(aResult);
	
	return aResult;
}