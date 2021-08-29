#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define AUTO_CFG // автоматическое создание конфига с кварами

// PREPARE DATA
enum pSkillKey {
  pId = 0,
  pSkill
}

new playerHs[MAX_CLIENTS + 1], playerKills[MAX_CLIENTS + 1], playerDeaths[MAX_CLIENTS + 1];

new bool:playerToTransfer[MAX_CLIENTS + 1];

enum CVARS {
  SCORE_DIFFERENCE,
  MIN_PLAYERS,
  DM_MODE
};

new cvar[CVARS];

// PLUGIN INIT
public plugin_init() {
  register_plugin("Team Balance Lite", "1.1", "szawesome");

  RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true);
  RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", false);
  RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);

  RegisterCvars();
}

// PUBLIC FUNTIONS
public client_putinserver(id) {
  playerHs[id] = 0;
  playerKills[id] = 0;
  playerDeaths[id] = 0;
  playerToTransfer[id] = false;
}

public client_disconnected(id) {
  playerHs[id] = 0;
  playerKills[id] = 0;
  playerDeaths[id] = 0;
  playerToTransfer[id] = false;
}

public CBasePlayer_Killed_Post(victim, killer, gibs) {
  if(!is_user_connected(victim) || !is_user_connected(killer)) {
    return HC_SUPERCEDE;
  }

  if(!get_pcvar_num(cvar[DM_MODE])) {    
    playerKills[killer]++;
    playerDeaths[victim]++;

    if(get_member(victim, m_bHeadshotKilled)) {
      playerHs[killer]++;
    }
  }

  return HC_CONTINUE;
}

public CBasePlayer_Spawn_Pre(id) {
  if(get_pcvar_num(cvar[DM_MODE])) {
    ModeDM_SetPlayerToTranfer(id);
  }

  if(is_user_connected(id) && playerToTransfer[id]) {
    TransferPlayer(id);
    playerToTransfer[id] = false;
  }

  return HC_CONTINUE;
}

public CSGameRules_RestartRound_Pre() {
  if(bool:get_member_game(m_bCompleteReset)) {
    ClearArrays();
  }

  if(!get_pcvar_num(cvar[DM_MODE])) {
    new difference;
    static nextCheck;
    
    nextCheck--;
    
    GetTeamsScore(difference);
    
    if(nextCheck <= 0 && difference >= get_pcvar_num(cvar[SCORE_DIFFERENCE])) {
      new bestPlayer, worstPlayer, CTNum, TTNum;
      GetBestWorstPlayers(bestPlayer, worstPlayer, CTNum, TTNum);
      
      new minPlayers = get_pcvar_num(cvar[MIN_PLAYERS]);
      if(minPlayers < 6 || minPlayers > 32) {
        minPlayers = 6;
      }

      if(CTNum + TTNum >= minPlayers) {
        nextCheck = get_pcvar_num(cvar[SCORE_DIFFERENCE]);

        playerToTransfer[bestPlayer] = true;
        playerToTransfer[worstPlayer] = true;
      }
    }
  }

  return HC_CONTINUE;
}

// CUSTOM FUNTIONS
RegisterCvars() {
  cvar[SCORE_DIFFERENCE] = create_cvar(
    .name = "tbl_score_diff", 
    .string = "10",
    .flags = FCVAR_NONE,
    .description = "Разница в счёте команд, при которой произойдет баланс",
    .has_min = true, 
    .min_val = 1.0
  );
  cvar[MIN_PLAYERS] = create_cvar(
    .name = "tbl_min_players", 
    .string = "7",
    .flags = FCVAR_NONE,
    .description = "Минимальное количество игроков для балансировки команд",
    .has_min = true, 
    .min_val = 6.0,
    .has_max = true, 
    .max_val = 32.0
  );
  cvar[DM_MODE] = create_cvar(
    .name = "tbl_dm_mode", 
    .string = "0",
    .flags = FCVAR_NONE,
    .description = "Включает баланс по равенству в режиме DM (бесконечный раунд)",
    .has_min = true, 
    .min_val = 0.0,
    .has_max = true, 
    .max_val = 1.0
  );
  #if defined AUTO_CFG
  AutoExecConfig();
  #endif
}

ClearArrays() {
  arrayset(playerHs, 0, MAX_CLIENTS + 1);
  arrayset(playerKills, 0, MAX_CLIENTS + 1);
  arrayset(playerDeaths, 0, MAX_CLIENTS + 1);
  arrayset(playerToTransfer, false, MAX_CLIENTS + 1);
}

ModeDM_SetPlayerToTranfer(id) {
  new TTNum, CTNum;
      
  for(new player = 1; player <= MaxClients; player++) {
    if(!is_user_connected(player) || is_user_hltv(player)) continue;
    switch(TeamName:get_member(player, m_iTeam)) {
      case TEAM_TERRORIST: TTNum++;
      case TEAM_CT: CTNum++;
      default: continue;
    }
  }

  if(abs(TTNum - CTNum) > 1) {
    if(
        (TTNum - CTNum) > 0 && get_member(id, m_iTeam) == TEAM_TERRORIST
        ||
        (CTNum - TTNum) > 0 && get_member(id, m_iTeam) == TEAM_CT
      ) {
      playerToTransfer[id] = true;
    }
  }
}

