#include <amxmodx>
#include <reapi>

#define AUTO_CFG // автоматическое создание конфига с кварами

enum CVARS {
  START,
  END,
  FLAGS,
  ALERT,
  ALERT_COLOR,
  GAMENAME
};

new cvar[CVARS];

new bool:isAlertShowed[MAX_CLIENTS + 1];

public plugin_init() {
  register_plugin("Night VIPs", "1.0", "szawesome");

  RegisterCvars();

  if (!is_night_time()) {
    pause("ad");
  }

  new alert[128];
  get_pcvar_string(cvar[ALERT], alert, sizeof alert);
  if(strlen(alert)) {
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true);
  }

  new gamename[64];
  get_pcvar_string(cvar[GAMENAME], gamename, sizeof gamename);
  if(strlen(gamename)) {
    set_member_game(m_GameDesc, gamename);
  }
}

public client_putinserver(id) {
  isAlertShowed[id] = false;

  new pFlags = get_user_flags(id);
  new cFlags[32]; get_pcvar_string(cvar[FLAGS], cFlags, sizeof cFlags);
  new addFlags = read_flags(cFlags);

  if (pFlags & addFlags || pFlags & addFlags == addFlags) {
    isAlertShowed[id] = true;
    return HC_CONTINUE;
  }

  set_user_flags(id, pFlags | addFlags);

  return HC_CONTINUE;
}

public CBasePlayer_OnSpawnEquip_Post(player, bool:addDefault, bool:equipGame) {
  if(is_user_alive(player) && !isAlertShowed[player]) {
    new alert[128]; get_pcvar_string(cvar[ALERT], alert, sizeof alert); replace_all(alert, charsmax(alert), "\n", "^n");
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
  cvar[START] = create_cvar(
    .name = "night_vips_start",
    .string = "22",
    .flags = FCVAR_NONE,
    .description = "Время, начиная с которого будут выдаваться флаги",
    .has_min = true,
    .min_val = 0.0,
    .has_max = true,
    .max_val = 24.0
  );
  cvar[END] = create_cvar(
    .name = "night_vips_end",
    .string = "6",
    .flags = FCVAR_NONE,
    .description = "Время, когда флаги прекратят выдаваться",
    .has_min = true,
    .min_val = 0.0,
    .has_max = true,
    .max_val = 24.0
  );
  cvar[FLAGS] = create_cvar(
    .name = "night_vips_flags",
    .string = "t",
    .flags = FCVAR_NONE,
    .description = "Выдаваемые флаги. Можно сочитать, например: bt"
  );
  cvar[ALERT] = create_cvar(
    .name = "night_vips_alert",
    .string = "Ночная VIP активирована\nЖелаем приятной игры",
    .flags = FCVAR_NONE,
    .description = "Выводить сообщение о активации ночной привилегии?^nОставьте пустым чтобы не выводить"
  );
  cvar[ALERT_COLOR] = create_cvar(
    .name = "night_vips_alert_color",
    .string = "255 255 0",
    .flags = FCVAR_NONE,
    .description = "Цвет сообщения и затемнения экрана. Формат: R G B"
  );
  cvar[GAMENAME] = create_cvar(
    .name = "night_vips_gamename",
    .string = "",
    .flags = FCVAR_NONE,
    .description = "Менять описание игры в списке серверов в заданноe время?^nОставьте пустым чтобы не менять"
  );
  #if defined AUTO_CFG
  AutoExecConfig();
  #endif
}

bool:is_night_time() {
  new hour; time(hour);
  new hour_start = get_pcvar_num(cvar[START]);
  new hour_end = get_pcvar_num(cvar[END]);

  if ((hour_start <= hour < hour_end || hour_start > hour_end && !(hour_start > hour >= hour_end))) {
    return true;
  }

  return false;
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