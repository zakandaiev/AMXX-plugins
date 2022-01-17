#include <amxmodx>
#include <csstats>
#include <reapi>

#define AUTO_CFG // автоматическое создание конфига с кварами

enum CVARS {
  RANKS,
  FLAGS,
  ALERT,
  ALERT_COLOR
};

new cvar[CVARS];

new bool:isTopPlayer[MAX_CLIENTS + 1], bool:isAlertShowed[MAX_CLIENTS + 1];

public plugin_init() {
  register_plugin("Top Awards", "1.0", "szawesome");

  RegisterCvars();

  new alert[128];
  get_pcvar_string(cvar[ALERT], alert, sizeof alert);
  if(strlen(alert)) {
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true);
  }
}

public client_putinserver(id) {
  isTopPlayer[id] = false;
  isAlertShowed[id] = false;

  set_task(0.5, "CheckStats", id);
}

public CheckStats(id) {
  new pFlags = get_user_flags(id);
  new cFlags[32]; get_pcvar_string(cvar[FLAGS], cFlags, sizeof cFlags);
  new addFlags = read_flags(cFlags);

  if(pFlags & addFlags || pFlags & addFlags == addFlags) {
    isAlertShowed[id] = true;
    return HC_CONTINUE;
  }

  new ranks = get_pcvar_num(cvar[RANKS]);

  if(!ranks) {
    return HC_CONTINUE;
  }

  new pStats[8], pBodyHits[8];
  new pRank = get_user_stats(id, pStats, pBodyHits);

  if(pRank && pRank <= ranks) {
    set_user_flags(id, pFlags | addFlags);
    isTopPlayer[id] = true;
  }

  return HC_CONTINUE;
}

public CBasePlayer_OnSpawnEquip_Post(player, bool:addDefault, bool:equipGame) {
  if(is_user_alive(player) && isTopPlayer[player] && !isAlertShowed[player]) {
    new alert[128]; get_pcvar_string(cvar[ALERT], alert, sizeof alert);
    new ranks[6]; get_pcvar_string(cvar[RANKS], ranks, sizeof ranks);

    replace_all(alert, charsmax(alert), "\n", "^n");
    replace_all(alert, charsmax(alert), "\d", ranks);
    
    new alert_color[11]; get_pcvar_string(cvar[ALERT_COLOR], alert_color, sizeof alert_color);
    new red[5], green[5], blue[5]; parse(alert_color, red, 4, green, 4, blue, 4);

    screen_fade(player, str_to_num(red), str_to_num(green), str_to_num(blue), 100, 1);
    set_dhudmessage(str_to_num(red), str_to_num(green), str_to_num(blue), -1.0, -0.29, 2, _, 5.0, 0.07);
    show_dhudmessage(player, alert);
    client_cmd(player, "spk fvox/bell");

    isAlertShowed[player] = true;
  }
}

RegisterCvars() {
  cvar[RANKS] = create_cvar(
    .name = "top_awards_count", 
    .string = "3",
    .flags = FCVAR_NONE,
    .description = "Выдавать флаги игрокам с 1 по N место в топе",
    .has_min = true,
    .min_val = 1.0
  );
  cvar[FLAGS] = create_cvar(
    .name = "top_awards_flags", 
    .string = "t",
    .flags = FCVAR_NONE,
    .description = "Выдаваемые флаги. Можно сочитать, например: bt"
  );
  cvar[ALERT] = create_cvar(
    .name = "top_awards_alert",
    .string = "Бесплатная VIP активирована\nТы в ТОП-\d лучших игроков сервера",
    .flags = FCVAR_NONE,
    .description = "Выводить сообщение о активации привилегии?^nОставьте пустым чтобы не выводить"
  );
  cvar[ALERT_COLOR] = create_cvar(
    .name = "top_awards_alert_color",
    .string = "255 255 0",
    .flags = FCVAR_NONE,
    .description = "Цвет сообщения и затемнения экрана. Формат: R G B"
  );
  #if defined AUTO_CFG
  AutoExecConfig();
  #endif
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