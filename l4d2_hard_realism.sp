/*
Version description / Changelog

Note: SI order = smoker, boomer, hunter, spitter, jockey, charger

Version 1

- Tank health is randomized in the range [3200, 16000].
- Jockey health is set to 300.
- Charger health is set to 575.
- Special infected limit is 5.
- Special infected spawn size minimum is 2.
- Special infected spawn size maximum is 5.
- Special infected spawn size increase per alive survivor is 1.
- Special infected spawn limits in SI order 2, 1, 2, 1, 2, 2
- Special infected spawn weights in SI order 100, 100, 100, 100, 90, 100
- Special infected spawn weight reduction factors in SI order 0.6, 1.0, 0.6, 1.0, 0.6, 0.6
- Special infected minimum spawn time is 15s.
- Special infected spawn time limit is 67s.
- Special infected spawn time reduction per alive survivor is 4.25s.
- Special infected spawns are randomly delayed in the range [0.3s, 2.7s].
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

//MAJOR.MINOR.PATCH
#define VERSION "1.1.1"

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
//keep same order as zombie classes
#define SI_TYPES 6
#define SI_SMOKER 0
#define SI_BOOMER 1
#define SI_HUNTER 2
#define SI_SPITTER 3
#define SI_JOCKEY 4
#define SI_CHARGER 5

//keep same order as zombie classes
char z_spawns[SI_TYPES][8] = { "smoker", "boomer", "hunter", "spitter", "jockey", "charger" };
int si_spawn_limits[SI_TYPES] = { 2, 1, 2, 1, 2, 2 };
int si_spawn_weights[SI_TYPES] = { 100, 100, 100, 100, 90, 100};
float si_spawn_weight_reduction_factors[SI_TYPES] = { 0.6, 1.0, 0.6, 1.0, 0.6, 0.6 };

//size
const int si_limit = 5;
const int si_spawn_size_min = 2;
int si_spawn_size_max;

//time
const float si_spawn_time_min = 15.0;
float si_spawn_time_max;
const float si_spawn_time_limit = 67.0;
const float si_spawn_time_per_survivor = 4.25;
const float si_spawn_delay_min = 0.3;
const float si_spawn_delay_max = 2.7;

int alive_survivors;
int si_type_counts[SI_TYPES];
int si_total_count;

//spawn timer
Handle h_spawn_timer;
bool is_spawn_timer_started;

//

//tank hp
const int tank_hp_min = 3200;
const int tank_hp_max = 16000;

Handle h_weapon_trie;

public Plugin myinfo = {
	name = "L4D2 HardRealism",
	author = "Garamond",
	description = "HardRealism mod",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-HardRealism"
};

public void OnPluginStart()
{
	//map weapon mods
	h_weapon_trie = CreateTrie();
	SetTrieValue(h_weapon_trie, "weapon_rifle", 1.07);
	SetTrieValue(h_weapon_trie, "weapon_hunting_rifle", 1.12);
	SetTrieValue(h_weapon_trie, "weapon_sniper_military", 1.12);
	SetTrieValue(h_weapon_trie, "weapon_sniper_awp", 1.74);
	SetTrieValue(h_weapon_trie, "weapon_hunter_claw", 0.5);

	//hook game events
	HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", survivor_check_on_event);
	HookEvent("player_death", survivor_check_on_event);
	HookEvent("tank_spawn", event_tank_spawn, EventHookMode_Pre);
	HookEvent("round_end", event_round_end, EventHookMode_Pre);
	HookEvent("map_transition", event_round_end, EventHookMode_Pre);
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
	if (attacker > 0 && attacker <= MaxClients && attacker == inflictor && IsClientInGame(attacker)) {
		char classname[32];
		GetClientWeapon(inflictor, classname, sizeof(classname));

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

public void survivor_check_on_event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
		survivor_check();
}

void survivor_check()
{
	//count alive survivors
	alive_survivors = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			alive_survivors++;
	
	si_spawn_size_max = si_spawn_size_min + alive_survivors;
	if (si_spawn_size_max > si_limit)
		si_spawn_size_max = si_limit;
	si_spawn_time_max = si_spawn_time_limit - si_spawn_time_per_survivor * alive_survivors;

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] survivor_check(): alive_survivors = %i; si_spawn_size_max = %i; si_spawn_time_max = %f", alive_survivors, si_spawn_size_max, si_spawn_time_max);
	#endif
}

void start_spawn_timer()
{
	end_spawn_timer();
	float timer = GetRandomFloat(si_spawn_time_min, si_spawn_time_max);
	h_spawn_timer = CreateTimer(timer, auto_spawn_si);
	is_spawn_timer_started = true;

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] start_spawn_timer(): si_spawn_time_max = %f; timer = %f", si_spawn_time_max, timer);
	#endif
}

void end_spawn_timer()
{
	if (is_spawn_timer_started) {
		CloseHandle(h_spawn_timer);
		is_spawn_timer_started = false;
	}
}

public Action auto_spawn_si(Handle timer)
{
	is_spawn_timer_started = false;
	spawn_si();
	start_spawn_timer();
	return Plugin_Continue;
}

void spawn_si()
{
	count_si();

	//early return if limit is reached
	if (si_total_count >= si_limit) {

		#if DEBUG_SI_SPAWN
		PrintToConsoleAll("[HR] spawn_si(): si_total_count = %i; return", si_total_count);
		#endif

		return;
	}

	//set spawn size
	int difference = si_limit - si_total_count;
	int size = si_spawn_size_max > difference ? difference : si_spawn_size_max;
	if (si_spawn_size_min < size)
		size = GetRandomInt(si_spawn_size_min, size);

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] spawn_si(): si_total_count = %i; size = %i", si_total_count, size);
	#endif
	
	float delay = 0.0;
	while (size > 0) {
		int index = get_si_index();

		//break on ivalid index, since get_si_index() has 5 retries to give valid index
		if (index < 0)
			break;
		
		//prevent instant spam of all specials at once
		delay += GetRandomFloat(si_spawn_delay_min, si_spawn_delay_max);
		CreateTimer(delay, z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);

		size--;
	}
}

void count_si()
{
	//reset counts
	si_total_count = 0;
	for (int i = 0; i < SI_TYPES; i++)
		si_type_counts[i] = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {

			//detect special infected type by zombie class
			switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
				case SI_CLASS_SMOKER: {
					si_type_counts[SI_SMOKER]++;
					si_total_count++;
				}
				case SI_CLASS_BOOMER: {
					si_type_counts[SI_BOOMER]++;
					si_total_count++;
				}
				case SI_CLASS_HUNTER: {
					si_type_counts[SI_HUNTER]++;
					si_total_count++;
				}
				case SI_CLASS_SPITTER: {
					si_type_counts[SI_SPITTER]++;
					si_total_count++;
				}
				case SI_CLASS_JOCKEY: {
					si_type_counts[SI_JOCKEY]++;
					si_total_count++;
				}
				case SI_CLASS_CHARGER: {
					si_type_counts[SI_CHARGER]++;
					si_total_count++;
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
	for (int i = 0; i < SI_TYPES; i++) {
		int tmp_count = si_type_counts[i];
		tmp_weights[i] = si_spawn_weights[i];
		while (tmp_count) {
			tmp_weights[i] = RoundToNearest(float(tmp_weights[i]) * si_spawn_weight_reduction_factors[i]);
			tmp_count--;
		}
		tmp_wsum += tmp_weights[i];
	}

	#if DEBUG_SI_SPAWN
	for (int i = 0; i < SI_TYPES; i++)
		PrintToConsoleAll("[HR] get_si_index(): tmp_weights[%i] = %i", i, tmp_weights[i]);
	#endif

	//get random index
	int retries = 5;
	while (retries > 0) {
		int index = GetRandomInt(1, tmp_wsum);

		//cycle trough weight ranges, find where the random index falls and pick an appropriate array index
		int range = 0;
		for (int i = 0; i < SI_TYPES; i++) {
			range += tmp_weights[i];
			if (index <= range) {
				index = i;
				break;
			}
		}

		#if DEBUG_SI_SPAWN
		PrintToConsoleAll("[HR] get_si_index(): retries = %i; range = %i; tmp_wsum = %i; index = %i", retries, range, tmp_wsum, index);
		#endif

		if (si_type_counts[index] < si_spawn_limits[index]) {
			si_type_counts[index]++;
			return index;
		}
		retries--;
	}

	return -1;
}

public Action z_spawn_old(Handle timer, any data)
{	
	int client = get_random_alive_survivor();
	
	//early return on invalid client
	if (!client) {

		#if DEBUG_SI_SPAWN
		PrintToConsoleAll("[HR] z_spawn_old(): INVALID CLIENT!");
		#endif
		
		return Plugin_Continue;
	}
	
	//create infected bot
	//without this we may not be able to spawn our special infected
	int bot = CreateFakeClient("Infected Bot");
	if (bot) {
		ChangeClientTeam(bot, TEAM_INFECTED);
		CreateTimer(0.1, kick_bot, bot, TIMER_FLAG_NO_MAPCHANGE);
	}

	static const char command[] = "z_spawn_old";

	//store command flags
	int flags = GetCommandFlags(command);
	
	//remove sv_cheat flag from the command
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);

	FakeClientCommand(client, "%s %s auto", command, z_spawns[data]);
	
	//restore command flags
	SetCommandFlags(command, flags);

	#if DEBUG_SI_SPAWN
	PrintToConsoleAll("[HR] z_spawn_old(): client = %i; z_spawns[%i] = %s", client, data, z_spawns[data]);
	#endif

	return Plugin_Continue;
}

int get_random_alive_survivor()
{
	if (alive_survivors) {
		int[] clients = new int[alive_survivors];
		int index = 0;
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				clients[index++] = i;
		return clients[GetRandomInt(0, alive_survivors - 1)];
	}
	return 0;
}

public Action kick_bot(Handle timer, any data)
{
	if (IsClientInGame(data) && !IsClientInKickQueue(data) && IsFakeClient(data))
		KickClient(data);
	return Plugin_Continue;
}

public void event_tank_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int hp = GetRandomInt(tank_hp_min, tank_hp_max);

    //defualt 4000
	SetConVarInt(FindConVar("z_tank_health"), hp);

	//set burn times
	//constant factros were calculated from default values
	SetConVarInt(FindConVar("tank_burn_duration"), RoundToNearest(float(hp) * 0.01875));
	SetConVarInt(FindConVar("tank_burn_duration_hard"), RoundToNearest(float(hp) * 0.02125));
	SetConVarInt(FindConVar("tank_burn_duration_expert"), RoundToNearest(float(hp) * 0.02));

	#if DEBUG_TANK_HP
	PrintToConsoleAll("tank hp is %i", GetConVarInt(FindConVar("z_tank_health")));
	PrintToConsoleAll("tank burn time normal is %i", GetConVarInt(FindConVar("tank_burn_duration")));
	PrintToConsoleAll("tank burn time hard is %i", GetConVarInt(FindConVar("tank_burn_duration_hard")));
	PrintToConsoleAll("tank burn time expert is %i", GetConVarInt(FindConVar("tank_burn_duration_expert")));
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
