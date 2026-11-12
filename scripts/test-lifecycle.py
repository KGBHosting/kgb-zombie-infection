#!/usr/bin/env python3
"""Lifecycle specification and Pawn source contracts; NOT engine/gameplay tests.

RoundSpecification is a deliberately small TEST DOUBLE used only in these tests.
It describes expected outcomes, does not execute Pawn and does not emulate ReHLDS.
"""
from __future__ import annotations

import ast
import itertools
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = (ROOT / "src/kgb_zombie_infection.sma").read_text()
CONFIG = (ROOT / "configs/kgb_zombie_infection.cfg.example").read_text()
HELPER = (ROOT / "tests/live/kgb_zi_acceptance_helper.sma").read_text()


class RoundSpecification:
    """TEST DOUBLE of the expected round clock, not an engine implementation."""

    def __init__(self) -> None:
        self.phase = "waiting"
        self.infection_at = 0
        self.survival_until = 0
        self.results: list[str] = []
        self.respawns: dict[int, int] = {}

    def tick(self, now: int, humans: int, participants: int) -> None:
        if self.phase == "waiting" and humans >= 2:
            self.phase, self.infection_at = "preparing", now + 15
        elif self.phase == "preparing":
            if humans < 2:
                self.phase, self.infection_at = "waiting", 0
            elif now >= self.infection_at:
                self.phase, self.survival_until = "infected", now + 180
        elif self.phase == "infected":
            if humans == 0:
                self.finish("zombies" if participants else "draw")
            elif participants == humans or now >= self.survival_until:
                self.finish("humans")

    def finish(self, winner: str) -> None:
        if self.phase == "infected":
            self.phase = "ending"
            self.respawns.clear()
            self.results.append(winner)

    def reset(self) -> None:
        self.phase = "waiting"
        self.infection_at = self.survival_until = 0
        self.respawns.clear()


def function_body(name: str, source: str = SOURCE) -> str:
    match = re.search(rf"(?:public|stock)\s+(?:\w+:)?{name}\([^)]*\)\s*\{{", source)
    if match is None:
        raise AssertionError(f"Missing Pawn function {name}")
    depth, cursor = 1, match.end()
    while depth:
        if source[cursor] == "{": depth += 1
        elif source[cursor] == "}": depth -= 1
        cursor += 1
    return source[match.end():cursor - 1]


def engine_team_choice_blocked(phase: str, participant: bool, choice: int) -> bool:
    """Evaluate the real Pawn guard's boolean expression, not a copied policy.

    Only equality, AND and the is_participant TEST DOUBLE are admitted. This
    checks the production predicate's decision table, not engine dispatch.
    """
    body = function_body("on_choose_team_pre")
    match = re.search(r"\bif\s*\(", body)
    if match is None:
        raise AssertionError("Engine team-choice guard has no condition")
    depth, cursor = 1, match.end()
    while depth:
        if body[cursor] == "(": depth += 1
        elif body[cursor] == ")": depth -= 1
        cursor += 1
    predicate = body[match.end():cursor - 1].replace("&&", " and ")
    tree = ast.parse(predicate, mode="eval")
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Compare, ast.Eq, ast.NotEq, ast.Name, ast.Load, ast.Call)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise AssertionError("Unsupported expression in actual Pawn team-choice guard")
    names = {node.id for node in ast.walk(tree) if isinstance(node, ast.Name)}
    if names != {"g_phase", "INFECTED", "is_participant", "id", "slot", "MenuChoose_Spec"}:
        raise AssertionError("Unexpected names in actual Pawn team-choice guard")
    return bool(eval(compile(tree, "<Pawn team-choice guard>", "eval"), {"__builtins__": {}}, {
        "g_phase": phase, "INFECTED": "infected", "id": 1,
        "is_participant": lambda _: participant,  # Explicit TEST DOUBLE, tests only.
        "slot": choice, "MenuChoose_Spec": 6,
    }))


