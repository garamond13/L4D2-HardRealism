/*
Version description

Note: SI order = smoker, boomer, hunter, spitter, jockey, charger.

Version 4:
- Tank health is relative to the number of alive survivors.
- Jockey health is set to 300.
- Charger health is set to 575.
- Special infected limit and max spawn size are relative to the number of alive survivors.
- Special infected spawn sizes and times are random and relative to the number of alive survivors.
- Special infected spawn limits in the SI order are 2, 1, 2, 1, 2, 2.
- Special infected spawn weights in the SI order are 100, 100, 100, 100, 90, 100.
- Special infected spawn weight reduction factors in the SI order are 0.5, 1.0, 0.5, 1.0, 0.5, 0.5.
- Special infected spawns are randomly delayed in the range [0.3s, 2.4s].
- M16 damage increased by 7%.
- Hunting Rifle damage increased by 12%.
- Military Sniper damage increased by 12%.
- AWP damage increased by 74%.
- Hunter Claw damage reduced by 50%.
- Disable bots shooting through the survivors.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

//MAJOR (gameplay change).MINOR.PATCH
#define VERSION "4.2.1"

//debug switches
#define DEBUG_DAMAGE_MOD 0
#define DEBUG_SI_SPAWN 0
#define DEBUG_TANK_HP 0

//teams
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

//zombie classes
#define SI_CLASS_SMOKER 1
#define SI_CLASS_BOOMER 2
#define SI_CLASS_HUNTER 3
#define SI_CLASS_SPITTER 4
#define SI_CLASS_JOCKEY 5
#define SI_CLASS_CHARGER 6

//special infected spawner
//

//special infected types (for indexing)
//keep the same order as zombie classes
#define SI_TYPES 6
#define SI_INDEX_SMOKER 0
#define SI_INDEX_BOOMER 1
#define SI_INDEX_HUNTER 2
#define SI_INDEX_SPITTER 3
#define SI_INDEX_JOCKEY 4
#define SI_INDEX_CHARGER 5

#if DEBUG_SI_SPAWN
//keep the same order as zombie classes
static const char debug_si_indexes[SI_TYPES][] = { "SI_INDEX_SMOKER", "SI_INDEX_BOOMER", "SI_INDEX_HUNTER", "SI_INDEX_SPITTER", "SI_INDEX_JOCKEY", "SI_INDEX_CHARGER" };
#endif

//keep the same order as zombie classes
static const char z_spawns[SI_TYPES][] = { "smoker", "boomer", "hunter", "spitter", "jockey", "charger" };
static const int si_spawn_limits[SI_TYPES] = { 2, 1, 2, 1, 2, 2 };
static const int si_spawn_weights[SI_TYPES] = { 100, 100, 100, 100, 90, 100 };
static const float si_spawn_weight_mods[SI_TYPES] = { 0.5, 1.0, 0.5, 1.0, 0.5, 0.5 };

//size
int si_limit;
int si_spawn_size_min;

//time
float si_spawn_time_min;
float si_spawn_time_max;

int alive_survivors;
int si_type_counts[SI_TYPES];
int si_total_count;

//spawn timer
Handle h_spawn_timer;
bool is_spawn_timer_running;

//

//tank health
int tank_hp;

//damage mod
Handle h_weapon_trie;

//gamemode and difficulty guard
bool is_gamemode_rejected;
Handle h_z_difficulty;

public Plugin myinfo = {
	name = "L4D2 HardRealism",
	author = "Garamond",
	description = "HardRealism mod",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-HardRealism"
};

public void OnPluginStart()
{
	//map damage mods
	h_weapon_trie = CreateTrie();
	SetTrieValue(h_weapon_trie, "weapon_rifle", 1.07);
	SetTrieValue(h_weapon_trie, "weapon_hunting_rifle", 1.12);
	SetTrieValue(h_weapon_trie, "weapon_sniper_military", 1.12);
	SetTrieValue(h_weapon_trie, "weapon_sniper_awp", 1.74);
	SetTrieValue(h_weapon_trie, "weapon_hunter_claw", 0.5);

	//hook game events
	HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", event_player_spawn);
	HookEvent("player_death", event_player_death);
	HookEvent("tank_spawn", event_tank_spawn, EventHookMode_Pre);
	HookEvent("round_end", event_round_end, EventHookMode_Pre);

	//setup difficulty guard
	h_z_difficulty = FindConVar("z_difficulty");
	SetConVarString(h_z_difficulty, "Impossible");
	HookConVarChange(h_z_difficulty, convar_change_z_difficulty);
	AddCommandListener(on_callvote, "callvote");
}

public void OnMapStart()
{
	char buffer[32];
	GetConVarString(FindConVar("mp_gamemode"), buffer, sizeof(buffer));
	if (!strcmp(buffer, "realism"))
		is_gamemode_rejected = false;
	else {
		is_gamemode_rejected = true;
		CreateTimer(1.0, changelevel, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action changelevel(Handle timer)
{
	ServerCommand("sm_cvar mp_gamemode realism; changelevel c1m1_hotel");
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	//defualt 325
	SetConVarInt(FindConVar("z_jockey_health"), 300);

	//default 600
	SetConVarInt(FindConVar("z_charger_health"), 575);

	//disable bots shooting through the survivors
	SetConVarInt(FindConVar("sb_allow_shoot_through_survivors"), 0);

	//disbale director spawn special infected
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);
}

Action on_callvote(int client, const char[] command, int argc)
{
	char buffer[32];
	GetCmdArg(1, buffer, sizeof(buffer));
	
	//silenly disable ChangeDifficulty vote
	if (!strcmp(buffer, "ChangeDifficulty"))
		return Plugin_Handled;

	return Plugin_Continue;
}

void convar_change_z_difficulty(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarString(h_z_difficulty, "Impossible");
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlength)
{
	if (is_gamemode_rejected && !IsFakeClient(client)) {

		//a dot at the end of the message will be auto added
		strcopy(rejectmsg, maxlength, "[HardRealism] Server doesn't support this gamemode. Only realism is supported");

		return false;
	}
	return true;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, on_take_damage);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!strcmp(classname, "infected") || !strcmp(classname, "witch"))
		SDKHook(entity, SDKHook_OnTakeDamage, on_take_damage);
}

public Action on_take_damage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	//attack with equipped weapon
	if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && attacker == inflictor) {
		char classname[32];
		GetClientWeapon(attacker, classname, sizeof(classname));

		//get damage modifier
		float mod;
		if (GetTrieValue(h_weapon_trie, classname, mod)) {
			damage *= mod;

			#if DEBUG_DAMAGE_MOD
			PrintToChatAll("[HR] Damage of %s modded by [%f] to %f", classname, mod, damage);
			#endif

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] event_player_left_safe_area()");
	#endif

	start_spawn_timer();
}

public void event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS) {

		//count on the next frame, fixes miscount on idle
		RequestFrame(survivor_check);

	}
}

public void event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
		survivor_check();
}

public void survivor_check()
{
	//count alive survivors
	alive_survivors = 0;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			++alive_survivors;
	
	//set survior relative values
	switch (alive_survivors) {
		case 4: {
			si_limit = 5;
			si_spawn_size_min = 2;
			si_spawn_time_min = 16.0;
			si_spawn_time_max = 36.0;
			tank_hp = 24000;
		}
		case 3: {
			si_limit = 5;
			si_spawn_size_min = 2;
			si_spawn_time_min = 17.0;
			si_spawn_time_max = 38.0;
			tank_hp = 18000;
		}
		case 2: {
			si_limit = 4;
			si_spawn_size_min = 2;
			si_spawn_time_min = 17.0;
			si_spawn_time_max = 38.0;
			tank_hp = 12000;
		}
		case 1: {
			si_limit = 2;
			si_spawn_size_min = 1;
			si_spawn_time_min = 17.0;
			si_spawn_time_max = 38.0;
			tank_hp = 6000;
		}
	}

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] survivor_check(): alive_survivors = %i", alive_survivors);
	PrintToConsoleAll("[HR] survivor_check(): si_spawn_size_min = %i; si_limit = %i", si_spawn_size_min, si_limit);
	PrintToConsoleAll("[HR] survivor_check(): si_spawn_time_min = %f; si_spawn_time_max = %f", si_spawn_time_min, si_spawn_time_max);
	PrintToConsoleAll("[HR] survivor_check(): tank_hp = %i", tank_hp);
	#endif
}

void start_spawn_timer()
{
	float timer = GetRandomFloat(si_spawn_time_min, si_spawn_time_max);
	h_spawn_timer = CreateTimer(timer, auto_spawn_si);
	is_spawn_timer_running = true;

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] start_spawn_timer(): si_spawn_time_min = %f; si_spawn_time_max = %f; timer = %f", si_spawn_time_min, si_spawn_time_max, timer);
	#endif
}

public Action auto_spawn_si(Handle timer)
{
	is_spawn_timer_running = false;
	spawn_si();
	start_spawn_timer();
	return Plugin_Continue;
}

void spawn_si()
{
	count_si();
	if (si_total_count < si_limit) {
		
		//set spawn size
		int size = si_limit - si_total_count;
		if (si_spawn_size_min < size)
			size = GetRandomInt(si_spawn_size_min, size);

		#if DEBUG_SI_SPAWN
		PrintToConsoleAll("[HR] spawn_si(): si_spawn_size_min = %i; si_limit = %i; si_total_count = %i; size = %i", si_spawn_size_min, si_limit, si_total_count, size);
		#endif

		float delay = 0.0;
		while (size) {
			int index = get_si_index();

			//break on ivalid index, since get_si_index() has 5 retries to give valid index
			if (index < 0)
				break;

			//prevent instant spam of all specials at once
			//min and max delays are chosen more for technical reasons than gameplay reasons
			delay += GetRandomFloat(0.3, 2.2);
			CreateTimer(delay, z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);

			--size;
		}
	}

	#if DEBUG_SI_SPAWN
	else
		PrintToConsoleAll("[HR] spawn_si(): si_spawn_size_min = %i; si_limit = %i; si_total_count = %i; SI LIMIT REACHED!", si_spawn_size_min, si_limit, si_total_count);
	#endif
}

void count_si()
{
	//reset counts
	si_total_count = 0;
	for (int i = 0; i < SI_TYPES; ++i)
		si_type_counts[i] = 0;

	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {

			//detect special infected type by zombie class
			switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
				case SI_CLASS_SMOKER: {
					++si_type_counts[SI_INDEX_SMOKER];
					++si_total_count;
				}
				case SI_CLASS_BOOMER: {
					++si_type_counts[SI_INDEX_BOOMER];
					++si_total_count;
				}
				case SI_CLASS_HUNTER: {
					++si_type_counts[SI_INDEX_HUNTER];
					++si_total_count;
				}
				case SI_CLASS_SPITTER: {
					++si_type_counts[SI_INDEX_SPITTER];
					++si_total_count;
				}
				case SI_CLASS_JOCKEY: {
					++si_type_counts[SI_INDEX_JOCKEY];
					++si_total_count;
				}
				case SI_CLASS_CHARGER: {
					++si_type_counts[SI_INDEX_CHARGER];
					++si_total_count;
				}
			}
		}
	}
}

int get_si_index()
{
	//calculate temporary weights and their weight sum, including reductions
	int tmp_weights[SI_TYPES];
	int tmp_wsum = 0;
	for (int i = 0; i < SI_TYPES; ++i) {
		int tmp_count = si_type_counts[i];
		tmp_weights[i] = si_spawn_weights[i];
		while (tmp_count) {
			tmp_weights[i] = RoundToNearest(float(tmp_weights[i]) * si_spawn_weight_mods[i]);
			--tmp_count;
		}
		tmp_wsum += tmp_weights[i];
	}

	#if DEBUG_SI_SPAWN
	for (int i = 0; i < SI_TYPES; ++i)
		PrintToConsoleAll("[HR] get_si_index(): tmp_weights[%s] = %i", debug_si_indexes[i], tmp_weights[i]);
	#endif

	//get random index
	int retries = 5;
	while (retries) {
		int index = GetRandomInt(1, tmp_wsum);

		//cycle trough weight ranges, find where the random index falls and pick an appropriate array index
		int range = 0;
		for (int i = 0; i < SI_TYPES; ++i) {
			range += tmp_weights[i];
			if (index <= range) {
				index = i;
				break;
			}
		}

		#if DEBUG_SI_SPAWN
		PrintToConsoleAll("[HR] get_si_index(): retries = %i; range = %i; tmp_wsum = %i; index = %s", retries, range, tmp_wsum, debug_si_indexes[index]);
		#endif

		if (si_type_counts[index] < si_spawn_limits[index]) {
			++si_type_counts[index];
			return index;
		}
		--retries;
	}

	//indicates an invalid index
	return -1;
}

public Action z_spawn_old(Handle timer, any data)
{	
	int client = get_random_alive_survivor();
	if (client) {
		
		//create infected bot
		//without this we may not be able to spawn our special infected
		int bot = CreateFakeClient("Infected Bot");
		if (bot)
			ChangeClientTeam(bot, TEAM_INFECTED);

		//store command flags
		int flags = GetCommandFlags("z_spawn_old");

		//clear "sv_cheat" flag from the command
		SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);

		FakeClientCommand(client, "z_spawn_old %s auto", z_spawns[data]);

		//restore command flags
		SetCommandFlags("z_spawn_old", flags);

		#if DEBUG_SI_SPAWN
		char buffer[32];
		GetClientName(client, buffer, sizeof(buffer));
		PrintToConsoleAll("[HR] z_spawn_old(): client = %i [%s]; z_spawns[%s] = %s", client, buffer, debug_si_indexes[data], z_spawns[data]);
		#endif

		//kick the bot
		if (bot && IsClientConnected(bot))
			KickClient(bot);

	}

	#if DEBUG_SI_SPAWN
	else
		PrintToConsoleAll("[HR] z_spawn_old(): INVALID CLIENT!");
	#endif

	return Plugin_Continue;
}

int get_random_alive_survivor()
{
	if (alive_survivors) {
		int[] clients = new int[alive_survivors];
		int index = 0;
		for (int i = 1; i <= MaxClients; ++i)
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				clients[index++] = i;
		return clients[GetRandomInt(0, alive_survivors - 1)];
	}
	return 0;
}

public void event_tank_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client) {
		SetEntProp(client, Prop_Data, "m_iMaxHealth", tank_hp);
		SetEntProp(client, Prop_Data, "m_iHealth", tank_hp);

		//the constant factor was calculated from default values
		SetConVarInt(FindConVar("tank_burn_duration_expert"), RoundToNearest(float(tank_hp) * 0.010625));

		#if DEBUG_TANK_HP
		PrintToConsoleAll("[HR] event_tank_spawn(): tank_hp = %i", tank_hp);
		PrintToConsoleAll("[HR] event_tank_spawn(): tank hp is %i", GetEntProp(client, Prop_Data, "m_iHealth"));
		PrintToConsoleAll("[HR] event_tank_spawn(): tank max hp is %i", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
		PrintToConsoleAll("[HR] event_tank_spawn(): tank burn time is %i", GetConVarInt(FindConVar("tank_burn_duration_expert")));
		#endif
	}

	#if DEBUG_TANK_HP
	else
		PrintToConsoleAll("[HR] event_tank_spawn(): CLIENT WAS ZERO!");
	#endif
}

public void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	end_spawn_timer();
}

public void OnMapEnd()
{
	end_spawn_timer();
}

void end_spawn_timer()
{
	if (is_spawn_timer_running) {
		CloseHandle(h_spawn_timer);
		is_spawn_timer_running = false;
	}
}
