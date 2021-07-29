#include <amxmodx>
#include <amxmisc>
#include <reapi>

// PREPARE DATA
enum _:pSkillKey {
  pId = 0,
  pSkill
}

new playerHs[MAX_CLIENTS + 1], playerKills[MAX_CLIENTS + 1], playerDeaths[MAX_CLIENTS + 1];

new bool:playerToTransfer[MAX_CLIENTS + 1];

new cvarScoreDifference, cvarMinPlayers, cvarNoRound;

new userMessage_ScreenFade;

// PLUGIN INIT
public plugin_init() {
  register_plugin("Team Balance Lite", "1.0", "szawesome");

  RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true);
  RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Pre", false);
  RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
  
  cvarScoreDifference = register_cvar("tbl_scorediff", "10");
  cvarMinPlayers = register_cvar("tbl_minplayers", "5");
  cvarNoRound = register_cvar("tbl_noround", "0");

  userMessage_ScreenFade = get_user_msgid("ScreenFade");
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

  if(!get_pcvar_num(cvarNoRound)) {    
    playerKills[killer]++;
    playerDeaths[victim]++;

    if(get_member(victim, m_bHeadshotKilled)) {
      playerHs[killer]++;
    }
  }

  return HC_CONTINUE;
}

public CBasePlayer_Spawn_Pre(id) {
  if(get_pcvar_num(cvarNoRound)) {
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

  if(!get_pcvar_num(cvarNoRound)) {
    new difference;
    static nextCheck;
    
    nextCheck--;
    
    GetTeamsScore(difference);
    
    if(nextCheck <= 0 && difference >= get_pcvar_num(cvarScoreDifference)) {
      new bestPlayer, worstPlayer, CTNum, TTNum;
      GetBestWorstPlayers(bestPlayer, worstPlayer, CTNum, TTNum);
      
      new minPlayers = get_pcvar_num(cvarMinPlayers);
      if(minPlayers < 6 || minPlayers > 32) {
        minPlayers = 6;
      }

      if(CTNum + TTNum >= minPlayers) {
        nextCheck = get_pcvar_num(cvarScoreDifference);

        playerToTransfer[bestPlayer] = true;
        playerToTransfer[worstPlayer] = true;
      }
    }
  }

  return HC_CONTINUE;
}

// CUSTOM FUNTIONS
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

  new iMinPlayers = get_pcvar_num(cvarMinPlayers);
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
      
      if(!get_pcvar_num(cvarNoRound) && !is_user_bot(id)) {
        SendNoticeMessage(id);
        // set_task_ex(0.1, "SendNoticeMessage", .flags = SetTask_Once); // skip reset hud. как тут id игрока передать?
      } else {
        SendNoticeMessage(id);
      }
    }
  }
}

public SendNoticeMessage(id) {
  if(is_user_connected(id) && !is_user_bot(id)) {
    set_dhudmessage(255, 200, 0, -1.0, -0.29, 2, _, 5.0, 0.07);

    if(get_member(id, m_iTeam) == TEAM_TERRORIST) {
      screen_fade(id, 255, 0, 0, 100, 1);
      show_dhudmessage(id, "Вы были переведены за Террористов");
    } else {
      screen_fade(id, 0, 0, 255, 100, 1);
      show_dhudmessage(id, "Вы были переведены за Контр-Террористов");
    }
    
    client_cmd(id, "spk fvox/bell");
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

stock screen_fade(id, red, green, blue, alfa, durration) {
  new dUnits = clamp((durration * (1 << 12)), 0, 0xFFFF);

  message_begin(MSG_ONE_UNRELIABLE, userMessage_ScreenFade, _, id);
  write_short(dUnits); //Durration
  write_short(dUnits/2); //Hold
  write_short(0x0000); // Type
  write_byte(red);
  write_byte(green);
  write_byte(blue);
  write_byte(alfa);
  message_end();
}