GetTeamsScore(&difference) {
  if(get_member_game(m_iNumCTWins) > get_member_game(m_iNumTerroristWins)) {
    difference = get_member_game(m_iNumCTWins) - get_member_game(m_iNumTerroristWins);
  }
  
  if(get_member_game(m_iNumTerroristWins) > get_member_game(m_iNumCTWins)) {
    difference = get_member_game(m_iNumTerroristWins) - get_member_game(m_iNumCTWins);
  }
}

GetBestWorstPlayers(&bestPlayer, &worstPlayer, &CTNum, &TTNum) {
  new Float:CTPlayersSkill[MAX_CLIENTS + 1][pSkillKey];
  new Float:TTPlayersSkill[MAX_CLIENTS + 1][pSkillKey];
  new kills, deaths, headshots;

  for(new id = 1; id <= MaxClients; id++) {
    if(!is_user_connected(id) || is_user_hltv(id)) continue;

    switch(TeamName:get_member(id, m_iTeam)) {
      case TEAM_CT: {
        CTNum++

        headshots = playerHs[id];
        kills = playerKills[id];
        deaths = playerDeaths[id];

        CTPlayersSkill[id][pId] = Float:id;
        CTPlayersSkill[id][pSkill] = get_skill(kills, deaths, headshots);
      }
      case TEAM_TERRORIST: {
        TTNum++

        headshots = playerHs[id];
        kills = playerKills[id];
        deaths = playerDeaths[id];

        TTPlayersSkill[id][pId] = Float:id;
        TTPlayersSkill[id][pSkill] = get_skill(kills, deaths, headshots);
      }
      default: continue;
    }
  }

  new iMinPlayers = get_pcvar_num(cvar[MIN_PLAYERS]);
  if(iMinPlayers < 6 || iMinPlayers > 32) iMinPlayers = 6;
  if(CTNum + TTNum < iMinPlayers) return;

  SortCustom2D(_:CTPlayersSkill, sizeof(CTPlayersSkill) , "SortDesc");
  SortCustom2D(_:TTPlayersSkill, sizeof(TTPlayersSkill) , "SortDesc");

  if(get_member_game(m_iNumCTWins) > get_member_game(m_iNumTerroristWins)) { // если КТ побеждает
    bestPlayer = _:CTPlayersSkill[0][pId]; // выбираем самого первого КТ из массива (с самым высоким скиллом)
    worstPlayer = _:TTPlayersSkill[TTNum-1][pId]; // выбираем самого последнего доступного игрока (с самым плохим скиллом) (после него идут пустые индексы если онлайн ниже 32)
  } else {
    bestPlayer = _:TTPlayersSkill[0][pId];
    worstPlayer = _:CTPlayersSkill[CTNum-1][pId];
  }
}

public SortDesc(Float:elem1[], Float:elem2[]) {
  if(elem1[pId] == 0) { // not a player
    return 1;
  } else if(elem1[pSkill] > elem2[pSkill]) {
    return -1;
  } else if(elem1[pSkill] < elem2[pSkill]) {
    return 1;
  }
  return 0;
}

TransferPlayer(id) {  
  if(is_user_connected(id)) {
    new TeamName:iTeam = get_member(id, m_iTeam);

    if(TEAM_TERRORIST <= iTeam <= TEAM_CT) {
      if(is_user_alive(id) && user_has_weapon(id, CSW_C4)) {
        rg_drop_items_by_slot(id, C4_SLOT);
      }

      rg_switch_team(id);

      /*if(is_user_alive(id)) {
        rg_round_respawn(id);
      }*/
      
      // skip reset hud event
      new data[1]; data[0] = id;
      set_task_ex(0.1, "SendNoticeMessage", _, data, 1, SetTask_Once);
    }
  }
}

public SendNoticeMessage(data[1]) {
  if(is_user_connected(data[0]) && !is_user_bot(data[0])) {
    set_dhudmessage(255, 255, 0, -1.0, -0.29, 2, _, 5.0, 0.07);

    if(get_member(data[0], m_iTeam) == TEAM_TERRORIST) {
      screen_fade(data[0], 255, 0, 0, 100, 1);
      show_dhudmessage(data[0], "Вы были переведены за Террористов");
    } else {
      screen_fade(data[0], 0, 0, 255, 100, 1);
      show_dhudmessage(data[0], "Вы были переведены за Контр-Террористов");
    }
    
    client_cmd(data[0], "spk fvox/bell");
  }
}

Float:get_skill(kills, deaths, headShots) {
  new Float:skill;
  if(deaths == 0) {
    deaths = 1;
  }
  skill = (float(kills) + float(headShots)) / float(deaths);
  return skill;
}

stock screen_fade(player, red, green, blue, alfa, durration) {
  if(bool:(Float:get_member(player, m_blindStartTime) + Float:get_member(player, m_blindFadeTime) >= get_gametime())) {
    return;
  }

  new dUnits = clamp((durration * (1 << 12)), 0, 0xFFFF);

  static userMessage_ScreenFade;
  if(userMessage_ScreenFade > 0 || (userMessage_ScreenFade = get_user_msgid("ScreenFade"))) {
    message_begin(MSG_ONE_UNRELIABLE, userMessage_ScreenFade, .player = player);
    write_short(dUnits); //Durration
    write_short(dUnits/2); //Hold
    write_short(0x0000); // Type
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(alfa);
    message_end();
  }
}