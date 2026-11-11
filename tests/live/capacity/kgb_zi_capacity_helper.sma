// SPDX-License-Identifier: GPL-3.0-or-later
// TEST INSTRUMENTATION ONLY. Never package with production core/maps.
// Stationary engine fake clients are explicit TEST DOUBLES. Human state is
// read-only. Fake joins use the native team/class command flow; all spawns are
// native engine/core events. No forced JOINED, team, spawn, origin or damage.
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define VERSION "0.1.0-test-source-review"
#define MAX_OWNED 31

new g_owned_uid[33], g_spawn_uid[33], g_spawn_count[33], g_spawn_round[33]
new g_creating_slot, g_creating_uid, g_serial, g_round
new g_join_reported[33]
new Float:g_next_command[33], Float:g_next_frame

public plugin_init()
{
    register_plugin("ZI capacity helper (TEST ONLY)", VERSION, "KGB Hosting")
    register_srvcmd("zicap_add", "command_add")
    register_srvcmd("zicap_drop", "command_drop")
    register_srvcmd("zicap_clear", "command_clear")
    register_srvcmd("zicap_snapshot", "command_snapshot")
    RegisterHookChain(RG_CSGameRules_RestartRound, "on_round", false)
    RegisterHam(Ham_Spawn, "player", "on_spawn_pre")
    RegisterHam(Ham_Spawn, "player", "on_spawn_post", 1)
    register_forward(FM_StartFrame, "on_frame")
    server_print("[ZICAP] event=loaded version_major=0 version_minor=1 version_patch=0 test_only=1")
}

// Exact positive ephemeral identity + native fake bit are required before
// every write. This lower-level guard also covers only the just-created fake
// during synchronous DLL initialization, before AMXX reports connected.
stock bool:exact_fake(id, uid)
{
    return id >= 1 && id <= MaxClients && uid > 0 && pev_valid(id)
        && get_user_userid(id) == uid && (pev(id, pev_flags) & FL_FAKECLIENT) != 0
}

stock bool:owned_fake(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id)
        && exact_fake(id, g_owned_uid[id])
}

stock owned_count()
{
    new count
    for (new id = 1; id <= MaxClients; id++) if (owned_fake(id)) count++
    return count
}

stock parse_positive_arg(position)
{
    new text[16]
    read_argv(position, text, charsmax(text))
    if (!text[0] || strlen(text) > 9) return 0
    for (new i = 0; text[i]; i++) if (text[i] < '0' || text[i] > '9') return 0
    new value = str_to_num(text)
    return value > 0 ? value : 0
}

stock clear_slot(id)
{
    g_owned_uid[id] = g_spawn_uid[id] = g_spawn_count[id] = g_spawn_round[id] = 0
    g_join_reported[id] = 0
    g_next_command[id] = 0.0
}

public client_putinserver(id)
{
    // Internal bookkeeping only; never writes any player's engine state.
    clear_slot(id)
}

public client_disconnected(id)
{
    server_print("[ZICAP] event=disconnect slot=%d previously_owned=%d round=%d time=%.2f", id, g_owned_uid[id] > 0, g_round, get_gametime())
    clear_slot(id)
}

// Pre-hook runs before native RestartRound spawns; counts cannot be reset by
// a later HLTV packet after the spawns being measured. No return is overridden.
public on_round()
{
    g_round++
    for (new id = 1; id <= MaxClients; id++)
    {
        g_spawn_count[id] = 0
        g_spawn_round[id] = g_round
    }
    server_print("[ZICAP] event=round_reset round=%d time=%.2f", g_round, get_gametime())
}

