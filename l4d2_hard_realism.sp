#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

// MAJOR (gameplay change).MINOR.PATCH
#define VERSION "43.0.0"

public Plugin myinfo = {
    name = "L4D2 HardRealism",
    author = "Garamond",
    description = "HardRealism mod",
    version = VERSION,
    url = "https://github.com/garamond13/L4D2-HardRealism"
};

// Debug switches
#define DEBUG_DAMAGE_MOD 0
#define DEBUG_SI_SPAWN 0
#define DEBUG_TANK_HP 0
#define DEBUG_POSTURE 0

// Teams
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

// Zombie classes
#define ZOMBIE_CLASS_SMOKER 1
#define ZOMBIE_CLASS_BOOMER 2
#define ZOMBIE_CLASS_HUNTER 3
#define ZOMBIE_CLASS_SPITTER 4
#define ZOMBIE_CLASS_JOCKEY 5
#define ZOMBIE_CLASS_CHARGER 6
#define ZOMBIE_CLASS_TANK 8

// Special infected spawner
//

// Special infected types (for indexing).
// Keep the same order as zombie classes.
#define ZOMBIE_INDEX_SMOKER 0
#define ZOMBIE_INDEX_BOOMER 1
#define ZOMBIE_INDEX_HUNTER 2
#define ZOMBIE_INDEX_SPITTER 3
#define ZOMBIE_INDEX_JOCKEY 4
#define ZOMBIE_INDEX_CHARGER 5
#define ZOMBIE_INDEX_SIZE 6

#if DEBUG_SI_SPAWN
// Keep the same order as zombie classes.
static const char g_debug_si_indexes[ZOMBIE_INDEX_SIZE][] = { "ZOMBIE_INDEX_SMOKER", "ZOMBIE_INDEX_BOOMER", "ZOMBIE_INDEX_HUNTER", "ZOMBIE_INDEX_SPITTER", "ZOMBIE_INDEX_JOCKEY", "ZOMBIE_INDEX_CHARGER" };
#endif

Handle g_spawn_timer;
Handle g_hr_istankinplay;
int g_alive_survivors;
int g_si_max_spawn_size;
int g_si_min_spawn_size;
float g_si_min_spawn_interval;
float g_si_max_spawn_interval;

// Keep the same order as zombie classes.
int g_si_recently_killed[ZOMBIE_INDEX_SIZE];

//

Handle g_my_next_bot_pointer;
Handle g_get_body_interface;
Handle g_get_actual_posture;

// Damage mod
Handle g_weapon_trie;

float g_tank_base_health;

// Normal(0), Extreme(1)
int g_difficulty;

public void OnPluginStart()
{
    Handle gamedata = LoadGameConfigFile("l4d2_hard_realism");

    // INextBot* CBaseEntity::MyNextBotPointer()
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_my_next_bot_pointer = EndPrepSDKCall();

    // IBody* INextBot::GetBodyInterface()
    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "INextBot::GetBodyInterface");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_get_body_interface = EndPrepSDKCall();

    // PostureType IBody::GetActualPosture()
    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "IBody::GetActualPosture");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_get_actual_posture = EndPrepSDKCall();

    CloseHandle(gamedata);

    // Map modded damage.
    g_weapon_trie = CreateTrie();
    SetTrieValue(g_weapon_trie, "hunting_rifle", 38.0);
    SetTrieValue(g_weapon_trie, "sniper_military", 38.0);
    SetTrieValue(g_weapon_trie, "sniper_scout", 76.0);
    SetTrieValue(g_weapon_trie, "sniper_awp", 152.0);

    // Hook game events.
    HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", event_player_spawn);
    HookEvent("player_death", event_player_death);
    HookEvent("tank_spawn", event_tank_spawn, EventHookMode_Pre);
    HookEvent("round_end", event_round_end, EventHookMode_PostNoCopy);
    
    // Register new console commands.
    RegConsoleCmd("hr_getdifficulty", command_hr_getdifficulty);
    RegConsoleCmd("hr_switchdifficulty", command_hr_switchdifficulty);
    
    // Only used internaly.
    g_hr_istankinplay = CreateConVar("hr_istankinplay", "0");

    set_normal_difficulty();
}

