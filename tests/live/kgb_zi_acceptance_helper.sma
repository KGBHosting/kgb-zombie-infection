// SPDX-License-Identifier: GPL-3.0-or-later
// DEVELOPMENT TEST INSTRUMENTATION ONLY. Never enable on customer servers.
// Stationary engine fake-clients are explicitly labeled TEST DOUBLES. They
// exercise normal product spawn/damage/disconnect paths, not human onboarding.
// Only the test operator's real Valve client attacks. No damage/death messages,
// infection calls, role assignment or real-client state changes are synthesized.
#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <reapi>

#define HELPER_VERSION "0.1.0-test"
#define MAX_TEST_CLIENTS 3

new g_owned_userid[33], g_spawn_userid[33]
new g_real_prethink[33], g_spawns[33], g_deaths[33]
new Float:g_next_attack_log[33], Float:g_next_damage_log[33]
new Float:g_next_fake_move
new g_fake_serial

public plugin_init()
{
    register_plugin("ZI acceptance helper (TEST ONLY)", HELPER_VERSION, "KGB Hosting")
    // These are server-console commands, not client/admin commands.
    register_srvcmd("ziqa_add", "command_add")
    register_srvcmd("ziqa_list", "command_list")
    register_srvcmd("ziqa_snapshot", "command_snapshot")
    register_srvcmd("ziqa_place", "command_place")
    register_srvcmd("ziqa_health", "command_health")
    register_srvcmd("ziqa_drop", "command_drop")
    register_srvcmd("ziqa_clear", "command_clear")
    register_event("HLTV", "on_round", "a", "1=0", "2=0")
    register_logevent("on_round_end", 2, "1=Round_End")
    register_event("DeathMsg", "on_death", "a")
    register_event("TeamScore", "on_team_score", "a")
    RegisterHam(Ham_Spawn, "player", "on_spawn_pre")
    RegisterHam(Ham_Spawn, "player", "on_spawn_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "on_damage_post", 1)
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m4a1", "on_primary_attack_post", 1)
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "on_primary_attack_post", 1)
    RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "on_primary_attack_post", 1)
    RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "on_secondary_attack_post", 1)
    register_forward(FM_StartFrame, "on_frame")
    register_forward(FM_PlayerPreThink, "on_prethink")
}

public client_putinserver(id)
{
    g_owned_userid[id] = g_spawn_userid[id] = 0
    g_real_prethink[id] = g_spawns[id] = g_deaths[id] = 0
    g_next_attack_log[id] = g_next_damage_log[id] = 0.0
}

public client_disconnected(id)
{
    server_print("[ZIQA] disconnect slot=%d owned_test_double=%d time=%.2f", id, g_owned_userid[id] > 0, get_gametime())
    g_owned_userid[id] = g_spawn_userid[id] = 0
}

// Positive ephemeral user ID + fake flag prevent a reused slot ever becoming
// an instrumentation target. Never identify ownership by slot/name alone.
stock bool:is_owned_fake(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id)
        && g_owned_userid[id] > 0 && get_user_userid(id) == g_owned_userid[id]
        && (pev(id, pev_flags) & FL_FAKECLIENT) != 0
}

stock argument_player(position)
{
    new argument[16]
    read_argv(position, argument, charsmax(argument))
    new userid = str_to_num(argument)
    return userid > 0 ? find_player("k", userid) : 0
}

stock owned_count()
{
    new count
    for (new id = 1; id <= MaxClients; id++) if (is_owned_fake(id)) count++
    return count
}

public command_add()
{
    new argument[8]
    read_argv(1, argument, charsmax(argument))
    new count = str_to_num(argument)
    if (read_argc() != 2 || count < 1 || count > MAX_TEST_CLIENTS || owned_count() + count > MAX_TEST_CLIENTS)
    {
        server_print("[ZIQA] ERROR ziqa_add <1..3>; at most three owned stationary TEST DOUBLES")
        return
    }
    for (new index = 0; index < count; index++)
    {
        new name[48], reject[128]
        formatex(name, charsmax(name), "ZI-QA stationary TEST DOUBLE %d", ++g_fake_serial)
        new id = engfunc(EngFunc_CreateFakeClient, name)
        if (!id)
        {
            server_print("[ZIQA] ERROR no free fake-client slot; creation stopped")
            break
        }
        // Only the just-created engine fake client is initialized here. The
        // actual human must complete Valve's team/class/Join state naturally.
        engfunc(EngFunc_FreeEntPrivateData, id)
        dllfunc(DLLFunc_ClientConnect, id, name, "127.0.0.1", reject, charsmax(reject))
        dllfunc(DLLFunc_ClientPutInServer, id)
        set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT | FL_FROZEN)
        g_owned_userid[id] = get_user_userid(id)
        if (!is_owned_fake(id))
        {
            server_print("[ZIQA] ERROR new fake-client identity unavailable; no spawn initialization")
            break
        }
        // Initial test-double enrollment only. Product Ham_Spawn assigns the
        // phase-appropriate team, weapons, model/render, health and gravity.
        cs_set_user_team(id, CS_TEAM_CT, CS_CT_GIGN)
        set_member(id, m_iJoiningState, JOINED)
        set_member(id, m_fLastMovement, get_gametime())
        ExecuteHamB(Ham_CS_RoundRespawn, id)
        if (!is_owned_fake(id))
        {
            server_print("[ZIQA] ERROR fake-client identity changed during spawn")
            break
        }
        server_print("[ZIQA] created stationary TEST DOUBLE slot=%d userid=%d time=%.2f", id, g_owned_userid[id], get_gametime())
        dump_player(id)
    }
}

