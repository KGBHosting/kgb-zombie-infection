/*
 * KGB Zombie Infection
 * Copyright (C) 2026 KGB Hosting
 *
 * Derived from KGB Zombie Escape Core 0.1.3 (GPL-3.0-or-later):
 * https://github.com/KGBHosting/kgb-zombie-escape-core/tree/9e4b308195a97b7b2b2a67d23dd2d3a991fea872
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version. This program comes WITHOUT ANY WARRANTY. See LICENSE.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <reapi>

#define PLUGIN_NAME "KGB Zombie Infection"
#define PLUGIN_VERSION "0.1.1"
#define PLUGIN_AUTHOR "KGB Hosting"
#define TASK_TICK 72100

enum RoundPhase { WAITING, PREPARING, INFECTED, ENDING }
new RoundPhase:g_phase = WAITING
new g_max_players
new bool:g_is_zombie[33]
new bool:g_departing[33]
new Float:g_respawn_at[33]
new Float:g_infection_at
new Float:g_survival_until
new g_hud
new g_cvar_min_players, g_cvar_infection_delay, g_cvar_survival_time
new g_cvar_zombie_ratio, g_cvar_zombie_health, g_cvar_zombie_speed, g_cvar_zombie_gravity
new g_cvar_human_health, g_cvar_human_armor, g_cvar_respawn_delay
new g_cvar_display_name, g_cvar_chat_prefix

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    g_cvar_min_players = register_cvar("kgb_zi_min_players", "2")
    g_cvar_infection_delay = register_cvar("kgb_zi_infection_delay", "15.0")
    g_cvar_survival_time = register_cvar("kgb_zi_survival_time", "180.0")
    g_cvar_zombie_ratio = register_cvar("kgb_zi_zombie_ratio", "0.20")
    g_cvar_zombie_health = register_cvar("kgb_zi_zombie_health", "3000")
    g_cvar_zombie_speed = register_cvar("kgb_zi_zombie_speed", "300.0")
    g_cvar_zombie_gravity = register_cvar("kgb_zi_zombie_gravity", "0.80")
    g_cvar_human_health = register_cvar("kgb_zi_human_health", "100")
    g_cvar_human_armor = register_cvar("kgb_zi_human_armor", "50")
    g_cvar_respawn_delay = register_cvar("kgb_zi_respawn_delay", "3.0")
    g_cvar_display_name = register_cvar("kgb_zi_display_name", "Zombie Infection")
    g_cvar_chat_prefix = register_cvar("kgb_zi_chat_prefix", "[Zombie Infection]")

    register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
    register_event("CurWeapon", "on_current_weapon", "be", "1=1")
    register_logevent("on_round_end", 2, "1=Round_End")
    RegisterHam(Ham_Spawn, "player", "on_player_spawn_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "on_take_damage_pre", 0)
    RegisterHam(Ham_Killed, "player", "on_player_killed_post", 1)
    register_forward(FM_PlayerPreThink, "on_player_prethink")

    register_clcmd("say /zombie", "command_player_status")
    register_clcmd("say_team /zombie", "command_player_status")
    register_concmd("amx_zi_status", "command_admin_status", ADMIN_CFG)
    register_concmd("amx_zi_infect", "command_admin_infect", ADMIN_CFG, "<name or #userid> (active infection only)")
    register_clcmd("buy", "command_block_buy")
    register_clcmd("autobuy", "command_block_buy")
    register_clcmd("rebuy", "command_block_buy")
    register_clcmd("cl_autobuy", "command_block_buy")
    register_clcmd("cl_rebuy", "command_block_buy")
    // Direct jointeam, VGUI and legacy menuselect all reach this engine hook.
    RegisterHookChain(RG_HandleMenu_ChooseTeam, "on_choose_team_pre", false)

    g_max_players = get_maxplayers()
    g_hud = CreateHudSyncObj()
}

public plugin_cfg()
{
    server_cmd("exec addons/amxmodx/configs/kgb_zombie_infection.cfg")
    server_exec()
    new pointer = get_cvar_pointer("mp_round_infinite")
    if (!pointer || get_pcvar_num(pointer) != 1)
    {
        set_fail_state("Zombie Infection requires ReGameDLL_CS and mp_round_infinite 1; native objectives must not end infection rounds.")
        return
    }
    // One recurring clock owns every deadline. No round or slot-specific task
    // callbacks can survive a reset, disconnect, spectator switch or slot reuse.
    set_task(1.0, "round_tick", TASK_TICK, "", 0, "b")
}

public client_putinserver(id)
{
    g_departing[id] = false
    g_is_zombie[id] = false
    g_respawn_at[id] = 0.0
}

public client_disconnected(id)
{
    // Exclude the departing slot until the next client fully enters it.
    g_departing[id] = true
    g_is_zombie[id] = false
    g_respawn_at[id] = 0.0
}

public on_new_round()
{
    g_phase = WAITING
    g_infection_at = 0.0
    g_survival_until = 0.0
    for (new id = 1; id <= g_max_players; id++)
    {
        g_is_zombie[id] = false
        g_respawn_at[id] = 0.0
    }
}

public on_round_end()
{
    g_phase = ENDING
    clear_respawns()
}

public round_tick()
{
    if (g_phase == ENDING)
    {
        return
    }
    new Float:now = get_gametime()
    process_respawns(now)
    new humans, zombies, participants
    count_roles(humans, zombies, participants)

    if (g_phase == WAITING)
    {
        new minimum = clamp(get_pcvar_num(g_cvar_min_players), 2, g_max_players)
        if (humans < minimum || get_member_game(m_bFreezePeriod))
        {
            show_status(humans, zombies)
            return
        }
        g_phase = PREPARING
        g_infection_at = now + floatclamp(get_pcvar_float(g_cvar_infection_delay), 3.0, 120.0)
        announce("Infection begins in %.0f seconds. Survive together; zombies infect with their knife.", g_infection_at - now)
    }
    else if (g_phase == PREPARING)
    {
        if (humans < clamp(get_pcvar_num(g_cvar_min_players), 2, g_max_players))
        {
            g_phase = WAITING
            g_infection_at = 0.0
            announce("Waiting for more players. The preparation countdown will restart.")
        }
        else if (now >= g_infection_at)
        {
            begin_infection(now)
        }
    }
    else if (g_phase == INFECTED)
    {
        // Dead zombies waiting to respawn remain participants, so killing the
        // last living zombie cannot incorrectly award the humans a victory.
        if (humans == 0)
        {
            finish_round(participants > 0 ? WINSTATUS_TERRORISTS : WINSTATUS_DRAW)
        }
        else if (participants == humans || now >= g_survival_until)
        {
            finish_round(WINSTATUS_CTS)
        }
    }
    if (g_phase != ENDING)
    {
        count_roles(humans, zombies, participants)
        show_status(humans, zombies)
    }
}

stock begin_infection(Float:now)
{
    new players[32], player_count
    for (new id = 1; id <= g_max_players; id++)
    {
        if (is_participant(id) && is_user_alive(id))
        {
            players[player_count++] = id
        }
    }
    if (player_count < 2)
    {
        g_phase = WAITING
        return
    }
    new Float:ratio = floatclamp(get_pcvar_float(g_cvar_zombie_ratio), 0.05, 0.90)
    new initial = clamp(floatround(float(player_count) * ratio, floatround_ceil), 1, player_count - 1)
    for (new index = player_count - 1; index > 0; index--)
    {
        new swap_index = random_num(0, index)
        new swap_value = players[index]
        players[index] = players[swap_index]
        players[swap_index] = swap_value
    }
    g_phase = INFECTED
    g_survival_until = now + floatclamp(get_pcvar_float(g_cvar_survival_time), 15.0, 1800.0)
    for (new index = 0; index < initial; index++)
    {
        make_zombie(players[index], 0)
    }
    announce("%d initial zombie%s! Humans win by surviving %.0f seconds; zombies win by infecting every human.", initial, initial == 1 ? "" : "s", g_survival_until - now)
    log_amx("[ZI] infection_started humans=%d zombies=%d duration=%.0f", player_count - initial, initial, g_survival_until - now)
}

public on_player_spawn_post(id)
{
    if (!is_participant(id) || !is_user_alive(id) || g_phase == ENDING)
    {
        return HAM_IGNORED
    }
    g_respawn_at[id] = 0.0
    if (g_phase == INFECTED)
    {
        make_zombie(id, 0)
    }
    else
    {
        make_human(id)
    }
    return HAM_IGNORED
}

public on_take_damage_pre(victim, inflictor, attacker, Float:damage, damage_bits)
{
    if (g_phase != INFECTED || attacker < 1 || attacker > g_max_players || attacker == victim)
    {
        return HAM_IGNORED
    }
    if (!is_participant(attacker) || !is_participant(victim) || !is_user_alive(attacker) || !is_user_alive(victim))
    {
        return HAM_IGNORED
    }
    if (g_is_zombie[attacker] && !g_is_zombie[victim] && inflictor == attacker && get_user_weapon(attacker) == CSW_KNIFE && (damage_bits & DMG_BULLET))
    {
        // ReGameDLL knife.cpp uses DMG_BULLET | DMG_NEVERGIB, not DMG_SLASH.
        make_zombie(victim, attacker)
        SetHamParamFloat(4, 0.0)
        new humans, zombies, participants
        count_roles(humans, zombies, participants)
        if (humans == 0)
        {
            finish_round(WINSTATUS_TERRORISTS)
        }
        return HAM_SUPERCEDE
    }
    return HAM_IGNORED
}

public on_player_killed_post(victim, attacker, should_gib)
{
    if (g_phase == ENDING || !is_participant(victim))
    {
        return HAM_IGNORED
    }
    g_respawn_at[victim] = get_gametime() + respawn_delay()
    if (g_phase == INFECTED)
    {
        g_is_zombie[victim] = true
    }
    return HAM_IGNORED
}

stock process_respawns(Float:now)
{
    for (new id = 1; id <= g_max_players; id++)
    {
        if (!is_participant(id) || is_user_alive(id) || get_member(id, m_iJoiningState) != JOINED)
        {
            g_respawn_at[id] = 0.0
            continue
        }
        if (g_respawn_at[id] == 0.0)
        {
            // Late joining players and preparation deaths also recover.
            g_respawn_at[id] = now + respawn_delay()
        }
        if (now >= g_respawn_at[id])
        {
            g_respawn_at[id] = 0.0
            cs_set_user_team(id, g_phase == INFECTED ? CS_TEAM_T : CS_TEAM_CT)
            ExecuteHamB(Ham_CS_RoundRespawn, id)
        }
    }
}

public on_current_weapon(id)
{
    if (g_phase != ENDING && is_user_alive(id) && g_is_zombie[id] && read_data(2) != CSW_KNIFE)
    {
        strip_user_weapons(id)
        give_item(id, "weapon_knife")
    }
}

public on_player_prethink(id)
{
    if (g_phase == INFECTED && is_user_alive(id) && g_is_zombie[id])
    {
        set_pev(id, pev_maxspeed, floatclamp(get_pcvar_float(g_cvar_zombie_speed), 150.0, 400.0))
    }
    return FMRES_IGNORED
}

public command_block_buy(id)
{
    return PLUGIN_HANDLED
}

public on_choose_team_pre(id, MenuChooseTeam:slot)
{
    if (g_phase == INFECTED && is_participant(id) && slot != MenuChoose_Spec)
    {
        client_print(id, print_chat, "Use /zombie for the rules. Team changes resume next round; you can still spectate.")
        SetHookChainReturn(ATYPE_BOOL, false)
        return HC_SUPERCEDE
    }
    return HC_CONTINUE
}

public command_player_status(id)
{
    if (!is_user_connected(id))
    {
        return PLUGIN_HANDLED
    }
    new humans, zombies, participants, prefix[48]
    count_roles(humans, zombies, participants)
    get_pcvar_string(g_cvar_chat_prefix, prefix, charsmax(prefix))
    client_print(id, print_chat, "%s Humans survive until time runs out. Zombies infect with their knife and respawn after death. Late joins become zombies.", prefix)
    client_print(id, print_chat, "%s Humans alive: %d | Zombies alive: %d | Your role: %s", prefix, humans, zombies, !is_participant(id) ? "spectator" : (g_is_zombie[id] ? "zombie" : "human"))
    return PLUGIN_HANDLED
}

public command_admin_status(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED
    }
    new humans, zombies, participants
    count_roles(humans, zombies, participants)
    console_print(id, "[ZI] version=%s phase=%d humans_alive=%d zombies_alive=%d participants=%d remaining=%.0f", PLUGIN_VERSION, g_phase, humans, zombies, participants, g_phase == INFECTED ? floatmax(0.0, g_survival_until - get_gametime()) : 0.0)
    return PLUGIN_HANDLED
}

public command_admin_infect(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED
    }
    if (g_phase != INFECTED)
    {
        console_print(id, "[ZI] Infection controls are available only during an active infection round.")
        return PLUGIN_HANDLED
    }
    new argument[32]
    read_argv(1, argument, charsmax(argument))
    new target = cmd_target(id, argument, CMDTARGET_ALLOW_SELF | CMDTARGET_ONLY_ALIVE)
    if (target && is_participant(target) && !g_is_zombie[target])
    {
        make_zombie(target, 0)
        log_amx("[ZI] admin infection requested by userid=%d target_userid=%d", id > 0 ? get_user_userid(id) : 0, get_user_userid(target))
        // Reconcile on the next tick, after the command completes.
    }
    return PLUGIN_HANDLED
}

stock make_human(id)
{
    g_is_zombie[id] = false
    cs_set_user_team(id, CS_TEAM_CT)
    cs_reset_user_model(id)
    strip_user_weapons(id)
    give_item(id, "weapon_knife")
    give_item(id, "weapon_m4a1")
    give_item(id, "weapon_usp")
    cs_set_user_bpammo(id, CSW_M4A1, 90)
    cs_set_user_bpammo(id, CSW_USP, 100)
    set_user_health(id, clamp(get_pcvar_num(g_cvar_human_health), 1, 1000))
    cs_set_user_armor(id, clamp(get_pcvar_num(g_cvar_human_armor), 0, 1000), CS_ARMOR_VESTHELM)
    set_user_gravity(id, 1.0)
    set_user_rendering(id)
}

stock make_zombie(id, infector)
{
    g_is_zombie[id] = true
    cs_set_user_team(id, CS_TEAM_T)
    cs_reset_user_model(id)
    strip_user_weapons(id)
    give_item(id, "weapon_knife")
    set_user_health(id, clamp(get_pcvar_num(g_cvar_zombie_health), 100, 100000))
    cs_set_user_armor(id, 0, CS_ARMOR_NONE)
    set_user_gravity(id, floatclamp(get_pcvar_float(g_cvar_zombie_gravity), 0.25, 1.0))
    set_user_rendering(id, kRenderFxGlowShell, 80, 180, 80, kRenderNormal, 8)
    if (infector > 0)
    {
        announce("A human has been infected! Humans remaining must survive together.")
    }
}

stock bool:is_participant(id)
{
    if (g_departing[id] || !is_user_connected(id) || is_user_hltv(id))
    {
        return false
    }
    new CsTeams:team = cs_get_user_team(id)
    return team == CS_TEAM_T || team == CS_TEAM_CT
}

stock count_roles(&humans, &zombies, &participants)
{
    humans = 0
    zombies = 0
    participants = 0
    for (new id = 1; id <= g_max_players; id++)
    {
        if (!is_participant(id))
        {
            continue
        }
        participants++
        if (!is_user_alive(id))
        {
            continue
        }
        if (g_is_zombie[id]) zombies++
        else humans++
    }
}

stock finish_round(WinStatus:winner)
{
    if (g_phase != INFECTED)
    {
        return
    }
    g_phase = ENDING
    clear_respawns()
    ClearSyncHud(0, g_hud)
    if (winner == WINSTATUS_CTS)
    {
        announce("Humans win! They survived the infection or all zombies left.")
        rg_round_end(3.0, WINSTATUS_CTS, ROUND_CTS_WIN)
    }
    else if (winner == WINSTATUS_TERRORISTS)
    {
        announce("Zombies win! No living humans remain.")
        rg_round_end(3.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN)
    }
    else
    {
        announce("Round drawn: no players remain.")
        rg_round_end(3.0, WINSTATUS_DRAW, ROUND_END_DRAW)
    }
    log_amx("[ZI] round_end winner=%d", winner)
}

stock clear_respawns()
{
    for (new id = 1; id <= g_max_players; id++) g_respawn_at[id] = 0.0
}

stock Float:respawn_delay()
{
    return floatclamp(get_pcvar_float(g_cvar_respawn_delay), 1.0, 30.0)
}

stock show_status(humans, zombies)
{
    new display_name[64]
    get_pcvar_string(g_cvar_display_name, display_name, charsmax(display_name))
    set_hudmessage(100, 220, 100, -1.0, 0.12, 0, 0.0, 1.1, 0.0, 0.0)
    if (g_phase == WAITING)
    {
        ShowSyncHudMsg(0, g_hud, "%s^nWaiting for %d players | Type /zombie for rules", display_name, clamp(get_pcvar_num(g_cvar_min_players), 2, g_max_players))
    }
    else if (g_phase == PREPARING)
    {
        ShowSyncHudMsg(0, g_hud, "%s^nInitial infection in %d | Move and prepare!", display_name, floatround(floatmax(0.0, g_infection_at - get_gametime()), floatround_ceil))
    }
    else
    {
        new remaining = floatround(floatmax(0.0, g_survival_until - get_gametime()), floatround_ceil)
        ShowSyncHudMsg(0, g_hud, "%s^nHumans: %d | Zombies: %d | Survive: %d:%02d", display_name, humans, zombies, remaining / 60, remaining % 60)
    }
}

stock announce(const format[], any:...)
{
    new message[190], prefix[48]
    vformat(message, charsmax(message), format, 2)
    get_pcvar_string(g_cvar_chat_prefix, prefix, charsmax(prefix))
    client_print(0, print_chat, "%s %s", prefix, message)
}