void set_normal_difficulty()
{
    g_si_min_spawn_size = 2;
    g_si_max_spawn_size = 4;
    g_si_min_spawn_interval = 17.0;
    g_si_max_spawn_interval = 35.0;
    g_tank_base_health = 5200.0;
}

public void OnConfigsExecuted()
{	
    // Disbale director spawn special infected.
    SetConVarInt(FindConVar("z_smoker_limit"), 0);
    SetConVarInt(FindConVar("z_boomer_limit"), 0);
    SetConVarInt(FindConVar("z_hunter_limit"), 0);
    SetConVarInt(FindConVar("z_spitter_limit"), 0);
    SetConVarInt(FindConVar("z_jockey_limit"), 0);
    SetConVarInt(FindConVar("z_charger_limit"), 0);

    char current_map[20];
    GetCurrentMap(current_map, sizeof(current_map));
    
    // Set to Morning(2), to always spawn wandering witches.
    // Unless c6m1_riverbank, we don't want wandering bride witch.
    // Default -1.
    static const char sv_force_time_of_day[] = "sv_force_time_of_day";
    if (!strcmp(current_map, "c6m1_riverbank")) {
        SetConVarInt(FindConVar(sv_force_time_of_day), -1);
    }
    else {
        SetConVarInt(FindConVar(sv_force_time_of_day), 2);
    }

    // Defaults to 300 in Versus.
    // Default 50.
    SetConVarInt(FindConVar("tongue_break_from_damage_amount"), 300);

    // Remove tongue victim inaccuracy.
    // Default 0.133.
    SetConVarFloat(FindConVar("tongue_victim_accuracy_penalty"), 0.0);

    // Workaround. It will be halved by on_take_damage().
    // Default 5, it will be multiplied by 3 on Realsim Expert.
    SetConVarInt(FindConVar("z_pounce_damage"), 10);

    // Default 325
    SetConVarInt(FindConVar("z_jockey_health"), 290);

    // Default 4, it will be multiplied by 3 on Realsim Expert.
    SetConVarInt(FindConVar("z_jockey_ride_damage"), 5);

    // Default 15.
    SetConVarInt(FindConVar("z_charger_pound_dmg"), 20);

    // Default 100.
    SetConVarInt(FindConVar("z_shotgun_bonus_damage_range"), 150);
}

Action command_hr_getdifficulty(int client, int args)
{
    switch (g_difficulty) {
        case 0: {
            PrintToChat(client, "[HR] Normal difficulty.");
        }
        case 1: {
            PrintToChat(client, "[HR] Extreme difficulty.");
        }
        case 2: {
            PrintToChat(client, "[HR] Max difficulty.");
        }
    }
    return Plugin_Handled;
}

Action command_hr_switchdifficulty(int client, int args)
{
    ++g_difficulty;
    if (g_difficulty > 2) {
        g_difficulty = 0;
    }
    switch (g_difficulty) {
        case 0: {
            set_normal_difficulty();
            PrintToChatAll("[HR] Normal difficulty set by %N.", client);
        }
        case 1: {
            g_si_min_spawn_size = 2;
            g_si_max_spawn_size = 5;
            g_si_min_spawn_interval = 17.0;
            g_si_max_spawn_interval = 24.0;
            g_tank_base_health = 6000.0;
            PrintToChatAll("[HR] Extreme difficulty set by %N.", client);
        }
        case 2: {
            g_si_min_spawn_size = 5;
            g_si_max_spawn_size = 5;
            g_si_min_spawn_interval = 17.0;
            g_si_max_spawn_interval = 17.1;
            g_tank_base_health = 6000.0;
            PrintToChatAll("[HR] Max difficulty set by %N.", client);
        }
    }
    return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!strcmp(classname, "infected")) {
        SDKHook(entity, SDKHook_OnTakeDamage, on_take_damage_infected);
    }
}

Action on_take_damage_infected(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (attacker == inflictor && attacker > 0 && attacker <= MaxClients) {
        
        // The classname will have prefix weapon_
        char classname[24];
        GetClientWeapon(attacker, classname, sizeof(classname));

        // Get modded damage.
        if (GetTrieValue(g_weapon_trie, classname[7], damage)) {
        
            #if DEBUG_DAMAGE_MOD
            debug_on_take_damage(victim, attacker, inflictor, damage);
            #endif
        
            return Plugin_Changed;
        }
    }

    #if DEBUG_DAMAGE_MOD
    debug_on_take_damage(victim, attacker, inflictor, damage);
    #endif

    return Plugin_Continue;
}

