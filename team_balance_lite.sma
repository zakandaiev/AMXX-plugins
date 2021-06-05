#include <amxmodx>
#include <amxmisc>
#include <reapi>

// PREPARE DATA
enum _:Teams {
  TeamTT = 1,
  TeamCT
}
enum _:pSkillKey {
  pId = 0,
  pSkill
}

const CHECK_INTERVAL = 10;

new playerHs[MAX_CLIENTS + 1], playerKills[MAX_CLIENTS + 1], playerDeaths[MAX_CLIENTS + 1];

new teamScore[Teams + 1];

new cvarScoreDifference, cvarMinPlayers, cvarNoRound, getMaxPlayers;

new userMessage_ScreenFade;

// PLUGIN INIT
public plugin_init() {
  register_plugin("Team Balance Lite", "1.0", "szawesome");
  
  register_event("DeathMsg", "EventDeath", "a");
  register_event("TeamScore", "EventScore", "a");
  register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
  register_event("TextMsg", "EventClear", "a", "2&#Game_C", "2&#Game_w");
  
  cvarScoreDifference = register_cvar("tbl_scorediff", "10");
  cvarMinPlayers = register_cvar("tbl_minplayers", "5");
  cvarNoRound = register_cvar("tbl_noround", "0");
  
  getMaxPlayers = get_maxplayers();

  userMessage_ScreenFade = get_user_msgid("ScreenFade");
}

// PUBLIC FUNTIONS
public client_putinserver(id) {
  playerHs[id] = 0;
  playerKills[id] = 0;
  playerDeaths[id] = 0;
}

public client_disconnected(id) {
  playerHs[id] = 0;
  playerKills[id] = 0;
  playerDeaths[id] = 0;
}

public EventClear() {
  arrayset(teamScore, 0, Teams + 1);
  arrayset(playerHs, 0, MAX_CLIENTS + 1);
  arrayset(playerKills, 0, MAX_CLIENTS + 1);
  arrayset(playerDeaths, 0, MAX_CLIENTS + 1);
}

public EventDeath() {
  if(!get_pcvar_num(cvarNoRound)) {
    new iKiller = read_data(1);
  
    if(read_data(3)) {
      playerHs[iKiller]++;
    }
    
    playerKills[iKiller]++;
    playerDeaths[read_data(2)]++;
  } else {
    static iKills; 
    iKills++;
    
    if(!(iKills % CHECK_INTERVAL)) {
      BalanceTeamsToEqualNum();
    }
  }
}

public EventScore() { 
  new szTeam[1];
  read_data(1, szTeam, 1);

  if(szTeam[0] == 'C') teamScore[TeamCT] = read_data(2);
  else teamScore[TeamTT] = read_data(2);
}

public EventNewRound() {
  if(!get_pcvar_num(cvarNoRound)) {
    new iDifference;
    static iNextCheck;
    
    iNextCheck--;
    
    CheckTeamsScore(iDifference);
    
    if(iNextCheck <= 0 && iDifference >= get_pcvar_num(cvarScoreDifference)) {
      new iBestPlayer, iWorstPlayer, iCTNum, iTTNum;
      GetActualPlayers(iBestPlayer, iWorstPlayer, iCTNum, iTTNum);
      
      new iMinPlayers = get_pcvar_num(cvarMinPlayers);
      if(iMinPlayers < 6 || iMinPlayers > 32) {
        iMinPlayers = 6;
      }

      if(iCTNum + iTTNum >= iMinPlayers) {
        iNextCheck = get_pcvar_num(cvarScoreDifference);

        TransferPlayer(iBestPlayer);
        TransferPlayer(iWorstPlayer);

        /*server_print("Best Player %n", iBestPlayer);
        server_print("Worst Player %n", iWorstPlayer);*/
      }
    }
  }
}

// CUSTOM FUNTIONS
CheckTeamsScore(&iDifference) {
  if(teamScore[TeamCT] > teamScore[TeamTT]) {
    iDifference = teamScore[TeamCT] - teamScore[TeamTT];
  }
  
  if(teamScore[TeamTT] > teamScore[TeamCT]) {
    iDifference = teamScore[TeamTT] - teamScore[TeamCT];
  }
}

