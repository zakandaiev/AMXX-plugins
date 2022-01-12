#include <amxmodx>
#include <reapi>

#define AUTO_CFG // автоматическое создание конфига с кварами

enum CVARS {
  HE_COLOR,
  FB_COLOR
};

new cvar[CVARS];

public plugin_init() {
  register_plugin("[ReAPI] Grenades Dynamic Light", "1.1", "szawesome");

  RegisterCvars();

  new alert_he[128];
  get_pcvar_string(cvar[HE_COLOR], alert_he, sizeof alert_he);
  if(strlen(alert_he)) {
    RegisterHookChain(RG_CGrenade_ExplodeHeGrenade, "CGrenade_ExplodeHE_Post", true);
  }

  new alert_fb[128];
  get_pcvar_string(cvar[FB_COLOR], alert_fb, sizeof alert_fb);
  if(strlen(alert_fb)) {
    RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "CGrenade_ExplodeFB_Post", true);
  }
}

RegisterCvars() {
  cvar[HE_COLOR] = create_cvar(
    .name = "gdl_he", 
    .string = "255 220 0",
    .flags = FCVAR_NONE,
    .description = "Цвет дин. освещения при взырве HE. Формат: R G B^nОставьте пустым чтобы отключить еффект"
  );
  cvar[FB_COLOR] = create_cvar(
    .name = "gdl_fb", 
    .string = "255 255 255",
    .flags = FCVAR_NONE,
    .description = "Цвет дин. освещения при взырве FB. Формат: R G B^nОставьте пустым чтобы отключить еффект"
  );
  #if defined AUTO_CFG
  AutoExecConfig();
  #endif
}

public CGrenade_ExplodeHE_Post(ent) {
  new he_color[11]; get_pcvar_string(cvar[HE_COLOR], he_color, sizeof he_color);
  new red[5], green[5], blue[5]; parse(he_color, red, 4, green, 4, blue, 4);

  new Float:origin[3];
  get_entvar(ent, var_origin, origin);
  
  make_dyn_light(origin, str_to_num(red), str_to_num(green), str_to_num(blue));
}

public CGrenade_ExplodeFB_Post(ent) {
  new fb_color[11]; get_pcvar_string(cvar[FB_COLOR], fb_color, sizeof fb_color);
  new red[5], green[5], blue[5]; parse(fb_color, red, 4, green, 4, blue, 4);

  new Float:origin[3];
  get_entvar(ent, var_origin, origin);

  make_dyn_light(origin, str_to_num(red), str_to_num(green), str_to_num(blue));
}

stock make_dyn_light(Float:origin[3], red, green, blue) {
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_DLIGHT);
  write_coord(floatround(origin[0]));
  write_coord(floatround(origin[1]));
  write_coord(floatround(origin[2]));
  write_byte(50);
  write_byte(red);
  write_byte(green);
  write_byte(blue);
  write_byte(8);
  write_byte(60);
  message_end();
}