class LifecycleSpecificationTests(unittest.TestCase):
    def infected(self) -> RoundSpecification:
        spec = RoundSpecification()
        spec.tick(1, 2, 2)
        spec.tick(16, 2, 2)
        self.assertEqual("infected", spec.phase)
        return spec

    def test_joins_recover_waiting_without_manual_restart(self) -> None:
        spec = RoundSpecification()
        spec.tick(1, 1, 1)
        self.assertEqual("waiting", spec.phase)
        spec.tick(5, 2, 2)
        self.assertEqual(("preparing", 20), (spec.phase, spec.infection_at))

    def test_dropout_restarts_full_countdown(self) -> None:
        spec = RoundSpecification()
        spec.tick(1, 2, 2)
        spec.tick(15, 1, 1)
        spec.tick(16, 2, 2)
        self.assertEqual(("preparing", 31), (spec.phase, spec.infection_at))

    def test_living_roles_and_participant_matrix(self) -> None:
        for humans, participants in itertools.product(range(4), repeat=2):
            if humans > participants: continue
            with self.subTest(humans=humans, participants=participants):
                spec = self.infected()
                spec.tick(20, humans, participants)
                expected = (["zombies"] if participants else ["draw"]) if humans == 0 else (["humans"] if participants == humans else [])
                self.assertEqual(expected, spec.results)

    def test_dead_zombie_participant_prevents_early_human_win(self) -> None:
        spec = self.infected()
        spec.tick(20, humans=1, participants=2)
        self.assertEqual([], spec.results)

    def test_deadline_and_single_terminal_result(self) -> None:
        spec = self.infected()
        spec.respawns[7] = 200
        spec.tick(195, 1, 2)
        self.assertEqual([], spec.results)
        spec.tick(196, 1, 2)
        spec.tick(197, 0, 2)
        spec.finish("zombies")
        self.assertEqual(["humans"], spec.results)
        self.assertEqual({}, spec.respawns)

    def test_reset_discards_respawns_and_deadlines(self) -> None:
        spec = self.infected()
        spec.respawns[3] = 21
        spec.reset()
        spec.tick(21, 1, 1)
        self.assertEqual(("waiting", {}, 0, 0), (spec.phase, spec.respawns, spec.infection_at, spec.survival_until))