void event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (GetClientTeam(client) == TEAM_SURVIVORS) {

        // First make sure we are not rehooking on_take_damage_survivor.
        SDKUnhook(client, SDKHook_OnTakeDamage, on_take_damage_survivor);

        SDKHook(client, SDKHook_OnTakeDamage, on_take_damage_survivor);

        // Count on the next frame, fixes miscount on idle.
        RequestFrame(count_alive_survivors);
    }
}

Action on_take_damage_survivor(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    // Hunter damage to survivors.
    if (attacker > 0 && attacker <= MaxClients && GetClientTeam(attacker) == TEAM_INFECTED && GetEntProp(attacker, Prop_Send, "m_zombieClass") == ZOMBIE_CLASS_HUNTER) {
        damage *= 0.5;

        #if DEBUG_DAMAGE_MOD
        debug_on_take_damage(victim, attacker, inflictor, damage);
        #endif

        return Plugin_Changed;
    }

    // Crouched commons damage to survivors
    else {
        char classname[12];
        GetEntityClassname(attacker, classname, sizeof(classname));
        if (!strcmp(classname, "infected")) {

            #if DEBUG_POSTURE
            static const char posture_type[][] = { "STAND", "CROUCH", "SIT", "CRAWL", "LIE" };
            int actual_posture = SDKCall(g_get_actual_posture, SDKCall(g_get_body_interface, SDKCall(g_my_next_bot_pointer, attacker)));
            PrintToChatAll("[HR] on_take_damage_survivor(): actual_posture = %s", posture_type[actual_posture]);
            #endif

            // If actual posture is PostureType::CROUCH
            if (SDKCall(g_get_actual_posture, SDKCall(g_get_body_interface, SDKCall(g_my_next_bot_pointer, attacker))) == 1) {
                damage = 2.0;
                return Plugin_Changed;
            }
        }
    }
    
    #if DEBUG_DAMAGE_MOD
    debug_on_take_damage(victim, attacker, inflictor, damage);
    #endif

    return Plugin_Continue;
}

void event_player_death(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client) {
        int client_team = GetClientTeam(client);

        // Keep track of recently killed special infected.
        if (client_team == TEAM_INFECTED) {
            const float delay = 4.0;
            switch (GetEntProp(client, Prop_Send, "m_zombieClass")) {
                case ZOMBIE_CLASS_SMOKER: {
                    ++g_si_recently_killed[ZOMBIE_INDEX_SMOKER];
                    CreateTimer(delay, clear_recently_killed, ZOMBIE_INDEX_SMOKER, TIMER_FLAG_NO_MAPCHANGE);
                }
                case ZOMBIE_CLASS_BOOMER: {
                    ++g_si_recently_killed[ZOMBIE_INDEX_BOOMER];
                    CreateTimer(delay, clear_recently_killed, ZOMBIE_INDEX_BOOMER, TIMER_FLAG_NO_MAPCHANGE);
                }
                case ZOMBIE_CLASS_HUNTER: {
                    ++g_si_recently_killed[ZOMBIE_INDEX_HUNTER];
                    CreateTimer(delay, clear_recently_killed, ZOMBIE_INDEX_HUNTER, TIMER_FLAG_NO_MAPCHANGE);
                }
                case ZOMBIE_CLASS_SPITTER: {
                    ++g_si_recently_killed[ZOMBIE_INDEX_SPITTER];
                    CreateTimer(delay, clear_recently_killed, ZOMBIE_INDEX_SPITTER, TIMER_FLAG_NO_MAPCHANGE);
                }
                case ZOMBIE_CLASS_JOCKEY: {
                    ++g_si_recently_killed[ZOMBIE_INDEX_JOCKEY];
                    CreateTimer(delay, clear_recently_killed, ZOMBIE_INDEX_JOCKEY, TIMER_FLAG_NO_MAPCHANGE);
                }
                case ZOMBIE_CLASS_CHARGER: {
                    ++g_si_recently_killed[ZOMBIE_INDEX_CHARGER];
                    CreateTimer(delay, clear_recently_killed, ZOMBIE_INDEX_CHARGER, TIMER_FLAG_NO_MAPCHANGE);
                }
            }
        }

        else if (client_team == TEAM_SURVIVORS) {
            count_alive_survivors();
        }
    }
}