public command_add()
{
    new count = parse_positive_arg(1), connected, foreign_fake, real_present
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        connected++
        if ((pev(id, pev_flags) & FL_FAKECLIENT) != 0 && !owned_fake(id)) foreign_fake++
        if ((pev(id, pev_flags) & FL_FAKECLIENT) == 0 && !is_user_bot(id) && !is_user_hltv(id)) real_present++
    }
    // MaxClients-1 reserves a real-client slot even when no human is present.
    new limit = min(MAX_OWNED, MaxClients - 1)
    if (read_argc() != 2 || count < 1 || count > limit || owned_count() + count > limit
        || count > MaxClients - connected - (real_present > 0 ? 0 : 1) || foreign_fake > 0 || g_creating_slot != 0)
    {
        server_print("[ZICAP] event=refused code=1 maximum_slots=%d owned=%d foreign_fake=%d requested=%d limit=%d", MaxClients, owned_count(), foreign_fake, count, limit)
        return
    }
    new created
    for (new index = 0; index < count; index++)
    {
        new alias[48], reject[128]
        formatex(alias, charsmax(alias), "ZI-CAP TEST DOUBLE %d", ++g_serial)
        new id = engfunc(EngFunc_CreateFakeClient, alias)
        if (!id)
        {
            server_print("[ZICAP] event=refused code=2 created=%d", created)
            break
        }
        new uid = get_user_userid(id)
        if (!exact_fake(id, uid))
        {
            // Do not try to initialize, flag or kick an identity not proved fake.
            server_print("[ZICAP] event=refused code=3 slot=%d", id)
            break
        }
        g_creating_slot = id
        g_creating_uid = uid
        engfunc(EngFunc_FreeEntPrivateData, id)
        if (!exact_fake(id, uid))
        {
            g_creating_slot = g_creating_uid = 0
            server_print("[ZICAP] event=refused code=4 slot=%d", id)
            break
        }
        new accepted = dllfunc(DLLFunc_ClientConnect, id, alias, "127.0.0.1", reject, charsmax(reject))
        // Rejection text is deliberately never printed (may contain identity).
        if (!accepted || !exact_fake(id, uid))
        {
            g_creating_slot = g_creating_uid = 0
            server_print("[ZICAP] event=refused code=5 slot=%d accepted=%d", id, accepted != 0)
            // A verified just-created engine fake may be removed by its UID.
            if (exact_fake(id, uid)) { server_cmd("kick #%d", uid); server_exec(); }
            break
        }
        dllfunc(DLLFunc_ClientPutInServer, id)
        g_creating_slot = g_creating_uid = 0
        if (!is_user_connected(id) || !exact_fake(id, uid))
        {
            server_print("[ZICAP] event=refused code=6 slot=%d", id)
            break
        }
        g_owned_uid[id] = uid
        g_next_command[id] = get_gametime() + 0.25
        created++
        server_print("[ZICAP] event=created slot=%d userid=%d owned_test_double=1 round=%d time=%.2f", id, uid, g_round, get_gametime())
    }
    server_print("[ZICAP] event=add_complete requested=%d created=%d owned=%d maximum_slots=%d", count, created, owned_count(), MaxClients)
}

public on_spawn_pre(id)
{
    g_spawn_uid[id] = 0
    if (owned_fake(id)) g_spawn_uid[id] = g_owned_uid[id]
    else if (id == g_creating_slot && exact_fake(id, g_creating_uid)) g_spawn_uid[id] = g_creating_uid
    return HAM_IGNORED
}

public on_spawn_post(id)
{
    // Native Spawn clears FL_FAKECLIENT. Only a pre-proved fake's identical
    // positive UID may regain that flag; this does not convert a real player.
    new captured = g_spawn_uid[id]
    if (captured > 0 && get_user_userid(id) == captured
        && (g_owned_uid[id] == captured || (id == g_creating_slot && g_creating_uid == captured)))
    {
        set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT)
        if (owned_fake(id) && is_user_alive(id) && get_member(id, m_iJoiningState) == JOINED)
            set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN)
    }
    g_spawn_uid[id] = 0
    // All clients are read-only here except the identity-guarded fake flags above.
    if (is_user_connected(id) && is_user_alive(id) && get_member(id, m_iJoiningState) == JOINED)
    {
        g_spawn_count[id]++
        g_spawn_round[id] = g_round
        server_print("[ZICAP] event=engine_spawn slot=%d userid=%d owned_test_double=%d team=%d joining=%d spawns_this_round=%d round=%d time=%.2f", id, get_user_userid(id), owned_fake(id), get_member(id, m_iTeam), get_member(id, m_iJoiningState), g_spawn_count[id], g_round, get_gametime())
    }
    return HAM_IGNORED
}