class PawnSafetyContractTests(unittest.TestCase):
    def test_actual_team_choice_predicate_all_phases_roles_and_menu_slots(self) -> None:
        for phase, participant, choice in itertools.product(
            ("waiting", "preparing", "infected", "ending"), (False, True), (-1, 0, 1, 2, 3, 4, 5, 6, 7, 10)
        ):
            with self.subTest(phase=phase, participant=participant, choice=choice):
                # Independent requirement: active participants may spectate;
                # neither T/CT/VIP/autoselect nor malformed choices may switch them.
                expected = phase == "infected" and participant and choice != 6
                self.assertEqual(expected, engine_team_choice_blocked(phase, participant, choice))

    def test_team_lock_hooks_shared_engine_path_and_returns_engine_integer_zero(self) -> None:
        init = function_body("plugin_init")
        self.assertIn('RegisterHookChain(RG_HandleMenu_ChooseTeam, "on_choose_team_pre", false)', init)
        self.assertNotIn('register_clcmd("jointeam"', init)
        self.assertNotIn("public command_jointeam(", SOURCE)
        body = function_body("on_choose_team_pre")
        self.assertIn("slot != MenuChoose_Spec", body)
        self.assertIn("SetHookChainReturn(ATYPE_INTEGER, 0)", body)
        # ReGameDLL BOOL is typedef int, not C++ bool. ReAPI checks the exact
        # runtime type; a compiling ATYPE_BOOL call throws native error 10.
        self.assertNotRegex(body, r"SetHookChainReturn\(\s*ATYPE_BOOL\b")
        self.assertEqual(1, body.count("SetHookChainReturn("))
        self.assertIn("return HC_SUPERCEDE", body)
        self.assertIn("return HC_CONTINUE", body)
        self.assertLess(body.index("SetHookChainReturn(ATYPE_INTEGER, 0)"), body.index("return HC_SUPERCEDE"))
        self.assertLess(body.index("return HC_SUPERCEDE"), body.index("return HC_CONTINUE"))

    def test_only_one_permanent_clock_no_player_or_round_tasks(self) -> None:
        self.assertEqual(1, SOURCE.count("set_task("))
        self.assertIn('set_task(1.0, "round_tick", TASK_TICK', function_body("plugin_cfg"))
        self.assertNotIn("set_task(", function_body("on_new_round"))
        self.assertNotIn("set_task(", function_body("on_player_killed_post"))

    def test_native_objectives_fail_closed(self) -> None:
        self.assertIn('get_cvar_pointer("mp_round_infinite")', function_body("plugin_cfg"))
        self.assertIn("get_pcvar_num(pointer) != 1", function_body("plugin_cfg"))
        self.assertIn('mp_round_infinite "1"', CONFIG)
        self.assertIn('mp_forcerespawn "0"', CONFIG)
        self.assertIn('mp_freeforall "0"', CONFIG)

    def test_initial_infection_always_leaves_human(self) -> None:
        body = function_body("begin_infection")
        self.assertIn("player_count < 2", body)
        self.assertIn("1, player_count - 1", body)
        self.assertIn("random_num(0, index)", body)
        self.assertIn("g_survival_until = now +", body)

    def test_knife_infection_uses_verified_damage_contract(self) -> None:
        body = function_body("on_take_damage_pre")
        for contract in ("g_phase != INFECTED", "inflictor == attacker", "get_user_weapon(attacker) == CSW_KNIFE", "damage_bits & DMG_BULLET", "HAM_SUPERCEDE", "SetHamParamFloat(4, 0.0)"):
            self.assertIn(contract, body)

    def test_respawn_excludes_spectators_and_unfinished_joins(self) -> None:
        self.assertIn("team == CS_TEAM_T || team == CS_TEAM_CT", function_body("is_participant"))
        self.assertIn("g_departing[id]", function_body("is_participant"))
        self.assertIn("m_iJoiningState) != JOINED", function_body("process_respawns"))
        self.assertIn("ExecuteHamB(Ham_CS_RoundRespawn, id)", function_body("process_respawns"))
        self.assertIn("g_respawn_at[id] = 0.0", function_body("client_disconnected"))
        self.assertIn("g_departing[id] = false", function_body("client_putinserver"))

    def test_outcomes_guard_before_engine_call(self) -> None:
        body = function_body("finish_round")
        self.assertLess(body.index("g_phase != INFECTED"), body.index("g_phase = ENDING"))
        self.assertLess(body.index("g_phase = ENDING"), body.index("rg_round_end("))
        self.assertLess(body.index("clear_respawns()"), body.index("rg_round_end("))
        self.assertEqual(3, body.count("rg_round_end("))

    def test_winner_score_increment_is_guarded_and_precedes_termination(self) -> None:
        body = function_body("finish_round")
        self.assertEqual(2, body.count("rg_update_teamscores("))
        for score_call, end_call in (
            ("rg_update_teamscores(1, 0, true)", "rg_round_end(3.0, WINSTATUS_CTS, ROUND_CTS_WIN)"),
            ("rg_update_teamscores(0, 1, true)", "rg_round_end(3.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN)"),
        ):
            self.assertLess(body.index("g_phase != INFECTED"), body.index("g_phase = ENDING"))
            self.assertLess(body.index("g_phase = ENDING"), body.index(score_call))
            self.assertLess(body.index("clear_respawns()"), body.index(score_call))
            self.assertLess(body.index(score_call), body.index(end_call))
        # Bind each increment to its actual winner branch. Draw must be scoreless.
        cts, rest = body.split("else if (winner == WINSTATUS_TERRORISTS)", 1)
        terrorists, draw = rest.split("else", 1)
        self.assertIn("rg_update_teamscores(1, 0, true)", cts)
        self.assertNotIn("rg_update_teamscores(0, 1, true)", cts)
        self.assertIn("rg_update_teamscores(0, 1, true)", terrorists)
        self.assertNotIn("rg_update_teamscores(1, 0, true)", terrorists)
        self.assertNotIn("rg_update_teamscores(", draw)
        self.assertIn("get_member_game(m_iNumCTWins)", body)
        self.assertIn("get_member_game(m_iNumTerroristWins)", body)

    def test_no_external_assets_or_escape_claim(self) -> None:
        self.assertNotRegex(SOURCE, r"precache_(?:model|sound|generic)\s*\(")
        self.assertIn('#define PLUGIN_NAME "KGB Zombie Infection"', SOURCE)
        self.assertIn("SPDX-License-Identifier: GPL-3.0-or-later", SOURCE)
        self.assertIn("GNU GENERAL PUBLIC LICENSE", (ROOT / "LICENSE").read_text())

    def test_admin_cannot_skip_preparation_or_bypass_permissions(self) -> None:
        body = function_body("command_admin_infect")
        self.assertIn("cmd_access(id, level, cid, 2)", body)
        self.assertIn("g_phase != INFECTED", body)
        self.assertIn("CMDTARGET_ONLY_ALIVE", body)
        self.assertNotIn("g_phase = INFECTED", body)


