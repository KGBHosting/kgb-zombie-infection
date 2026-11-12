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
#define PLUGIN_VERSION "0.2.1"
#define PLUGIN_AUTHOR "KGB Hosting"
#define TASK_TICK 72100
#define NO_WEAPON_MENU -1
#define WEAPON_MENU_SECONDS 15

new const HUMAN_WEAPONS[][] = { "weapon_m4a1", "weapon_ak47", "weapon_mp5navy", "weapon_m3" }
new const HUMAN_WEAPON_NAMES[][] = { "M4A1 - balanced rifle", "AK47 - powerful rifle", "MP5 Navy - light SMG", "M3 - close-range shotgun" }
new const HUMAN_WEAPON_LABELS[][] = { "M4A1", "AK47", "MP5 Navy", "M3" }
new const HUMAN_WEAPON_IDS[] = { CSW_M4A1, CSW_AK47, CSW_MP5NAVY, CSW_M3 }
new const HUMAN_WEAPON_AMMO[] = { 90, 90, 120, 32 }

enum RoundPhase { WAITING, PREPARING, INFECTED, ENDING }
new RoundPhase:g_phase = WAITING
new g_max_players
new bool:g_is_zombie[33]
new bool:g_departing[33]
new Float:g_respawn_at[33]
new Float:g_infection_at
new Float:g_survival_until
new g_hud
new g_nvg_message, g_round_serial
new g_weapon_choice[33], bool:g_weapon_selected[33]
new g_weapon_menu[33], g_menu_userid[33], g_menu_round[33]
new Float:g_menu_at[33], Float:g_menu_expires_at[33], g_pending_userid[33]
new g_cvar_min_players, g_cvar_infection_delay, g_cvar_survival_time
new g_cvar_zombie_ratio, g_cvar_zombie_health, g_cvar_zombie_speed, g_cvar_zombie_gravity
new g_cvar_human_health, g_cvar_human_armor, g_cvar_respawn_delay
new g_cvar_display_name, g_cvar_chat_prefix
new g_cvar_weapon_menu, g_cvar_auto_weapon_menu, g_cvar_zombie_nvg, g_cvar_remember_weapons

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
    g_cvar_weapon_menu = register_cvar("kgb_zi_weapon_menu", "1")
    g_cvar_auto_weapon_menu = register_cvar("kgb_zi_auto_weapon_menu", "1")
    g_cvar_zombie_nvg = register_cvar("kgb_zi_zombie_nightvision", "1")
    g_cvar_remember_weapons = register_cvar("kgb_zi_remember_weapons", "1")

    register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
    register_event("CurWeapon", "on_current_weapon", "be", "1=1")
    register_logevent("on_round_end", 2, "1=Round_End")
    RegisterHam(Ham_Spawn, "player", "on_player_spawn_post", 1)
    RegisterHam(Ham_TakeDamage, "player", "on_take_damage_pre", 0)
    RegisterHam(Ham_Killed, "player", "on_player_killed_post", 1)
    register_forward(FM_PlayerPreThink, "on_player_prethink")

    register_clcmd("say /zombie", "command_player_status")
    register_clcmd("say_team /zombie", "command_player_status")
    register_clcmd("say /guns", "command_weapon_menu")
    register_clcmd("say_team /guns", "command_weapon_menu")
    register_clcmd("say /weapons", "command_weapon_menu")
    register_clcmd("say_team /weapons", "command_weapon_menu")
    register_concmd("amx_zi_status", "command_admin_status", ADMIN_CFG)
    register_concmd("amx_zi_infect", "command_admin_infect", ADMIN_CFG, "<name or #userid> (active infection only)")
    register_clcmd("buy", "command_block_buy")
    register_clcmd("autobuy", "command_block_buy")
    register_clcmd("rebuy", "command_block_buy")
    register_clcmd("cl_autobuy", "command_block_buy")
    register_clcmd("cl_rebuy", "command_block_buy")
    // Loadouts are owned by the mode; dropped defaults must not be farmed.
    register_clcmd("drop", "command_block_buy")
    // Direct jointeam, VGUI and legacy menuselect all reach this engine hook.
    RegisterHookChain(RG_HandleMenu_ChooseTeam, "on_choose_team_pre", false)

    g_max_players = get_maxplayers()
    g_hud = CreateHudSyncObj()
    g_nvg_message = get_user_msgid("NVGToggle")
    for (new id = 1; id <= g_max_players; id++) g_weapon_menu[id] = NO_WEAPON_MENU
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

public plugin_end()
{
    remove_task(TASK_TICK)
    clear_round_experience()
}

