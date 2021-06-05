#include <amxmodx>
#include <reapi>

#define clearPlayer(%0) arrayset(Players[%0], 0, sizeof Players)
#define eventBit(%0) (1 << _:%0)

const ROUND_EVENTS = eventBit(ROUND_GAME_COMMENCE) | eventBit(ROUND_GAME_RESTART) | eventBit(ROUND_GAME_OVER);

new cvarMoneyBonus;

enum _:Player {
  PlayerKills,
  PlayerDmg
}

new Players[MAX_CLIENTS + 1][Player];

public plugin_init() {
  register_plugin("Best Player of the Round", "1.0", "szawesome");

  RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Post", true);
  RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true);
  RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", true);
  
  cvarMoneyBonus = register_cvar("bpr_money", "1000");
}

public client_putinserver(id) {
  clearPlayer(id);
}

public client_disconnected(id) {
  clearPlayer(id);
}

public CBasePlayer_TakeDamage_Post(victim, inflictor, attacker, Float:damage, damageType) {
  if (victim == attacker || !is_user_connected(attacker) || !rg_is_player_can_takedamage(victim, attacker)) {
    return HC_CONTINUE;
  }

  Players[attacker][PlayerDmg] += floatround(damage);
  return HC_CONTINUE;
}

public CBasePlayer_Killed_Post(victim, attacker) {
  if (victim == attacker || !is_user_connected(attacker) || !rg_is_player_can_takedamage(victim, attacker)) {
    return HC_CONTINUE;
  }
  
  Players[attacker][PlayerKills]++;

  return HC_CONTINUE;
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
  if (eventBit(event) & ROUND_EVENTS == 0 && event != ROUND_NONE) {
    set_task(1.0, "TaskRoundEnd");
  } else {
    for (new i = 1; i <= MaxClients; i++) {
      clearPlayer(i);
    }
  }
}

public TaskRoundEnd() {
  new players[MAX_CLIENTS], num;
  get_players(players, num, "h");

  if (num <= 0) {
    return;
  }
  
  new maxId;
  for (new i = 0, player; i < num; i++) {
    player = players[i];
    if (Players[player][PlayerKills] > Players[maxId][PlayerKills] || (Players[player][PlayerKills] == Players[maxId][PlayerKills] && Players[player][PlayerDmg] > Players[maxId][PlayerDmg])) {
      maxId = player;
    }
  }

  if (maxId == 0) {
    for (new i = 0; i < num; i++) {
      clearPlayer(players[i]);
    }
    return;
  }

  new moneyBonus = get_pcvar_num(cvarMoneyBonus);
  if (moneyBonus > 0) {
    rg_add_account(maxId, moneyBonus, AS_ADD, true);
    client_print_color(0, maxId, "^4Лучший игрок раунда ^3%n^4 убил ^3%d^4 и нанёс ^3%d^4 урона!", maxId, Players[maxId][PlayerKills], Players[maxId][PlayerDmg]);
    client_print_color(maxId, maxId, "^4Ты получил ^3%d$^4 бонуса!", moneyBonus);
  }

  clearPlayer(maxId);
}