GetActualPlayers(&iBestPlayer, &iWorstPlayer, &iCTNum, &iTTNum) {
  new Float:iCTPlayersSkill[MAX_CLIENTS + 1][pSkillKey];
  new Float:iTTPlayersSkill[MAX_CLIENTS + 1][pSkillKey];
  new iKills, iDeaths, iHs;

  for(new id = 1; id <= getMaxPlayers; id++) {
    if(!is_user_connected(id)) continue;

    switch(get_member(id, m_iTeam)) {
      case TEAM_CT: {
        iCTNum++

        iHs = playerHs[id];
        iKills = playerKills[id];
        iDeaths = playerDeaths[id];

        iCTPlayersSkill[id][pId] = Float:id;
        iCTPlayersSkill[id][pSkill] = get_skill(iKills, iDeaths, iHs);
      }
      case TEAM_TERRORIST: {
        iTTNum++

        iHs = playerHs[id];
        iKills = playerKills[id];
        iDeaths = playerDeaths[id];

        iTTPlayersSkill[id][pId] = Float:id;
        iTTPlayersSkill[id][pSkill] = get_skill(iKills, iDeaths, iHs);
      }
      default: continue;
    }
  }

  new iMinPlayers = get_pcvar_num(cvarMinPlayers);
  if(iMinPlayers < 6 || iMinPlayers > 32) iMinPlayers = 6;
  if(iCTNum + iTTNum < iMinPlayers) return;

  SortCustom2D(_:iCTPlayersSkill, sizeof(iCTPlayersSkill) , "SortDesc");
  SortCustom2D(_:iTTPlayersSkill, sizeof(iTTPlayersSkill) , "SortDesc");

  if(teamScore[TeamCT] > teamScore[TeamTT]) { // если КТ побеждает
    iBestPlayer = _:iCTPlayersSkill[0][pId]; // выбираем самого первого КТ из массива (с самым высоким скиллом)
    iWorstPlayer = _:iTTPlayersSkill[iTTNum-1][pId]; // выбираем самого последнего доступного игрока (с самым плохим скиллом) (после него идут пустые индексы если онлайн ниже 32)
  } else {
    iBestPlayer = _:iTTPlayersSkill[0][pId];
    iWorstPlayer = _:iCTPlayersSkill[iCTNum-1][pId];
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

BalanceTeamsToEqualNum() {
  new iNums[Teams + 1];
  new iTTNum, iCTNum;
  new iPlayers[Teams + 1][32];
  new iNumToSwap, iTeamToSwap;
  
  for(new id = 1; id <= getMaxPlayers; id++) {
    if(!is_user_connected(id)) continue;
    
    switch(get_member(id, m_iTeam)) {
      case TEAM_CT: iPlayers[TeamCT][iNums[TeamCT]++] = id;
      case TEAM_TERRORIST: iPlayers[TeamTT][iNums[TeamTT]++] = id;
      default: continue;
    }
  }
  
  iTTNum = iNums[TeamTT];
  iCTNum = iNums[TeamCT];
  
  //Узнаем сколько игроков нужно перевести
  if(iTTNum > iCTNum) {
    iNumToSwap = ( iTTNum - iCTNum ) / 2;
    iTeamToSwap = TeamTT;
  } else if(iCTNum > iTTNum) {
    iNumToSwap = (iCTNum - iTTNum) / 2;
    iTeamToSwap = TeamCT;
  } else return PLUGIN_CONTINUE;  // Balance isn't needed, because teams are equal
  
  if(!iNumToSwap) return PLUGIN_CONTINUE;   // Balance isn't needed

  for(new i = 0; i <= iNumToSwap; i++) {
    TransferPlayer(iPlayers[iTeamToSwap][i]);
  }
  
  return PLUGIN_CONTINUE;
}

TransferPlayer(const id) {
  new TeamName:iTeam;
    
  if(is_user_connected(id)) {
    iTeam = get_member(id, m_iTeam);

    if(TEAM_TERRORIST <= iTeam <= TEAM_CT) {
      if(is_user_alive(id) && user_has_weapon(id, CSW_C4)) {
        rg_drop_items_by_slot(id, C4_SLOT);
      }

      rg_switch_team(id);

      if(is_user_alive(id)) {
        rg_round_respawn(id);
      }
      
      if(!is_user_bot(id)) {
        set_dhudmessage(255, 200, 0, -1.0, -0.29, 2, _, 5.0, 0.07);

        if(iTeam == TEAM_TERRORIST) {
          screen_fade(id, 0, 0, 255, 100, 1);
          show_dhudmessage(id, "Вы были переведены за Контр-Террористов");
        } else {
          screen_fade(id, 255, 0, 0, 100, 1);
          show_dhudmessage(id, "Вы были переведены за Террористов");
        }
        
        client_cmd(id, "spk fvox/bell");
      }
    }
  }
}

Float:get_skill(iKills, iDeaths, iHeadShots) {
  new Float:fSkill;
  if(iDeaths == 0) {
    iDeaths = 1;
  }
  fSkill = (float(iKills) + float(iHeadShots)) / float(iDeaths);
  return fSkill;
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