public client_putinserver(id)
{
    close_weapon_menu(id)
    g_departing[id] = false
    g_is_zombie[id] = false
    g_respawn_at[id] = 0.0
    g_weapon_choice[id] = 0
    g_weapon_selected[id] = false
}

public client_disconnected(id)
{
    close_weapon_menu(id)
    clear_nightvision(id)
    // Exclude the departing slot until the next client fully enters it.
    g_departing[id] = true
    g_is_zombie[id] = false
    g_respawn_at[id] = 0.0
    g_weapon_choice[id] = 0
    g_weapon_selected[id] = false
}

public on_new_round()
{
    g_phase = WAITING
    g_round_serial++
    g_infection_at = 0.0
    g_survival_until = 0.0
    for (new id = 1; id <= g_max_players; id++)
    {
        close_weapon_menu(id)
        clear_nightvision(id)
        g_is_zombie[id] = false
        g_respawn_at[id] = 0.0
        // A preference belongs only to this connection, never a saved identity.
        // Disabling menus restores the original default at the next round too.
        if (!remember_weapon_choice()) g_weapon_choice[id] = 0
        g_weapon_selected[id] = false
    }
}

public on_round_end()
{
    g_phase = ENDING
    clear_respawns()
    clear_round_experience()
}

public round_tick()
{
    if (g_phase == ENDING)
    {
        return
    }
    new Float:now = get_gametime()
    process_respawns(now)
    process_weapon_menus(now)
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
    // No human, including an uninfected survivor, may choose after this point.
    for (new id = 1; id <= g_max_players; id++) close_weapon_menu(id)
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
    close_weapon_menu(victim)
    clear_nightvision(victim)
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
        // Engine BOOL is typedef int: ReAPI rejects ATYPE_BOOL for this hook.
        SetHookChainReturn(ATYPE_INTEGER, 0)
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
    client_print(id, print_chat, "%s Before infection: /guns chooses a primary once per round (USP + knife included). Zombies: N toggles night vision.", prefix)
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
    close_weapon_menu(id)
    clear_nightvision(id)
    g_is_zombie[id] = false
    cs_set_user_team(id, CS_TEAM_CT)
    cs_reset_user_model(id)
    give_human_loadout(id)
    set_user_health(id, clamp(get_pcvar_num(g_cvar_human_health), 1, 1000))
    cs_set_user_armor(id, clamp(get_pcvar_num(g_cvar_human_armor), 0, 1000), CS_ARMOR_VESTHELM)
    set_user_gravity(id, 1.0)
    set_user_rendering(id)
    if (get_pcvar_num(g_cvar_weapon_menu) && !is_user_bot(id))
    {
        new choice = clamp(g_weapon_choice[id], 0, sizeof HUMAN_WEAPONS - 1)
        client_print(id, print_chat, "[Zombie Infection] %s + USP/knife. Type /guns to change once this round, before infection.", HUMAN_WEAPON_LABELS[choice])
    }
    if (get_pcvar_num(g_cvar_auto_weapon_menu) && !g_weapon_selected[id] && !is_user_bot(id))
    {
        // Serviced by the existing clock, guarded by this exact client userid.
        g_menu_at[id] = get_gametime() + 1.0
        g_pending_userid[id] = get_user_userid(id)
    }
}

stock make_zombie(id, infector)
{
    close_weapon_menu(id)
    clear_nightvision(id)
    g_is_zombie[id] = true
    cs_set_user_team(id, CS_TEAM_T)
    cs_reset_user_model(id)
    strip_user_weapons(id)
    give_item(id, "weapon_knife")
    set_user_health(id, clamp(get_pcvar_num(g_cvar_zombie_health), 100, 100000))
    cs_set_user_armor(id, 0, CS_ARMOR_NONE)
    set_user_gravity(id, floatclamp(get_pcvar_float(g_cvar_zombie_gravity), 0.25, 1.0))
    set_user_rendering(id, kRenderFxGlowShell, 80, 180, 80, kRenderNormal, 8)
    if (get_pcvar_num(g_cvar_zombie_nvg))
    {
        // Ownership only: stock nightvision/N handles toggling and observers.
        cs_set_user_nvg(id, 1)
        client_print(id, print_chat, "[Zombie Infection] Press N to toggle zombie night vision.")
    }
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
    clear_round_experience()
    ClearSyncHud(0, g_hud)
    if (winner == WINSTATUS_CTS)
    {
        announce("Humans win! They survived the infection or all zombies left.")
        // rg_round_end announces/terminates only; it does not award a point.
        // The ENDING guard above owns this increment and the TeamScore update.
        rg_update_teamscores(1, 0, true)
        rg_round_end(3.0, WINSTATUS_CTS, ROUND_CTS_WIN)
    }
    else if (winner == WINSTATUS_TERRORISTS)
    {
        announce("Zombies win! No living humans remain.")
        rg_update_teamscores(0, 1, true)
        rg_round_end(3.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN)
    }
    else
    {
        announce("Round drawn: no players remain.")
        rg_round_end(3.0, WINSTATUS_DRAW, ROUND_END_DRAW)
    }
    log_amx("[ZI] round_end winner=%d ct_score=%d t_score=%d", winner, get_member_game(m_iNumCTWins), get_member_game(m_iNumTerroristWins))
}

