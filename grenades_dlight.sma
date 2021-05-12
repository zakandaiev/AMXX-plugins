#include <amxmodx>
#include <reapi>

#define HE_COLOR "255 220 0"
#define FB_COLOR "255 255 255"

public plugin_init() {
  register_plugin("[ReAPI] Grenades Dynamic Light", "1.0", "szawesome");
  RegisterHookChain(RG_CGrenade_ExplodeHeGrenade, "CGrenade_ExplodeHE_Post", true);
  RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "CGrenade_ExplodeFlashbang_Post", true);
}

public CGrenade_ExplodeHE_Post(const ent) {
  new red[5], green[5], blue[5];
  parse(HE_COLOR,red,4,green,4,blue,4);

  new Float:origin[3];
  get_entvar(ent, var_origin, origin);
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_DLIGHT);
  write_coord(floatround(origin[0]));
  write_coord(floatround(origin[1]));
  write_coord(floatround(origin[2]));
  write_byte(50);
  write_byte(str_to_num(red));
  write_byte(str_to_num(green));
  write_byte(str_to_num(blue));
  write_byte(8);
  write_byte(60);
  message_end();
}

public CGrenade_ExplodeFlashbang_Post(const ent) {
  new red[5], green[5], blue[5];
  parse(FB_COLOR,red,4,green,4,blue,4);

  new Float:origin[3];
  get_entvar(ent, var_origin, origin);
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_DLIGHT);
  write_coord(floatround(origin[0]));
  write_coord(floatround(origin[1]));
  write_coord(floatround(origin[2]));
  write_byte(50);
  write_byte(str_to_num(red));
  write_byte(str_to_num(green));
  write_byte(str_to_num(blue));
  write_byte(8);
  write_byte(60);
  message_end();
}