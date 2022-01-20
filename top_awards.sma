#include <amxmodx>
#include <reapi>

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define AUTO_CFG // автоматическое создание конфига с кварами
// #define CSSTATS_MYSQL // раскомментируйте если на сервере установлена статистика CsStats MySQL от SKAJIbnEJIb
// #define CSSTATSX_SQL // раскомментируйте если на сервере установлена статистика CSstatsX SQL от serfreeman1337
// #define CMSSTATS_MYSQL // раскомментируйте если на сервере установлена статистика CMSStats MySQL от zhorzh78
/*
	Если закомментировать все сразу #define CSSTATS_MYSQL и #define CSSTATSX_SQL и #define CMSSTATS_MYSQL
	то плагин будет работать со стандартной статистикой CSX (cstrike/addons/amxmodx/data/csstats.dat)
*/
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

#if defined CSSTATS_MYSQL
	native csstats_get_user_stats(id, stats[22]);
#elseif defined CSSTATSX_SQL
	native get_user_stats_sql(index, stats[8], bodyhits[8]);
#elseif defined CMSSTATS_MYSQL
	native cmsstats_get_user_stats(id, stats[8], bodyhits[8]);
#else
	#include <csstats>
#endif

enum any:CVARS {
	COUNT,
	FLAGS[32],
	FLAGS_BIT,
	ALERT[192],
	ALERT_COLOR[12],
	ALERT_COLOR_R,
	ALERT_COLOR_G,
	ALERT_COLOR_B,
	ALERT_COORDS[32],
	Float:ALERT_COORDS_X,
	Float:ALERT_COORDS_Y,
	ALERT_SOUND[64]
};

enum bool:PLAYER_DATA {
	IS_TOP,
	IS_ALERT_SHOWED
};

new cvar[CVARS], player[MAX_CLIENTS + 1][PLAYER_DATA];

public plugin_init() {
	register_plugin("Top Awards", "1.2.0", "szawesome");

	if(strlen(cvar[ALERT])) {
		RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true);
	}
}

public plugin_precache() {
	RegisterCvars();
	ValueCvars();

	if(strlen(cvar[ALERT_SOUND])) {
		precache_sound(cvar[ALERT_SOUND]);
	}
}

public client_putinserver(id) {
	player[id][IS_TOP] = false;
	player[id][IS_ALERT_SHOWED] = false;

	set_task(0.5, "CheckStats", id);
}

public CheckStats(id) {
	new pFlags = get_user_flags(id);

	if(pFlags & cvar[FLAGS_BIT] || pFlags & cvar[FLAGS_BIT] == cvar[FLAGS_BIT]) {
		return HC_CONTINUE;
	}

	if(cvar[COUNT] <= 0) {
		return HC_CONTINUE;
	}

	#if defined CSSTATS_MYSQL
		new pStats[22];
	#else
		new pStats[8], pBodyHits[8];
	#endif

	#if defined CSSTATS_MYSQL
		new pRank = csstats_get_user_stats(id, pStats);
	#elseif defined CSSTATSX_SQL
		new pRank = get_user_stats_sql(id, pStats, pBodyHits);
	#elseif defined CMSSTATS_MYSQL
		new pRank = cmsstats_get_user_stats(id, pStats, pBodyHits);
	#else
		new pRank = get_user_stats(id, pStats, pBodyHits);
	#endif

	if(pRank && 0 < pRank <= cvar[COUNT]) {
		set_user_flags(id, pFlags | cvar[FLAGS_BIT]);
		player[id][IS_TOP] = true;
	}

	return HC_CONTINUE;
}

public CBasePlayer_OnSpawnEquip_Post(id, bool:addDefault, bool:equipGame) {
	if(is_user_alive(id) && !is_user_bot(id) && player[id][IS_TOP] && !player[id][IS_ALERT_SHOWED]) {
		screen_fade(id, cvar[ALERT_COLOR_R], cvar[ALERT_COLOR_G], cvar[ALERT_COLOR_B], 100, 1);
		set_dhudmessage(cvar[ALERT_COLOR_R], cvar[ALERT_COLOR_G], cvar[ALERT_COLOR_B], cvar[ALERT_COORDS_X], cvar[ALERT_COORDS_Y], 2, _, 5.0, 0.07);
		show_dhudmessage(id, cvar[ALERT]);
		if(strlen(cvar[ALERT_SOUND])) {
			rg_send_audio(id, cvar[ALERT_SOUND]);
		}

		player[id][IS_ALERT_SHOWED] = true;
	}
}