public on_spawn_pre(id)
{
    g_spawn_userid[id] = is_owned_fake(id) ? g_owned_userid[id] : 0
    return HAM_IGNORED
}

public on_spawn_post(id)
{
    // Spawn clears engine flags; restore them only for the previously owned
    // fake's exact positive user ID, never for a human reusing its slot.
    if (g_spawn_userid[id] > 0 && is_user_connected(id)
        && get_user_userid(id) == g_spawn_userid[id] && g_owned_userid[id] == g_spawn_userid[id])
    {
        set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT | FL_FROZEN)
        set_member(id, m_fLastMovement, get_gametime())
    }
    g_spawn_userid[id] = 0
    if (is_user_alive(id))
    {
        g_spawns[id]++
        server_print("[ZIQA] engine spawn slot=%d team=%d health=%d owned_test_double=%d count=%d time=%.2f", id, get_member(id, m_iTeam), get_user_health(id), is_owned_fake(id), g_spawns[id], get_gametime())
    }
    return HAM_IGNORED
}

public on_frame()
{
    new Float:now = get_gametime()
    if (now < g_next_fake_move) return FMRES_IGNORED
    g_next_fake_move = now + 0.05
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_owned_fake(id)) continue
        new Float:angles[3]
        pev(id, pev_v_angle, angles)
        // Explicitly stationary/idle-safe test double. Zero buttons means no
        // fake weapon attack; no input or activity state of humans is changed.
        set_member(id, m_fLastMovement, now)
        engfunc(EngFunc_RunPlayerMove, id, angles, 0.0, 0.0, 0.0, 0, 0, 50)
    }
    return FMRES_IGNORED
}

public on_prethink(id)
{
    if (is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id)) g_real_prethink[id]++
    return FMRES_IGNORED
}

public command_list()
{
    dump_round("snapshot")
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        server_print("[ZIQA] participant slot=%d userid=%d bot=%d owned_test_double=%d alive=%d team=%d joining=%d", id, get_user_userid(id), is_user_bot(id), is_owned_fake(id), is_user_alive(id), get_member(id, m_iTeam), get_member(id, m_iJoiningState))
    }
    server_cmd("amx_zi_status")
    server_exec()
}

public command_snapshot()
{
    new id = argument_player(1)
    if (read_argc() != 2 || !is_user_connected(id))
    {
        server_print("[ZIQA] ERROR ziqa_snapshot <ephemeral-userid>; player must be connected")
        return
    }
    dump_round("snapshot")
    dump_player(id)
}