public on_frame()
{
    new Float:now = get_gametime()
    if (now < g_next_frame) return FMRES_IGNORED
    g_next_frame = now + 0.05
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!owned_fake(id)) continue
        // Fake-only activity prevents native idle-kicks. Zero-button engine
        // movement advances JoiningThink naturally; it never attacks or moves.
        set_member(id, m_fLastMovement, now)
        new Float:angles[3]
        pev(id, pev_v_angle, angles)
        engfunc(EngFunc_RunPlayerMove, id, angles, 0.0, 0.0, 0.0, 0, 0, 50)
        if (!owned_fake(id)) continue
        new JoinState:joining = get_member(id, m_iJoiningState)
        new _Menu:menu = get_member(id, m_iMenu)
        if (joining == JOINED)
        {
            if (!g_join_reported[id])
            {
                g_join_reported[id] = 1
                server_print("[ZICAP] event=native_joined slot=%d userid=%d team=%d alive=%d round=%d time=%.2f", id, g_owned_uid[id], get_member(id, m_iTeam), is_user_alive(id), g_round, now)
            }
            if (is_user_alive(id)) set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN)
            continue
        }
        if (now < g_next_command[id]) continue
        g_next_command[id] = now + 0.5
        if (joining == PICKINGTEAM && menu == Menu_ChooseTeam && get_member(id, m_iTeam) == TEAM_UNASSIGNED)
        {
            // Native command handlers, including the core's actual hooks.
            engclient_cmd(id, "jointeam", "2")
        }
        else if (menu == Menu_ChooseAppearance)
        {
            engclient_cmd(id, "joinclass", "4")
        }
    }
    return FMRES_IGNORED
}

stock kick_owned(id)
{
    if (!owned_fake(id)) return
    new uid = g_owned_uid[id]
    server_print("[ZICAP] event=drop slot=%d userid=%d round=%d time=%.2f", id, uid, g_round, get_gametime())
    server_cmd("kick #%d", uid)
    server_exec()
}

public command_drop()
{
    new uid = parse_positive_arg(1)
    new id = uid > 0 ? find_player("k", uid) : 0
    if (read_argc() != 2 || !owned_fake(id))
    {
        server_print("[ZICAP] event=refused code=7")
        return
    }
    kick_owned(id)
}

public command_clear()
{
    if (read_argc() != 1) { server_print("[ZICAP] event=refused code=8"); return; }
    for (new id = 1; id <= MaxClients; id++) kick_owned(id)
    server_print("[ZICAP] event=clear_complete owned=%d", owned_count())
}