void clear_recently_killed(Handle tiemr, int data)
{
    --g_si_recently_killed[data];
}

void count_alive_survivors()
{
    g_alive_survivors = 0;
    for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i)) {
            ++g_alive_survivors;
        }
    }

    #if DEBUG_SI_SPAWN
    PrintToChatAll("[HR] count_alive_survivors(): (BEFORE CLAMP!) g_alive_survivors = %i", g_alive_survivors);
    #endif

    // Clamp to max 4.
    if (g_alive_survivors > 4) {
        g_alive_survivors = 4;
    }

    #if DEBUG_SI_SPAWN
    PrintToChatAll("[HR] count_alive_survivors(): (AFTER CLAMP!) g_alive_survivors = %i", g_alive_survivors);
    #endif
}

void event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
    #if DEBUG_SI_SPAWN
    PrintToChatAll("[HR] event_player_left_safe_area()");
    #endif

    start_spawn_timer();
}

void start_spawn_timer()
{
    float interval = GetRandomFloat(g_si_min_spawn_interval, g_si_max_spawn_interval) + 0.05; // Round to one decimal place since min timer accuracy is 0.1s.
    g_spawn_timer = CreateTimer(interval, auto_spawn_si);

    #if DEBUG_SI_SPAWN
    PrintToChatAll("[HR] start_spawn_timer(): interval = %.2f", interval);
    #endif
}