stock dump_player(id)
{
    new weapons[32], count, model[64], entity_model[128]
    new Float:gravity, Float:speed, Float:health, Float:render_amount, Float:render_color[3]
    get_user_weapons(id, weapons, count)
    cs_get_user_model(id, model, charsmax(model))
    pev(id, pev_model, entity_model, charsmax(entity_model))
    pev(id, pev_gravity, gravity)
    pev(id, pev_maxspeed, speed)
    pev(id, pev_health, health)
    pev(id, pev_renderamt, render_amount)
    pev(id, pev_rendercolor, render_color)
    new active = get_member(id, m_pActiveItem), actual_weapon
    if (active > 0 && pev_valid(active)) actual_weapon = get_member(active, m_iId)
    new Float:protection_until = get_member(id, m_flSpawnProtectionEndTime)
    server_print("[ZIQA] player slot=%d userid=%d alive=%d team=%d joining=%d menu=%d just_connected=%d observer=%d real_prethink=%d time=%.2f", id, get_user_userid(id), is_user_alive(id), get_member(id, m_iTeam), get_member(id, m_iJoiningState), get_member(id, m_iMenu), get_member(id, m_bJustConnected), pev(id, pev_iuser1), g_real_prethink[id], get_gametime())
    server_print("[ZIQA] stats health=%.1f armor=%d armor_type=%d gravity=%.2f maxspeed=%.1f cached_weapon=%d actual_weapon=%d weapons=%d spawns=%d deaths=%d protection_until=%.2f", health, get_user_armor(id), get_member(id, m_iKevlar), gravity, speed, get_user_weapon(id), actual_weapon, count, g_spawns[id], g_deaths[id], protection_until)
    server_print("[ZIQA] visuals model=%s entity_model=%s modelindex=%d render_fx=%d render_mode=%d render_amount=%.1f color=(%.1f %.1f %.1f) flags=%d solid=%d deadflag=%d", model, entity_model, pev(id, pev_modelindex), pev(id, pev_renderfx), pev(id, pev_rendermode), render_amount, render_color[0], render_color[1], render_color[2], pev(id, pev_flags), pev(id, pev_solid), pev(id, pev_deadflag))
    for (new index = 0; index < count; index++)
    {
        new weapon_name[32]
        get_weaponname(weapons[index], weapon_name, charsmax(weapon_name))
        // Knife has no ammo index; asking CStrike for its reserve is an error.
        new reserve
        if (weapons[index] == CSW_M4A1 || weapons[index] == CSW_USP) reserve = cs_get_user_bpammo(id, weapons[index])
        server_print("[ZIQA] inventory slot=%d weapon=%s reserve=%d", id, weapon_name, reserve)
    }
}

public command_place()
{
    new target = argument_player(1), human = argument_player(2)
    if (read_argc() < 3 || read_argc() > 4 || !is_owned_fake(target) || !is_user_alive(target)
        || !is_user_alive(human) || is_user_bot(human) || is_user_hltv(human))
    {
        server_print("[ZIQA] ERROR ziqa_place <owned-fake-userid> <real-userid> [40..500 distance]; both must be alive")
        return
    }
    new Float:distance = 45.0
    if (read_argc() == 4)
    {
        new argument[16]
        read_argv(3, argument, charsmax(argument))
        distance = str_to_float(argument)
    }
    if (distance < 40.0 || distance > 500.0)
    {
        server_print("[ZIQA] ERROR distance must be 40..500 units")
        return
    }
    new Float:origin[3], Float:view[3], Float:aim[3], Float:destination[3]
    pev(human, pev_origin, origin)
    pev(human, pev_v_angle, view)
    view[0] = 0.0
    engfunc(EngFunc_MakeVectors, view)
    global_get(glb_v_forward, aim)
    for (new axis = 0; axis < 3; axis++) destination[axis] = origin[axis] + aim[axis] * distance
    new trace = create_tr2()
    engfunc(EngFunc_TraceHull, destination, destination, DONT_IGNORE_MONSTERS, HULL_HUMAN, target, trace)
    new blocked = get_tr2(trace, TR_StartSolid) || get_tr2(trace, TR_AllSolid)
    free_tr2(trace)
    if (blocked)
    {
        server_print("[ZIQA] ERROR fake position blocked; no player moved")
        return
    }
    // Identity was checked above. Only the owned fake moves; no role, weapon,
    // health, model, gravity, human position or human view state is changed.
    engfunc(EngFunc_SetOrigin, target, destination)
    set_pev(target, pev_velocity, Float:{0.0, 0.0, 0.0})
    set_pev(target, pev_flags, pev(target, pev_flags) | FL_FROZEN)
    server_print("[ZIQA] moved owned TEST DOUBLE slot=%d distance=%.1f; product role/stats untouched; wait for normal spawn protection", target, distance)
    dump_player(target)
    trace_aim(human, target)
}

stock trace_aim(human, target)
{
    new Float:eye[3], Float:offset[3], Float:view[3], Float:aim[3], Float:end[3]
    pev(human, pev_origin, eye)
    pev(human, pev_view_ofs, offset)
    for (new axis = 0; axis < 3; axis++) eye[axis] += offset[axis]
    pev(human, pev_v_angle, view)
    engfunc(EngFunc_MakeVectors, view)
    global_get(glb_v_forward, aim)
    for (new axis = 0; axis < 3; axis++) end[axis] = eye[axis] + aim[axis] * 8192.0
    new trace = create_tr2()
    engfunc(EngFunc_TraceLine, eye, end, DONT_IGNORE_MONSTERS, human, trace)
    new Float:fraction
    get_tr2(trace, TR_flFraction, fraction)
    server_print("[ZIQA] real crosshair hit=%d expected_test_slot=%d hitgroup=%d fraction=%.3f time=%.2f", get_tr2(trace, TR_pHit), target, get_tr2(trace, TR_iHitgroup), fraction, get_gametime())
    free_tr2(trace)
}