stock clear_respawns()
{
    for (new id = 1; id <= g_max_players; id++) g_respawn_at[id] = 0.0
}

stock clear_nightvision(id)
{
    if (is_user_connected(id))
    {
        cs_set_user_nvg(id, 0)
        clear_nightvision_effect(id)
    }
    // Match the native nightvision-off observer path. A target's death or
    // disconnect can require cleanup even if its own active flag is already off.
    for (new observer = 1; observer <= g_max_players; observer++)
    {
        if (is_nightvision_observer(observer, id)) clear_nightvision_effect(observer)
    }
}

stock bool:is_nightvision_observer(observer, target)
{
    return observer >= 1 && observer <= g_max_players && observer != target
        && is_user_connected(observer) && !is_user_hltv(observer)
        && pev(observer, pev_iuser1) == OBS_IN_EYE && pev(observer, pev_iuser2) == target
}

stock clear_nightvision_effect(id)
{
    // cs_set_user_nvg changes ownership only, not the active client effect.
    if (get_member(id, m_bNightVisionOn))
    {
        set_member(id, m_bNightVisionOn, false)
        message_begin(MSG_ONE, g_nvg_message, _, id)
        write_byte(0)
        message_end()
    }
}

stock clear_round_experience()
{
    for (new id = 1; id <= g_max_players; id++)
    {
        close_weapon_menu(id)
        clear_nightvision(id)
    }
}

stock bool:can_choose_weapon(id)
{
    return id >= 1 && id <= g_max_players && is_participant(id) && is_user_alive(id)
        && !g_is_zombie[id] && cs_get_user_team(id) == CS_TEAM_CT
        && (g_phase == WAITING || g_phase == PREPARING)
        && (g_phase != PREPARING || get_gametime() < g_infection_at)
        && get_member(id, m_iJoiningState) == JOINED && !g_weapon_selected[id]
        && get_pcvar_num(g_cvar_weapon_menu) != 0
}

stock bool:remember_weapon_choice()
{
    return get_pcvar_num(g_cvar_remember_weapons) != 0 && get_pcvar_num(g_cvar_weapon_menu) != 0
}

stock bool:client_has_menu(id)
{
    new old_menu, new_menu
    // AMXX cannot see the engine's team/class VGUI menu: check both APIs.
    return get_member(id, m_iMenu) != Menu_OFF || player_menu_info(id, old_menu, new_menu) != 0
}

stock bool:weapon_menu_current(id, Float:now)
{
    return g_menu_userid[id] == get_user_userid(id) && g_menu_round[id] == g_round_serial && now < g_menu_expires_at[id]
}

stock expire_weapon_menu(id, Float:now)
{
    // AMXX's timeout rejects late input but does not remove the HUD menu or
    // make player_menu_info forget it. Own the visible lifetime explicitly.
    if (g_weapon_menu[id] != NO_WEAPON_MENU && !weapon_menu_current(id, now)) close_weapon_menu(id)
}

stock process_weapon_menus(Float:now)
{
    for (new id = 1; id <= g_max_players; id++)
    {
        if (!can_choose_weapon(id))
        {
            close_weapon_menu(id)
            continue
        }
        expire_weapon_menu(id, now)
        if (g_menu_at[id] == 0.0 || now < g_menu_at[id]) continue
        if (g_pending_userid[id] != get_user_userid(id) || !get_pcvar_num(g_cvar_auto_weapon_menu))
        {
            g_menu_at[id] = 0.0
            g_pending_userid[id] = 0
            continue
        }
        if (!client_has_menu(id)) show_weapon_menu(id)
    }
}