public command_snapshot()
{
    if (read_argc() != 1) { server_print("[ZICAP] event=refused code=9"); return; }
    new connected, joined, alive, ct, t, owned, foreign_fake, actual_real, pending, unspawned
    new spawned_owned, spawned_real, overlap_pairs, blocked_world
    new Float:mins[33][3], Float:maxs[33][3], bool:physical[33]
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id)) continue
        connected++
        new bool:ours = owned_fake(id)
        new bool:fake = (pev(id, pev_flags) & FL_FAKECLIENT) != 0
        new bool:actual_human = !fake && !is_user_hltv(id) && !is_user_bot(id)
        owned += ours ? 1 : 0
        foreign_fake += fake && !ours ? 1 : 0
        actual_real += actual_human ? 1 : 0
        new JoinState:join_state = get_member(id, m_iJoiningState)
        new TeamName:team = get_member(id, m_iTeam)
        new bool:living = is_user_alive(id) != 0
        joined += join_state == JOINED ? 1 : 0
        pending += join_state != JOINED ? 1 : 0
        alive += living ? 1 : 0
        ct += living && team == TEAM_CT ? 1 : 0
        t += living && team == TEAM_TERRORIST ? 1 : 0
        new spawns = g_spawn_round[id] == g_round ? g_spawn_count[id] : 0
        unspawned += spawns == 0 ? 1 : 0
        spawned_owned += ours && spawns > 0 ? 1 : 0
        spawned_real += actual_human && spawns > 0 ? 1 : 0
        new Float:origin[3], Float:lo[3], Float:hi[3]
        pev(id, pev_origin, origin)
        pev(id, pev_mins, lo)
        pev(id, pev_maxs, hi)
        for (new axis = 0; axis < 3; axis++)
        {
            mins[id][axis] = origin[axis] + lo[axis]
            maxs[id][axis] = origin[axis] + hi[axis]
        }
        new blocked
        physical[id] = living && join_state == JOINED && (team == TEAM_CT || team == TEAM_TERRORIST) && pev(id, pev_solid) == SOLID_SLIDEBOX
        if (physical[id])
        {
            new trace = create_tr2()
            new hull = (pev(id, pev_flags) & FL_DUCKING) != 0 ? HULL_HEAD : HULL_HUMAN
            // World-only: player-vs-player overlap is independently checked below.
            engfunc(EngFunc_TraceHull, origin, origin, IGNORE_MONSTERS, hull, id, trace)
            blocked = get_tr2(trace, TR_StartSolid) || get_tr2(trace, TR_AllSolid)
            free_tr2(trace)
            blocked_world += blocked
        }
        server_print("[ZICAP] event=participant slot=%d userid=%d owned_test_double=%d real_client=%d alive=%d team=%d joining=%d solid=%d spawns_this_round=%d world_blocked=%d round=%d", id, get_user_userid(id), ours, actual_human, living, team, join_state, pev(id, pev_solid), spawns, blocked, g_round)
        if (physical[id])
            server_print("[ZICAP] event=hull slot=%d x=%.3f y=%.3f z=%.3f min_x=%.3f min_y=%.3f min_z=%.3f max_x=%.3f max_y=%.3f max_z=%.3f", id, origin[0], origin[1], origin[2], mins[id][0], mins[id][1], mins[id][2], maxs[id][0], maxs[id][1], maxs[id][2])
    }
    for (new a = 1; a <= MaxClients; a++)
    {
        if (!physical[a]) continue
        for (new b = a + 1; b <= MaxClients; b++)
        {
            if (!physical[b]) continue
            new Float:depth[3]
            for (new axis = 0; axis < 3; axis++) depth[axis] = floatmin(maxs[a][axis], maxs[b][axis]) - floatmax(mins[a][axis], mins[b][axis])
            // Strict positive intersection, not touching/adjacent boundaries.
            if (depth[0] <= 0.0 || depth[1] <= 0.0 || depth[2] <= 0.0) continue
            overlap_pairs++
            server_print("[ZICAP] event=hull_overlap slot_a=%d slot_b=%d userid_a=%d userid_b=%d depth_x=%.3f depth_y=%.3f depth_z=%.3f", a, b, get_user_userid(a), get_user_userid(b), depth[0], depth[1], depth[2])
        }
    }
    // Separate bounded records: AMXX server_print truncates long messages.
    // Round and time correlate all three; no aggregate relies on one long line.
    new Float:now = get_gametime()
    server_print("[ZICAP] event=counts maximum_slots=%d connected=%d joined=%d pending=%d alive=%d ct_alive=%d t_alive=%d round=%d time=%.2f", MaxClients, connected, joined, pending, alive, ct, t, g_round, now)
    server_print("[ZICAP] event=ownership real_clients=%d owned_test_doubles=%d foreign_fake=%d unspawned_this_round=%d spawned_owned=%d spawned_real=%d round=%d time=%.2f", actual_real, owned, foreign_fake, unspawned, spawned_owned, spawned_real, g_round, now)
    server_print("[ZICAP] event=collision overlap_pairs=%d world_blocked=%d round=%d time=%.2f", overlap_pairs, blocked_world, g_round, now)
}