class LiveHelperBoundaryContractTests(unittest.TestCase):
    """Static boundaries only: these do NOT execute or qualify the live helper."""

    def test_helper_is_console_only_and_excluded_from_runtime_release(self) -> None:
        self.assertIn("DEVELOPMENT TEST INSTRUMENTATION ONLY", HELPER)
        self.assertIn("TEST DOUBLES", HELPER)
        self.assertEqual(7, HELPER.count('register_srvcmd("ziqa_'))
        self.assertNotRegex(HELPER, r"register_(?:clcmd|concmd)\(")
        self.assertIn('BUILD_COMPONENTS="${BUILD_COMPONENTS:-core}"', (ROOT / "scripts/build.sh").read_text())
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn('BUILD_COMPONENTS: "core acceptance-helper capacity-helper"', workflow)
        self.assertNotIn("compiled/kgb_zi_acceptance_helper", workflow)
        self.assertNotIn("compiled/kgb_zi_capacity_helper", workflow)

    def test_native_client_connect_has_bounded_rejection_output(self) -> None:
        # Fakemeta DLLFunc_ClientConnect reads its sixth native argument as
        # reject-buffer capacity. Missing it makes variadic native access
        # undefined even when the game DLL accepts the connection.
        body = function_body("command_add", HELPER)
        calls = re.findall(r'dllfunc\(DLLFunc_ClientConnect,\s*(.*?)\)\s*\n', body)
        self.assertEqual(1, len(calls))
        self.assertRegex(calls[0], r'^id,\s*name,\s*"127\.0\.0\.1",\s*reject,\s*charsmax\(reject\)$')
        self.assertRegex(body, r'\breject\[128\]')

    def test_mutating_commands_require_exact_owned_fake_identity(self) -> None:
        guard = function_body("is_owned_fake", HELPER)
        for contract in ("id >= 1", "id <= MaxClients", "is_user_connected(id)",
                         "g_owned_userid[id] > 0", "get_user_userid(id) == g_owned_userid[id]", "FL_FAKECLIENT"):
            self.assertIn(contract, guard)
        for handler in ("command_place", "command_health", "kick_owned_fake", "on_frame"):
            self.assertIn("is_owned_fake(", function_body(handler, HELPER))
        enrollment = function_body("command_add", HELPER)
        self.assertLess(enrollment.index("EngFunc_CreateFakeClient"), enrollment.index("g_owned_userid[id] = get_user_userid(id)"))
        self.assertLess(enrollment.index("if (!is_owned_fake(id))"), enrollment.index("m_iJoiningState, JOINED"))
        spawn = function_body("on_spawn_post", HELPER)
        self.assertIn("get_user_userid(id) == g_spawn_userid[id]", spawn)
        self.assertIn("g_owned_userid[id] == g_spawn_userid[id]", spawn)

    def test_no_synthetic_damage_deaths_infections_or_human_state_writes(self) -> None:
        self.assertNotRegex(HELPER, r"ExecuteHamB?\(Ham_(?:TakeDamage|Killed)")
        self.assertNotRegex(HELPER, r"(?:message_begin|engfunc\(EngFunc_MessageBegin|write_byte|write_string)\(")
        self.assertNotIn('server_cmd("amx_zi_infect', HELPER)
        self.assertNotIn("SetHamParam", HELPER)
        self.assertNotIn("SetHookChain", HELPER)
        self.assertNotRegex(HELPER, r"(?:set_pev|set_member|set_user_\w+|cs_set_user_\w+|engclient_cmd)\(human\b")
        # JOINED may be set only during guarded creation of a fake test double.
        self.assertEqual(1, HELPER.count("m_iJoiningState, JOINED"))
        self.assertIn("m_iJoiningState, JOINED", function_body("command_add", HELPER))


def evaluate_experience_predicate(predicate: str, values: dict) -> bool:
    """Evaluate real Pawn boolean expressions using explicit test-only natives.

    This checks guard decision tables, never AMXX menu dispatch or engine state.
    Only a restricted AST is allowed; calls can access only supplied test doubles.
    """
    predicate = re.sub(r"!(?!=)", " not ", predicate).replace("&&", " and ").replace("||", " or ")
    tree = ast.parse(" ".join(predicate.split()), mode="eval")
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
               ast.Compare, ast.Eq, ast.NotEq, ast.Lt, ast.Gt, ast.GtE, ast.LtE,
               ast.Name, ast.Load, ast.Call, ast.Constant, ast.Subscript)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise AssertionError("Unsupported expression in actual Pawn experience guard")
    names = {node.id for node in ast.walk(tree) if isinstance(node, ast.Name)}
    if names - values.keys():
        raise AssertionError(f"Unexpected names in actual Pawn experience guard: {names - values.keys()}")
    return bool(eval(compile(tree, "<Pawn experience guard>", "eval"), {"__builtins__": {}}, values))