RegisterCvars() {
	bind_pcvar_num(
		create_cvar(
			.name = "top_awards_count", 
			.string = "3",
			.flags = FCVAR_NONE,
			.description = "Выдавать флаги TOP-N игрокам",
			.has_min = true,
			.min_val = 1.0
		),
		cvar[COUNT]
	);
	bind_pcvar_string(
		create_cvar(
			.name = "top_awards_flags", 
			.string = "t",
			.flags = FCVAR_NONE,
			.description = "Выдаваемые флаги. Можно сочитать, например: bt"
		),
		cvar[FLAGS],
		charsmax(cvar[FLAGS])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "top_awards_alert",
			.string = "Бесплатная VIP активирована\nТы в ТОП-\d лучших игроков сервера",
			.flags = FCVAR_NONE,
			.description = "Выводить сообщение о активации привилегии?^nОставьте пустым чтобы не выводить^n\n - перенос строки^n\d - число из квара top_awards_count"
		),
		cvar[ALERT],
		charsmax(cvar[ALERT])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "top_awards_alert_color",
			.string = "255 255 0",
			.flags = FCVAR_NONE,
			.description = "Цвет сообщения и затемнения экрана. Формат: R G B"
		),
		cvar[ALERT_COLOR],
		charsmax(cvar[ALERT_COLOR])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "top_awards_alert_coords",
			.string = "-1.0 -0.29",
			.flags = FCVAR_NONE,
			.description = "Координаты сообщения. Формат: X Y^nУказывается % смещения разделённый на 100^n-1.0 - по центру"
		),
		cvar[ALERT_COORDS],
		charsmax(cvar[ALERT_COORDS])
	);
	bind_pcvar_string(
		create_cvar(
			.name = "top_awards_alert_sound",
			.string = "fvox/bell.wav",
			.flags = FCVAR_NONE,
			.description = "Воспроизводить звук при активации привилегии?^nОставьте пустым чтобы не воспроизводить^nЗвук должен лежать в папке sound"
		),
		cvar[ALERT_SOUND],
		charsmax(cvar[ALERT_SOUND])
	);
	#if defined AUTO_CFG
		AutoExecConfig();
	#endif
}

ValueCvars() {
	// FLAGS BITS
	cvar[FLAGS_BIT] = read_flags(cvar[FLAGS]);
	// FORMAT ALERT MESSAGE
	if(strlen(cvar[ALERT])) {
		new cvCount[16]; num_to_str(cvar[COUNT], cvCount, sizeof cvCount);
		replace_all(cvar[ALERT], charsmax(cvar[ALERT]), "\n", "^n");
		replace_all(cvar[ALERT], charsmax(cvar[ALERT]), "\d", cvCount);
	}
	// PARSE COLORS
	new red[4], green[4], blue[4];
	parse(cvar[ALERT_COLOR], red, charsmax(red), green, charsmax(green), blue, charsmax(blue));
	cvar[ALERT_COLOR_R] = str_to_num(red);
	cvar[ALERT_COLOR_G] = str_to_num(green);
	cvar[ALERT_COLOR_B] = str_to_num(blue);
	// PARSE COORDS
	new coord_x[16], coord_y[16];
	parse(cvar[ALERT_COORDS], coord_x, charsmax(coord_x), coord_y, charsmax(coord_y));
	cvar[ALERT_COORDS_X] = str_to_float(coord_x);
	cvar[ALERT_COORDS_Y] = str_to_float(coord_y);
}

stock screen_fade(id, red, green, blue, alfa, durration) {
	if(!is_user_connected(id) || is_user_bot(id)) {
		return;
	}

	if(bool:(Float:get_member(id, m_blindStartTime) + Float:get_member(id, m_blindFadeTime) >= get_gametime())) {
		return;
	}

	new dUnits = clamp((durration * (1 << 12)), 0, 0xFFFF);

	static userMessage_ScreenFade;
	if(userMessage_ScreenFade > 0 || (userMessage_ScreenFade = get_user_msgid("ScreenFade"))) {
		message_begin(MSG_ONE_UNRELIABLE, userMessage_ScreenFade, .player = id);
		write_short(dUnits);
		write_short(dUnits/2);
		write_short(0x0000);
		write_byte(red);
		write_byte(green);
		write_byte(blue);
		write_byte(alfa);
		message_end();
	}
}