public command_health()
{
    new target = argument_player(1), argument[16]
    read_argv(2, argument, charsmax(argument))
    new health = str_to_num(argument)
    if (read_argc() != 3 || !is_owned_fake(target) || !is_user_alive(target) || health < 1 || health > 100000)
    {
        server_print("[ZIQA] ERROR ziqa_health <owned-fake-userid> <1..100000>; never changes a real client")
        return
    }
    // Optional labeled fixture setup AFTER default product stats were captured.
    // No damage is applied; subsequent death requires an actual client attack.
    server_print("[ZIQA] TEST FIXTURE health override slot=%d before=%d after=%d; not default-loadout evidence", target, get_user_health(target), health)
    set_user_health(target, health)
}

stock kick_owned_fake(id)
{
    if (!is_owned_fake(id)) return
    server_print("[ZIQA] disconnecting owned TEST DOUBLE slot=%d userid=%d time=%.2f", id, g_owned_userid[id], get_gametime())
    server_cmd("kick #%d", g_owned_userid[id])
    server_exec()
}

public command_drop()
{
    new target = argument_player(1)
    if (read_argc() != 2 || !is_owned_fake(target))
    {
        server_print("[ZIQA] ERROR ziqa_drop <owned-fake-userid>; identity guard refused")
        return
    }
    kick_owned_fake(target)
}

public command_clear()
{
    for (new id = 1; id <= MaxClients; id++) kick_owned_fake(id)
}

public on_death()
{
    new victim = read_data(2), weapon[32]
    read_data(4, weapon, charsmax(weapon))
    if (victim >= 1 && victim <= MaxClients) g_deaths[victim]++
    server_print("[ZIQA] ENGINE DeathMsg killer_slot=%d victim_slot=%d weapon=%s time=%.2f", read_data(1), victim, weapon, get_gametime())
}

public on_damage_post(victim, inflictor, attacker, Float:damage, damage_bits)
{
    if (!is_owned_fake(victim) || attacker < 1 || attacker > MaxClients
        || !is_user_connected(attacker) || is_user_bot(attacker) || is_user_hltv(attacker)) return HAM_IGNORED
    new Float:now = get_gametime()
    new bool:knife = get_user_weapon(attacker) == CSW_KNIFE
    if (!knife && now < g_next_damage_log[victim]) return HAM_IGNORED
    g_next_damage_log[victim] = now + 0.2
    new Float:health
    pev(victim, pev_health, health)
    server_print("[ZIQA] actual client damage post attacker_slot=%d victim_slot=%d inflictor=%d damage_arg=%.2f damagebits=%d alive=%d team_after=%d health_after=%.1f deaths=%d time=%.2f", attacker, victim, inflictor, damage, damage_bits, is_user_alive(victim), get_member(victim, m_iTeam), health, g_deaths[victim], now)
    return HAM_IGNORED
}

stock log_attack(weapon, const attack[])
{
    if (!pev_valid(weapon)) return
    new owner = get_member(weapon, m_pPlayer)
    if (owner < 1 || owner > MaxClients || !is_user_connected(owner)
        || is_user_bot(owner) || is_user_hltv(owner)) return
    new Float:now = get_gametime()
    new item = get_member(weapon, m_iId)
    if (item != CSW_KNIFE && now < g_next_attack_log[owner]) return
    g_next_attack_log[owner] = now + 0.2
    server_print("[ZIQA] actual client %s slot=%d weapon=%d clip_after=%d time=%.2f", attack, owner, item, get_member(weapon, m_Weapon_iClip), now)
}

public on_primary_attack_post(weapon) { log_attack(weapon, "primary_attack"); return HAM_IGNORED; }
public on_secondary_attack_post(weapon) { log_attack(weapon, "secondary_attack"); return HAM_IGNORED; }
public on_round() { dump_round("ENGINE new_round"); }
public on_round_end() { dump_round("ENGINE Round_End"); }

public on_team_score()
{
    new team[16]
    read_data(1, team, charsmax(team))
    server_print("[ZIQA] ENGINE TeamScore team=%s score=%d time=%.2f", team, read_data(2), get_gametime())
}

stock dump_round(const label[])
{
    server_print("[ZIQA] %s ct_score=%d t_score=%d winstatus=%d terminating=%d freeze=%d game_started=%d restart_at=%.2f time=%.2f", label, get_member_game(m_iNumCTWins), get_member_game(m_iNumTerroristWins), get_member_game(m_iRoundWinStatus), get_member_game(m_bRoundTerminating), get_member_game(m_bFreezePeriod), get_member_game(m_bGameStarted), Float:get_member_game(m_flRestartRoundTime), get_gametime())
}