def can_choose_actual(*, phase="preparing", participant=True, alive=True,
                      zombie=False, ct=True, joined=True, selected=False,
                      enabled=True, now=10, deadline=15, client=1,
                      source=SOURCE) -> bool:
    body = function_body("can_choose_weapon", source)
    predicate = body.split("return", 1)[1].strip()
    return evaluate_experience_predicate(predicate, {
        "id": client, "g_max_players": 32,
        "is_participant": lambda _: participant,  # Explicit TEST DOUBLES.
        "is_user_alive": lambda _: alive,
        "g_is_zombie": {client: zombie}, "cs_get_user_team": lambda _: ct,
        "CS_TEAM_CT": True, "g_phase": phase, "WAITING": "waiting",
        "PREPARING": "preparing", "get_gametime": lambda: now,
        "g_infection_at": deadline, "get_member": lambda *_: joined,
        "m_iJoiningState": "joining", "JOINED": True,
        "g_weapon_selected": {client: selected},
        "get_pcvar_num": lambda _: int(enabled), "g_cvar_weapon_menu": "enabled",
    })


def menu_current_actual(*, same_userid=True, same_round=True, now=10, expires=15, source=SOURCE) -> bool:
    predicate = function_body("weapon_menu_current", source).split("return", 1)[1].strip()
    return evaluate_experience_predicate(predicate, {
        "id": 1, "g_menu_userid": {1: 100 if same_userid else 99},
        "get_user_userid": lambda _: 100, "g_menu_round": {1: 5 if same_round else 4},
        "g_round_serial": 5, "now": now, "g_menu_expires_at": {1: expires},
    })


def remember_choice_actual(*, remember=1, enabled=1, source=SOURCE) -> bool:
    predicate = function_body("remember_weapon_choice", source).split("return", 1)[1].strip()
    flags = {"remember": remember, "enabled": enabled}
    return evaluate_experience_predicate(predicate, {
        "get_pcvar_num": lambda cvar: flags[cvar],  # Explicit TEST DOUBLE.
        "g_cvar_remember_weapons": "remember", "g_cvar_weapon_menu": "enabled",
    })


def memory_assignments_actual(state: dict, event: str, *, remember=1, enabled=1,
                              choice=0, source=SOURCE) -> dict:
    """Apply actual Pawn preference/used assignments, not engine callbacks.

    TEST DOUBLE only: ignores unrelated player/engine operations and does not
    qualify callback dispatch. Unsupported memory writes fail the test parser.
    """
    result = state.copy()
    for line in function_body(event, source).splitlines():
        if not re.search(r"g_weapon_(?:choice|selected)\[id\]\s*=", line):
            continue
        match = re.fullmatch(r"\s*(?:if \((.+)\) )?g_weapon_(choice|selected)\[id\] = (0|true|false|choice)\s*", line)
        if match is None:
            raise AssertionError("Unsupported actual Pawn memory assignment")
        condition, field, value = match.groups()
        if condition and not evaluate_experience_predicate(condition, {
            "remember_weapon_choice": lambda: remember_choice_actual(remember=remember, enabled=enabled, source=source),
        }):
            continue
        result[field] = {"0": 0, "true": True, "false": False, "choice": choice}[value]
    return result


def nvg_observer_actual(*, client=2, connected=True, hltv=False, mode=4,
                        target=1, followed=1, source=SOURCE) -> bool:
    predicate = function_body("is_nightvision_observer", source).split("return", 1)[1].strip()
    return evaluate_experience_predicate(predicate, {
        "observer": client, "target": target, "g_max_players": 32,
        "is_user_connected": lambda _: connected, "is_user_hltv": lambda _: hltv,
        "pev": lambda _, field: mode if field == "mode" else followed,
        "pev_iuser1": "mode", "pev_iuser2": "followed", "OBS_IN_EYE": 4,
    })