void auto_spawn_si(Handle timer)
{
    // Count special infected.
    int si_type_counts[ZOMBIE_INDEX_SIZE];
    int si_total_count;
    for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {
            switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
                case ZOMBIE_CLASS_SMOKER: {
                    ++si_type_counts[ZOMBIE_INDEX_SMOKER];
                    ++si_total_count;
                }
                case ZOMBIE_CLASS_BOOMER: {
                    ++si_type_counts[ZOMBIE_INDEX_BOOMER];
                    ++si_total_count;
                }
                case ZOMBIE_CLASS_HUNTER: {
                    ++si_type_counts[ZOMBIE_INDEX_HUNTER];
                    ++si_total_count;
                }
                case ZOMBIE_CLASS_SPITTER: {
                    ++si_type_counts[ZOMBIE_INDEX_SPITTER];
                    ++si_total_count;
                }
                case ZOMBIE_CLASS_JOCKEY: {
                    ++si_type_counts[ZOMBIE_INDEX_JOCKEY];
                    ++si_total_count;
                }
                case ZOMBIE_CLASS_CHARGER: {
                    ++si_type_counts[ZOMBIE_INDEX_CHARGER];
                    ++si_total_count;
                }

                // Idealy should count only aggroed tanks.
                case ZOMBIE_CLASS_TANK: {

                    // Run VScript code.
                    int logic = CreateEntityByName("logic_script");
                    DispatchSpawn(logic);
                    SetVariantString("Convars.SetValue(\"hr_istankinplay\",Director.IsTankInPlay());");
                    AcceptEntityInput(logic, "RunScriptCode");
                    RemoveEntity(logic);

                    #if DEBUG_SI_SPAWN
                    PrintToChatAll("[HR] auto_spawn_si(): hr_istankinplay = %i", GetConVarInt(g_hr_istankinplay));
                    #endif

                    if (GetConVarBool(g_hr_istankinplay)) {
                        ++si_total_count;
                    }
                }

            }
        }
    }

    // Spawn special infected.
    if (si_total_count < g_si_max_spawn_size) {
        
        // Set spawn size.
        int size = g_si_max_spawn_size - si_total_count;
        if (size > g_si_min_spawn_size) {
            size = GetRandomInt(g_si_min_spawn_size, size);
        }

        #if DEBUG_SI_SPAWN
        PrintToChatAll("[HR] auto_spawn_si(): g_si_max_spawn_size = %i; si_total_count = %i; size = %i", g_si_max_spawn_size, si_total_count, size);
        #endif

        // Keep the same order as zombie classes.
        static const int si_spawn_limits[ZOMBIE_INDEX_SIZE] = { 2, 1, 2, 1, 2, 2 };
        static const int si_spawn_weights[ZOMBIE_INDEX_SIZE] = { 60, 100, 60, 100, 60, 60 };
        static const float si_spawn_weight_mods[ZOMBIE_INDEX_SIZE] = { 0.5, 1.0, 0.5, 1.0, 0.5, 0.5 };

        int tmp_weights[ZOMBIE_INDEX_SIZE];
        float delay;
        while (size) {

            // Calculate temporary weights and their weight sum, including reductions.
            int tmp_wsum;
            for (int i = 0; i < ZOMBIE_INDEX_SIZE; ++i) {
                if (si_type_counts[i] < si_spawn_limits[i]) {
                    tmp_weights[i] = si_spawn_weights[i];
                    int tmp_count = si_type_counts[i];
                    while (tmp_count) {
                        tmp_weights[i] = RoundToNearest(float(tmp_weights[i]) * si_spawn_weight_mods[i]);
                        --tmp_count;
                    }
                }
                else {
                    tmp_weights[i] = 0;
                }
                tmp_wsum += tmp_weights[i];
            }

            #if DEBUG_SI_SPAWN
            for (int i = 0; i < ZOMBIE_INDEX_SIZE; ++i) {
                PrintToChatAll("[HR] auto_spawn_si(): tmp_weights[%s] = %i", g_debug_si_indexes[i], tmp_weights[i]);
            }
            #endif

            int index = GetRandomInt(1, tmp_wsum);

            #if DEBUG_SI_SPAWN
            PrintToChatAll("[HR] auto_spawn_si(): index = %i", index);
            #endif

            // Cycle trough weight ranges, find where the random index falls and pick an appropriate array index.
            int range;
            for (int i = 0; i < ZOMBIE_INDEX_SIZE; ++i) {
                range += tmp_weights[i];
                if (index <= range) {
                    index = i;
                    ++si_type_counts[index];
                    break;
                }
            }

            #if DEBUG_SI_SPAWN
            PrintToChatAll("[HR] auto_spawn_si(): range = %i; tmp_wsum = %i; index = %s", range, tmp_wsum, g_debug_si_indexes[index]);
            #endif

            // Prevent instant spam of all specials at once.
            // Min and max delays are chosen more for technical reasons than gameplay reasons.
            delay += GetRandomFloat(0.4, 1.2) + 0.05; // Round to one decimal place since min timer accuracy is 0.1s.
            CreateTimer(delay, fake_z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);

            --size;
        }
    }

    #if DEBUG_SI_SPAWN
    else {
        PrintToConsoleAll("[HR] auto_spawn_si(): g_si_max_spawn_size = %i; si_total_count = %i; SI LIMIT REACHED!", g_si_max_spawn_size, si_total_count);
    }
    #endif

    // Restart the spawn timer.
    start_spawn_timer();
}

void fake_z_spawn_old(Handle timer, int data)
{	
    // Further delay spawn if special infected we wished to spawn was killed recently.
    if (g_si_recently_killed[data] > 0) {

        #if DEBUG_SI_SPAWN
        PrintToChatAll("[HR] fake_z_spawn_old(): g_si_recently_killed[%s] = %i; RECREATING TIMER AND RETURNING!", g_debug_si_indexes[data], g_si_recently_killed[data]);
        #endif

        CreateTimer(0.2, fake_z_spawn_old, data, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    // Get all alive survivors.
    int[] clients = new int[MaxClients];
    int client;
    for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i)) {
            clients[client++] = i; // We can't know who's last, so index will overflow!
        }
    }
    
    // If we have any alive survivors.
    if (client) {

        // Get random alive survivor.
        client = clients[GetRandomInt(0, client - 1)];
        
        // Create infected bot.
        // Without this we may not be able to spawn our special infected.
        int bot = CreateFakeClient("");
        if (bot) {
            ChangeClientTeam(bot, TEAM_INFECTED);
        }
        
        static const char z_spawn_old[] = "z_spawn_old";

        // Store command flags.
        int flags = GetCommandFlags(z_spawn_old);

        // Clear "sv_cheat" flag from the command.
        SetCommandFlags(z_spawn_old, flags & ~FCVAR_CHEAT);

        // Keep the same order as zombie classes.
        static const char z_spawns[ZOMBIE_INDEX_SIZE][] = { "z_spawn_old smoker auto", "z_spawn_old boomer auto", "z_spawn_old hunter auto", "z_spawn_old spitter auto", "z_spawn_old jockey auto", "z_spawn_old charger auto" };

        FakeClientCommand(client, z_spawns[data]);

        // Restore command flags.
        SetCommandFlags(z_spawn_old, flags);

        #if DEBUG_SI_SPAWN
        PrintToChatAll("[HR] fake_z_spawn_old(): client = %i [%N]; z_spawns[%s] = %s", client, client, g_debug_si_indexes[data], z_spawns[data]);
        #endif

        // Kick the bot.
        if (bot && IsClientConnected(bot)) {
            KickClient(bot);
        }
    }
}