public command_weapon_menu(id)
{
    if (!can_choose_weapon(id))
    {
        client_print(id, print_chat, "[Zombie Infection] Choose once per round while alive and human, before infection begins.")
        return PLUGIN_HANDLED
    }
    // A command can arrive after the deadline but before the next clock tick.
    expire_weapon_menu(id, get_gametime())
    if (client_has_menu(id))
    {
        client_print(id, print_chat, "[Zombie Infection] Close your current menu, then type /guns.")
        return PLUGIN_HANDLED
    }
    show_weapon_menu(id)
    return PLUGIN_HANDLED
}

stock show_weapon_menu(id)
{
    if (!can_choose_weapon(id) || client_has_menu(id)) return
    close_weapon_menu(id)
    new title[160], choice = clamp(g_weapon_choice[id], 0, sizeof HUMAN_WEAPONS - 1)
    formatex(title, charsmax(title), "Human weapons | Current: %s^nUSP + knife included | Choose once this round", HUMAN_WEAPON_LABELS[choice])
    new menu = menu_create(title, "on_weapon_selected")
    for (choice = 0; choice < sizeof HUMAN_WEAPONS; choice++)
    {
        new value[4]
        num_to_str(choice, value, charsmax(value))
        menu_additem(menu, HUMAN_WEAPON_NAMES[choice], value)
    }
    menu_setprop(menu, MPROP_EXITNAME, "Keep current weapons")
    g_weapon_menu[id] = menu
    g_menu_userid[id] = get_user_userid(id)
    g_menu_round[id] = g_round_serial
    g_menu_expires_at[id] = get_gametime() + float(WEAPON_MENU_SECONDS)
    menu_display(id, menu, 0, WEAPON_MENU_SECONDS)
}

public on_weapon_selected(id, menu, item)
{
    // Cancellation can call this synchronously from close_weapon_menu. Only the
    // current owner destroys the resource; an old callback cannot grant items.
    if (id < 1 || id > g_max_players || menu != g_weapon_menu[id]) return PLUGIN_HANDLED
    new bool:valid = weapon_menu_current(id, get_gametime()) && can_choose_weapon(id)
    new choice = -1
    if (valid && item >= 0 && item < sizeof HUMAN_WEAPONS)
    {
        new access, callback, value[4], label[64]
        menu_item_getinfo(menu, item, access, value, charsmax(value), label, charsmax(label), callback)
        choice = str_to_num(value)
        if (choice != item) choice = -1
    }
    close_weapon_menu(id)
    if (!valid || choice < 0 || choice >= sizeof HUMAN_WEAPONS) return PLUGIN_HANDLED
    // Consume the choice before inventory writes. No health/armor refresh.
    g_weapon_selected[id] = true
    g_weapon_choice[id] = choice
    give_human_loadout(id)
    if (remember_weapon_choice()) client_print(id, print_chat, "[Zombie Infection] %s selected and remembered until you leave. You can change again next round.", HUMAN_WEAPON_LABELS[choice])
    else client_print(id, print_chat, "[Zombie Infection] %s selected for this round. You can change again next round.", HUMAN_WEAPON_LABELS[choice])
    return PLUGIN_HANDLED
}

stock close_weapon_menu(id)
{
    g_menu_at[id] = 0.0
    g_pending_userid[id] = 0
    new menu = g_weapon_menu[id]
    g_weapon_menu[id] = NO_WEAPON_MENU
    g_menu_userid[id] = 0
    g_menu_round[id] = 0
    g_menu_expires_at[id] = 0.0
    if (menu == NO_WEAPON_MENU) return
    if (is_user_connected(id))
    {
        new old_menu, active_menu
        if (player_menu_info(id, old_menu, active_menu) && active_menu == menu)
        {
            menu_cancel(id)
            // menu_cancel invalidates a menu but leaves its HUD on screen.
            show_menu(id, 0, "^n", 1)
        }
    }
    menu_destroy(menu)
}

stock give_human_loadout(id)
{
    new choice = clamp(g_weapon_choice[id], 0, sizeof HUMAN_WEAPONS - 1)
    strip_user_weapons(id)
    // Explicitly clear reserves for every selectable primary; changing a
    // loadout replaces rather than accumulates ammunition or dropped weapons.
    for (new index = 0; index < sizeof HUMAN_WEAPON_IDS; index++) cs_set_user_bpammo(id, HUMAN_WEAPON_IDS[index], 0)
    give_item(id, "weapon_knife")
    give_item(id, HUMAN_WEAPONS[choice])
    give_item(id, "weapon_usp")
    cs_set_user_bpammo(id, HUMAN_WEAPON_IDS[choice], HUMAN_WEAPON_AMMO[choice])
    cs_set_user_bpammo(id, CSW_USP, 100)
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