class ExperienceGuardTests(unittest.TestCase):
    """Source contracts/decision tables only, not client-visible acceptance."""

    def test_actual_choice_guard_all_phase_role_and_client_states(self) -> None:
        for phase, participant, alive, zombie, ct, joined, selected, enabled, expired in itertools.product(
            ("waiting", "preparing", "infected", "ending"), *[(False, True)] * 8
        ):
            arguments = dict(phase=phase, participant=participant, alive=alive,
                             zombie=zombie, ct=ct, joined=joined, selected=selected,
                             enabled=enabled, now=15 if expired else 14, deadline=15)
            expected = (participant and alive and not zombie and ct and joined and not selected and enabled
                        and (phase == "waiting" or (phase == "preparing" and not expired)))
            with self.subTest(**arguments):
                self.assertEqual(expected, can_choose_actual(**arguments))
        for client in (-1, 0, 33, 99):
            self.assertFalse(can_choose_actual(client=client))

    def test_negative_controls_reject_repeated_choice_and_deadline_regressions(self) -> None:
        for fragment, arguments in (
            (" && !g_weapon_selected[id]", {"selected": True}),
            ("&& (g_phase != PREPARING || get_gametime() < g_infection_at)", {"now": 15}),
            ("&& !g_is_zombie[id]", {"zombie": True}),
        ):
            body = function_body("can_choose_weapon")
            self.assertIn(fragment, body)
            mutated = SOURCE.replace(body, body.replace(fragment, "", 1), 1)
            self.assertFalse(can_choose_actual(**arguments))
            self.assertTrue(can_choose_actual(source=mutated, **arguments), "Negative control did not exercise the removed guard")

    def test_actual_callback_guard_denies_stale_userid_round_state_and_expiry(self) -> None:
        body = function_body("on_weapon_selected")
        predicate = re.search(r"new bool:valid = ([^\n]+)", body).group(1)
        for same_userid, same_round, eligible, now in itertools.product((False, True), (False, True), (False, True), (0, 14.999, 15, 15.001)):
            self.assertEqual(same_userid and same_round and eligible and now < 15, evaluate_experience_predicate(predicate, {
                "id": 1, "get_gametime": lambda: now,
                "weapon_menu_current": lambda _, time: menu_current_actual(same_userid=same_userid, same_round=same_round, now=time),
                "can_choose_weapon": lambda _: eligible,  # Explicit test-only native/state doubles.
            }))
        self.assertFalse(menu_current_actual(expires=0))
        self.assertIn("if (id < 1 || id > g_max_players || menu != g_weapon_menu[id]) return PLUGIN_HANDLED", body)
        self.assertLess(body.index("if (!valid || choice < 0"), body.index("g_weapon_selected[id] = true"))
        self.assertLess(body.index("g_weapon_selected[id] = true"), body.index("give_human_loadout(id)"))
        self.assertNotIn("make_human(", body)  # Menu must never heal/rearmor a player.

    def test_timeout_closes_menu_on_clock_allows_manual_reopen_and_does_not_auto_reopen(self) -> None:
        """Evaluate real expiry/auto predicates; UI calls remain test-only doubles.

        This deliberately covers WAITING (one player), where phase transition
        cannot incidentally remove the old menu and hide the original defect.
        """
        expiry = function_body("expire_weapon_menu")
        predicate = re.search(r"if \((.+)\) close_weapon_menu\(id\)", expiry).group(1)
        menu = {1: 7}  # TEST DOUBLE of the current AMXX resource, not a menu engine.
        for now, expected_close in ((14.999, False), (15, True)):
            should_close = evaluate_experience_predicate(predicate, {
                "id": 1, "g_weapon_menu": menu, "NO_WEAPON_MENU": -1, "now": now,
                "weapon_menu_current": lambda _, time: menu_current_actual(now=time),
            })
            self.assertEqual(expected_close, should_close)
        process = function_body("process_weapon_menus")
        auto_predicate = re.search(r"if \((g_menu_at\[id\].+)\) continue", process).group(1)
        close = function_body("close_weapon_menu")
        self.assertIn("g_menu_at[id] = 0.0", close)
        self.assertIn("g_menu_expires_at[id] = 0.0", close)
        self.assertNotIn("g_weapon_selected[id] = true", close)
        # Closing consumes no choice and schedules no automatic re-opening.
        self.assertTrue(evaluate_experience_predicate(auto_predicate, {"id": 1, "g_menu_at": {1: 0.0}, "now": 16}))
        self.assertTrue(can_choose_actual(phase="waiting", now=16))
        self.assertLess(process.index("expire_weapon_menu(id, now)"), process.index("if (g_menu_at[id] == 0.0"))
        command = function_body("command_weapon_menu")
        self.assertLess(command.index("expire_weapon_menu(id, get_gametime())"), command.index("if (client_has_menu(id))"))
        self.assertLess(command.index("if (client_has_menu(id))"), command.index("show_weapon_menu(id)"))
        show = function_body("show_weapon_menu")
        self.assertLess(show.index("close_weapon_menu(id)"), show.index("g_menu_expires_at[id] = get_gametime() + float(WEAPON_MENU_SECONDS)"))
        self.assertIn("#define WEAPON_MENU_SECONDS 15", SOURCE)
        self.assertIn("menu_display(id, menu, 0, WEAPON_MENU_SECONDS)", show)
        # Negative control: removing the actual expiry guard permits late input.
        body = function_body("weapon_menu_current")
        mutated = SOURCE.replace(body, body.replace(" && now < g_menu_expires_at[id]", "", 1), 1)
        self.assertFalse(menu_current_actual(now=15))
        self.assertTrue(menu_current_actual(now=15, source=mutated))

    def test_auto_menu_uses_single_clock_and_does_not_override_join_or_other_menus(self) -> None:
        self.assertEqual(1, SOURCE.count("set_task("))
        self.assertIn("process_weapon_menus(now)", function_body("round_tick"))
        process = function_body("process_weapon_menus")
        self.assertIn("g_pending_userid[id] != get_user_userid(id)", process)
        self.assertIn("!can_choose_weapon(id)", process)
        self.assertIn("if (!client_has_menu(id)) show_weapon_menu(id)", process)
        other_menu = function_body("client_has_menu")
        self.assertIn("m_iMenu) != Menu_OFF", other_menu)
        self.assertIn("player_menu_info(id, old_menu, new_menu) != 0", other_menu)
        self.assertIn("g_pending_userid[id] = get_user_userid(id)", function_body("make_human"))
        self.assertIn("is_user_bot(id)", function_body("make_human"))

    def test_menu_cleanup_invalidates_owner_before_synchronous_callback(self) -> None:
        body = function_body("close_weapon_menu")
        self.assertLess(body.index("g_weapon_menu[id] = NO_WEAPON_MENU"), body.index("menu_cancel(id)"))
        self.assertIn("active_menu == menu", body)
        self.assertLess(body.index("active_menu == menu"), body.index("show_menu(id, 0,"))
        self.assertEqual(1, body.count("menu_destroy(menu)"))
        for name in ("client_putinserver", "client_disconnected", "on_new_round", "make_human", "make_zombie", "on_player_killed_post", "begin_infection"):
            self.assertIn("close_weapon_menu(", function_body(name))
        for name in ("on_round_end", "finish_round", "plugin_end"):
            self.assertIn("clear_round_experience()", function_body(name))

    def test_replaces_loadout_and_prevents_drop_or_menu_ammo_farming(self) -> None:
        init = function_body("plugin_init")
        self.assertIn('register_clcmd("drop", "command_block_buy")', init)
        body = function_body("give_human_loadout")
        self.assertLess(body.index("strip_user_weapons(id)"), body.index("give_item("))
        self.assertIn("cs_set_user_bpammo(id, HUMAN_WEAPON_IDS[index], 0)", body)
        self.assertIn("cs_set_user_bpammo(id, HUMAN_WEAPON_IDS[choice], HUMAN_WEAPON_AMMO[choice])", body)
        self.assertIn("if (!remember_weapon_choice()) g_weapon_choice[id] = 0", function_body("on_new_round"))
        for name in ("client_putinserver", "client_disconnected", "on_new_round"):
            self.assertIn("g_weapon_selected[id] = false", function_body(name))
        self.assertNotIn("g_weapon_selected[id] = false", function_body("on_player_killed_post"))

    def test_nvg_grants_stock_ownership_and_clears_both_effect_and_engine_flag(self) -> None:
        self.assertIn("cs_set_user_nvg(id, 1)", function_body("make_zombie"))
        self.assertNotIn("m_bNightVisionOn, true", SOURCE)
        self.assertIn("cs_set_user_nvg(id, 0)", function_body("clear_nightvision"))
        clear = function_body("clear_nightvision_effect")
        for fragment in ("set_member(id, m_bNightVisionOn, false)", "g_nvg_message", "write_byte(0)"):
            self.assertIn(fragment, clear)
        for name in ("make_human", "make_zombie", "client_disconnected", "on_new_round", "on_player_killed_post", "clear_round_experience"):
            self.assertIn("clear_nightvision(", function_body(name))
        self.assertNotRegex(SOURCE, r'register_clcmd\("(?:nightvision|n)"')
        self.assertNotRegex(SOURCE, r"precache_(?:model|sound|generic)\s*\(")

    def test_remembered_primary_round_respawn_and_connection_boundaries(self) -> None:
        for remember, enabled, primary in itertools.product((-1, 0, 1), (-1, 0, 1), range(4)):
            expected_remember = remember != 0 and enabled != 0
            self.assertEqual(expected_remember, remember_choice_actual(remember=remember, enabled=enabled))
            state = {"choice": primary, "selected": True}
            for event in ("on_player_killed_post", "make_human", "make_zombie", "clear_round_experience", "finish_round"):
                self.assertEqual(state, memory_assignments_actual(state, event, remember=remember, enabled=enabled))
            self.assertEqual({"choice": primary if expected_remember else 0, "selected": False},
                             memory_assignments_actual(state, "on_new_round", remember=remember, enabled=enabled))
            for event in ("client_disconnected", "client_putinserver"):
                self.assertEqual({"choice": 0, "selected": False}, memory_assignments_actual(state, event))
            self.assertEqual({"choice": primary, "selected": True},
                             memory_assignments_actual({"choice": 0, "selected": False}, "on_weapon_selected", choice=primary))
        # A normal next-round spawn uses the retained primary; only a new explicit
        # accepted callback consumes that round's replacement opportunity.
        self.assertIn("give_human_loadout(id)", function_body("make_human"))
        self.assertIn("g_weapon_choice[id]", function_body("give_human_loadout"))
        self.assertIn('register_cvar("kgb_zi_remember_weapons", "1")', function_body("plugin_init"))
        self.assertIn('kgb_zi_remember_weapons "1"', CONFIG)
        self.assertNotRegex(SOURCE, r"(?:nvault_|fvault_|SQL_|get_user_authid|set_user_info)\s*\(")

    def test_memory_negative_controls_catch_round_and_slot_leaks(self) -> None:
        state = {"choice": 3, "selected": True}
        for original, replacement, event, arguments in (
            ("if (!remember_weapon_choice()) g_weapon_choice[id] = 0", "g_weapon_choice[id] = 0", "on_new_round", {}),
            ("if (!remember_weapon_choice()) g_weapon_choice[id] = 0", "if (remember_weapon_choice()) g_weapon_choice[id] = 0", "on_new_round", {}),
            ("g_weapon_choice[id] = 0", "", "client_disconnected", {}),
            ("g_weapon_choice[id] = 0", "", "client_putinserver", {}),
        ):
            body = function_body(event)
            mutated = SOURCE.replace(body, body.replace(original, replacement, 1), 1)
            self.assertNotEqual(memory_assignments_actual(state, event, **arguments),
                                memory_assignments_actual(state, event, source=mutated, **arguments))
        for guard, arguments in (("get_pcvar_num(g_cvar_remember_weapons) != 0 && ", {"remember": 0}),
                                 (" && get_pcvar_num(g_cvar_weapon_menu) != 0", {"enabled": 0})):
            body = function_body("remember_weapon_choice")
            self.assertIn(guard, body)
            mutated = SOURCE.replace(body, body.replace(guard, "", 1), 1)
            self.assertFalse(remember_choice_actual(**arguments))
            self.assertTrue(remember_choice_actual(source=mutated, **arguments))

    def test_nvg_cleanup_targets_only_native_first_person_followers(self) -> None:
        for client, connected, hltv, mode, followed in itertools.product(
            (1, 2), (False, True), (False, True), (0, 1, 2, 4, 5, 6), (1, 3)
        ):
            self.assertEqual(client != 1 and connected and not hltv and mode == 4 and followed == 1,
                             nvg_observer_actual(client=client, connected=connected, hltv=hltv, mode=mode, followed=followed))
        for client in (-1, 0, 33, 99):
            self.assertFalse(nvg_observer_actual(client=client))
        cleanup = function_body("clear_nightvision")
        # The observer loop is outside the connected-target block, so an already
        # cleared/departed target cannot strand its exact in-eye followers.
        self.assertRegex(cleanup, r"clear_nightvision_effect\(id\)\s*\}\s*//[\s\S]*?for \(new observer")
        self.assertIn("if (is_nightvision_observer(observer, id)) clear_nightvision_effect(observer)", cleanup)
        self.assertNotIn("cs_set_user_nvg(", function_body("clear_nightvision_effect"))
        for fragment, arguments in (
            ("&& pev(observer, pev_iuser1) == OBS_IN_EYE ", {"mode": 1}),
            ("&& pev(observer, pev_iuser2) == target", {"followed": 3}),
            (" && !is_user_hltv(observer)", {"hltv": True}),
        ):
            body = function_body("is_nightvision_observer")
            self.assertIn(fragment, body)
            mutated = SOURCE.replace(body, body.replace(fragment, "", 1), 1)
            self.assertFalse(nvg_observer_actual(**arguments))
            self.assertTrue(nvg_observer_actual(source=mutated, **arguments))

    def test_player_hints_name_current_loadout_and_keep_native_nvg_dispatch(self) -> None:
        self.assertIn("HUMAN_WEAPON_LABELS[choice]", function_body("make_human"))
        self.assertIn("Type /guns", function_body("make_human"))
        self.assertIn("Current: %s", function_body("show_weapon_menu"))
        self.assertIn("remembered until you leave", function_body("on_weapon_selected"))
        self.assertIn("Press N", function_body("make_zombie"))
        self.assertIn("/guns", function_body("command_player_status"))
        self.assertNotRegex(SOURCE, r'register_clcmd\("nightvision"')


if __name__ == "__main__":
    unittest.main(verbosity=2)
