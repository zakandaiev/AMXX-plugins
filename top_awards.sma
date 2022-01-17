#include <amxmodx>
#include <reapi>

/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */
#define AUTO_CFG // автоматическое создание конфига с кварами
// #define CSSTATS_MYSQL // на сервере установлена статистика CsStats MySQL от SKAJIbnEJIb
// #define CSSTATSX_SQL // на сервере установлена статистика CSstatsX SQL от serfreeman1337
/*
	Если закомментировать #define CSSTATS_MYSQL и #define CSSTATSX_SQL
	то плагин будет работать со стандартной статистикой CSX (cstrike/addons/amxmodx/data/csstats.dat)
*/
/* ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ */

#if defined CSSTATS_MYSQL
	native csstats_get_user_stats(id, stats[22]);
#elseif defined CSSTATSX_SQL
	native get_user_stats_sql(index, stats[8], bodyhits[8]);
#else
	#include <csstats>
#endif

enum any:CVARS {
	COUNT,
	FLAGS[32],
	ALERT[192],
	ALERT_COLOR[11],
	ALERT_SOUND[64]
};

new cvar[CVARS];

new bool:isTopPlayer[MAX_CLIENTS + 1], bool:isAlertShowed[MAX_CLIENTS + 1];

public plugin_init() {
	register_plugin("Top Awards", "1.1.0", "szawesome");

	RegisterCvars();

	if(strlen(cvar[ALERT])) {
		new cvCount[1]; num_to_str(cvar[COUNT], cvCount, sizeof cvCount);
		replace_all(cvar[ALERT], charsmax(cvar[ALERT]), "\n", "^n");
		replace_all(cvar[ALERT], charsmax(cvar[ALERT]), "\d", cvCount);
		RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true);
	}
}

public plugin_precache() {
	if(strlen(cvar[ALERT_SOUND])) {
		precache_sound(cvar[ALERT_SOUND]);
	}
}

public client_putinserver(id) {
	isTopPlayer[id] = false;
	isAlertShowed[id] = false;

	set_task(0.5, "CheckStats", id);
}

public CheckStats(id) {
	new pFlags = get_user_flags(id);
	new addFlags = read_flags(cvar[FLAGS]);

	if(pFlags & addFlags || pFlags & addFlags == addFlags) {
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
	#else
		new pRank = get_user_stats(id, pStats, pBodyHits);
	#endif

	if(pRank && pRank > 0 && pRank <= cvar[COUNT]) {
		set_user_flags(id, pFlags | addFlags);
		isTopPlayer[id] = true;
	}

	return HC_CONTINUE;
}

public CBasePlayer_OnSpawnEquip_Post(player, bool:addDefault, bool:equipGame) {
	if(is_user_alive(player) && isTopPlayer[player] && !isAlertShowed[player]) {
		new red[5], green[5], blue[5], cRed, cGreen, cBlue;

		parse(cvar[ALERT_COLOR], red, 4, green, 4, blue, 4);
		cRed = str_to_num(red);
		cGreen = str_to_num(green);
		cBlue = str_to_num(blue);

		screen_fade(player, cRed, cGreen, cBlue, 100, 1);
		set_dhudmessage(cRed, cGreen, cBlue, -1.0, -0.29, 2, _, 5.0, 0.07);
		show_dhudmessage(player, cvar[ALERT]);
		if(strlen(cvar[ALERT_SOUND])) {
			rg_send_audio(player, cvar[ALERT_SOUND]);
		}

		isAlertShowed[player] = true;
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

stock screen_fade(player, red, green, blue, alfa, durration) {
	if(bool:(Float:get_member(player, m_blindStartTime) + Float:get_member(player, m_blindFadeTime) >= get_gametime())) {
		return;
	}

	new dUnits = clamp((durration * (1 << 12)), 0, 0xFFFF);

	static userMessage_ScreenFade;
	if(userMessage_ScreenFade > 0 || (userMessage_ScreenFade = get_user_msgid("ScreenFade"))) {
		message_begin(MSG_ONE_UNRELIABLE, userMessage_ScreenFade, .player = player);
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