void event_tank_spawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(userid);
    int tank_hp = RoundToNearest(g_tank_base_health * Pow(float(g_alive_survivors), 0.8));
    SetEntProp(client, Prop_Data, "m_iMaxHealth", tank_hp);
    SetEntProp(client, Prop_Data, "m_iHealth", tank_hp);

    // The constant factor was calculated from default values.
    SetConVarInt(FindConVar("tank_burn_duration_expert"), RoundToNearest(float(tank_hp) * 0.010625));

    SDKHook(client, SDKHook_OnTakeDamage, on_take_damage_tank);
    CreateTimer(0.2, set_tank_speed, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    #if DEBUG_TANK_HP
    PrintToChatAll("[HR] event_tank_spawn(): tank hp is %i", GetEntProp(client, Prop_Data, "m_iHealth"));
    PrintToChatAll("[HR] event_tank_spawn(): tank max hp is %i", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
    PrintToChatAll("[HR] event_tank_spawn(): tank burn time is %i", GetConVarInt(FindConVar("tank_burn_duration_expert")));
    #endif
}

Action on_take_damage_tank(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    // Melee damage to tank.
    //

    char classname[16];
    GetEdictClassname(inflictor, classname, sizeof(classname));
    
    // Melee should do one instance of damage larger than zero and multiple instances of zero damage,
    // so ignore zero damage.
    if (!strcmp(classname, "weapon_melee") && FloatAbs(damage) >= 0.000001) {
        damage = 400.0;
        
        #if DEBUG_DAMAGE_MOD
        debug_on_take_damage(victim, attacker, inflictor, damage);
        #endif
        
        return Plugin_Changed;
    }

    //
    
    #if DEBUG_DAMAGE_MOD
    debug_on_take_damage(victim, attacker, inflictor, damage);
    #endif

    return Plugin_Continue;
}

Action set_tank_speed(Handle timer, int data)
{
    int client = GetClientOfUserId(data);
    if (client) {
        if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE) {
            SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.24); // 260 units per second
        }
        else {
            SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
        }
        return Plugin_Continue;		
    }
    return Plugin_Stop;
}

void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
    on_end();
}

public void OnMapEnd()
{
    on_end();
}

void on_end()
{
    delete g_spawn_timer;
    for (int i = 0; i < ZOMBIE_INDEX_SIZE; ++i) {
        g_si_recently_killed[i] = 0;
    }
}

public void OnServerEnterHibernation()
{
    g_difficulty = 0;
    set_normal_difficulty();
}

#if DEBUG_DAMAGE_MOD
void debug_on_take_damage(int victim, int attacker, int inflictor, float damage)
{
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker)) {
        char classname[32];
        if (attacker == inflictor) {
            GetClientWeapon(inflictor, classname, sizeof(classname));
        }
        else {
            GetEdictClassname(inflictor, classname, sizeof(classname));
        }
        if (victim > 0 && victim <= MaxClients && IsClientInGame(victim)) {
            PrintToChatAll("%N (%s) %.2f dmg to %N", attacker, classname, damage, victim);
        }
        else {
            PrintToChatAll("%N (%s) %.2f dmg to victim %i", attacker, classname, damage, victim);
        }
    }
}
#endif