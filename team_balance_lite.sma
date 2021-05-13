#include <amxmodx>
#include <cstrike>

// PREPARE DATA
enum _:Teams {
  TeamTT = 1,
  TeamCT
}
enum _:pSkillKey {
  pId = 0,
  pSkill
}

const MAXPLAYERS = 32;

new g_iPlayerHs[MAXPLAYERS + 1], g_iPlayerKills[MAXPLAYERS + 1], g_iPlayerDeaths[MAXPLAYERS + 1];

new g_eTeamScore[Teams + 1];

new g_pScoreDifference, g_pMinPlayers, g_iMaxPlayers;

new g_iMsgId_ScreenFade;

// PLUGIN INIT
public plugin_init() {
  register_plugin("Team Balance Lite", "1.2", "szawesome");
  
  register_event("DeathMsg", "EventDeath", "a");
  register_event("TeamScore", "EventScore", "a");
  register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
  register_event("TextMsg", "EventClear", "a", "2&#Game_C", "2&#Game_w");
  
  g_pScoreDifference = register_cvar("tbl_scorediff", "10");
  g_pMinPlayers = register_cvar("tbl_minplayers", "5");
  
  g_iMaxPlayers = get_maxplayers();

  g_iMsgId_ScreenFade = get_user_msgid("ScreenFade");
}

// PUBLIC FUNTIONS
public client_putinserver(id) {
  g_iPlayerHs[id] = 0;
  g_iPlayerKills[id] = 0;
  g_iPlayerDeaths[id] = 0;
}

public client_disconnected(id) {
  g_iPlayerHs[id] = 0;
  g_iPlayerKills[id] = 0;
  g_iPlayerDeaths[id] = 0;
}

public EventClear() {
  arrayset(g_eTeamScore, 0, Teams + 1);
  arrayset(g_iPlayerHs, 0, MAXPLAYERS + 1);
  arrayset(g_iPlayerKills, 0, MAXPLAYERS + 1);
  arrayset(g_iPlayerDeaths, 0, MAXPLAYERS + 1);
}

public EventDeath() {
  new iKiller = read_data(1);
  
  if(read_data(3)) {
    g_iPlayerHs[iKiller]++;
  }
  
  g_iPlayerKills[iKiller]++;
  g_iPlayerDeaths[read_data(2)]++;
}

public EventScore() { 
  new szTeam[1];
  read_data(1, szTeam, 1);

  if(szTeam[0] == 'C') g_eTeamScore[TeamCT] = read_data(2);
  else g_eTeamScore[TeamTT] = read_data(2);
}

public EventNewRound() {
  new iDifference;
  static iNextCheck;
  
  iNextCheck--;
  
  CheckTeamsScore(iDifference);
  
  if(iNextCheck <= 0 && iDifference >= get_pcvar_num(g_pScoreDifference)) {
    new iBestPlayer, iWorstPlayer, iCTNum, iTTNum;
    GetActualPlayers(iBestPlayer, iWorstPlayer, iCTNum, iTTNum);
    
    new iMinPlayers = get_pcvar_num(g_pMinPlayers);
    if(iMinPlayers < 6 || iMinPlayers > 32) {
      iMinPlayers = 6;
    }

    if(iCTNum + iTTNum >= iMinPlayers) {
      iNextCheck = get_pcvar_num(g_pScoreDifference) / 2 + 1;

      TransferPlayer(iBestPlayer);
      TransferPlayer(iWorstPlayer);

      /*server_print("Best Player %n", iBestPlayer);
      server_print("Worst Player %n", iWorstPlayer);*/
    }
  }
}

// CUSTOM FUNTIONS
CheckTeamsScore(&iDifference) {
  if(g_eTeamScore[TeamCT] > g_eTeamScore[TeamTT]) {
    iDifference = g_eTeamScore[TeamCT] - g_eTeamScore[TeamTT];
  }
  
  if(g_eTeamScore[TeamTT] > g_eTeamScore[TeamCT]) {
    iDifference = g_eTeamScore[TeamTT] - g_eTeamScore[TeamCT];
  }
}

GetActualPlayers(&iBestPlayer, &iWorstPlayer, &iCTNum, &iTTNum) {
  new Float:iCTPlayersSkill[MAXPLAYERS + 1][pSkillKey];
  new Float:iTTPlayersSkill[MAXPLAYERS + 1][pSkillKey];
  new iKills, iDeaths, iHs;

  for(new id = 1; id <= g_iMaxPlayers; id++) {
    if(!is_user_connected(id)) continue;

    switch(cs_get_user_team(id)) {
      case CS_TEAM_CT: {
        iCTNum++

        iHs = g_iPlayerHs[id];
        iKills = g_iPlayerKills[id];
        iDeaths = g_iPlayerDeaths[id];

        iCTPlayersSkill[id][pId] = Float:id;
        iCTPlayersSkill[id][pSkill] = get_skill(iKills, iDeaths, iHs);
      }
      case CS_TEAM_T: {
        iTTNum++

        iHs = g_iPlayerHs[id];
        iKills = g_iPlayerKills[id];
        iDeaths = g_iPlayerDeaths[id];

        iTTPlayersSkill[id][pId] = Float:id;
        iTTPlayersSkill[id][pSkill] = get_skill(iKills, iDeaths, iHs);
      }
      default: continue;
    }
  }

  new iMinPlayers = get_pcvar_num(g_pMinPlayers);
  if(iMinPlayers < 6 || iMinPlayers > 32) iMinPlayers = 6;
  if(iCTNum + iTTNum < iMinPlayers) return;

  SortCustom2D(_:iCTPlayersSkill, sizeof(iCTPlayersSkill) , "SortDesc");
  SortCustom2D(_:iTTPlayersSkill, sizeof(iTTPlayersSkill) , "SortDesc");

  if(g_eTeamScore[TeamCT] > g_eTeamScore[TeamTT]) { // если КТ побеждает
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

TransferPlayer(const id) {
  new CsTeams:iTeam;
    
  if(is_user_connected(id)) {
    iTeam = cs_get_user_team(id);

    if(CS_TEAM_T <= iTeam <= CS_TEAM_CT) {
      set_player_team(id, iTeam == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T);
      
      if(is_user_bot(id)) return;

      set_dhudmessage(255, 200, 0, -1.0, -0.29, 2, _, 5.0, 0.07);

      if(iTeam == CS_TEAM_T) {
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

set_player_team(const id, CsTeams:iTeam) {
  switch(iTeam) {
    case CS_TEAM_T: {
      if(cs_get_user_defuse(id)) {
        cs_set_user_defuse(id, 0);
      }
    }
    case CS_TEAM_CT: {
      if(user_has_weapon(id, CSW_C4)) {
        engclient_cmd(id, "drop", "weapon_c4");
      }
    }
  }
  cs_set_user_team(id, iTeam);
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

  message_begin(MSG_ONE_UNRELIABLE, g_iMsgId_ScreenFade, _, id);
  write_short(dUnits); //Durration
  write_short(dUnits/2); //Hold
  write_short(0x0000); // Type
  write_byte(red);
  write_byte(green);
  write_byte(blue);
  write_byte(alfa);
  message_end();
} 