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

    def test_team_lock_hooks_shared_engine_path_and_returns_false(self) -> None:
        init = function_body("plugin_init")
        self.assertIn('RegisterHookChain(RG_HandleMenu_ChooseTeam, "on_choose_team_pre", false)', init)
        self.assertNotIn('register_clcmd("jointeam"', init)
        self.assertNotIn("public command_jointeam(", SOURCE)
        body = function_body("on_choose_team_pre")
        self.assertIn("slot != MenuChoose_Spec", body)
        self.assertIn("SetHookChainReturn(ATYPE_BOOL, false)", body)
        self.assertIn("return HC_SUPERCEDE", body)
        self.assertIn("return HC_CONTINUE", body)
        self.assertLess(body.index("SetHookChainReturn(ATYPE_BOOL, false)"), body.index("return HC_SUPERCEDE"))
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
        self.assertIn('BUILD_COMPONENTS: "core acceptance-helper"', workflow)
        self.assertNotIn("compiled/kgb_zi_acceptance_helper", workflow)

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
