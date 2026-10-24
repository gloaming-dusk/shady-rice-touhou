/*
 * point-items: a closing window breaks into tiles that turn into score
 * items, blue point items and a few red power items, and are collected
 * upward off the screen.
 *
 * The plugin gives every window its own shader (point_items.vert/.frag),
 * which draws the window as Shady's does at rest and the items while the
 * window closes. The shaders are found next to this library's source tree:
 * $SHADY_TOUHOU_DIR/plugins/shaders, or ../plugins/shaders from the
 * directory the library was loaded from (build/ in this repository).
 *
 * Requires the spatial module (GL renderer).
 */
#define _GNU_SOURCE

#include <dlfcn.h>
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <shady/event.h>
#include <shady/plugin.h>

static const struct shady_plugin_api_v1 *api;
static shady_host host;
static shady_shader_program program;

static const struct shady_close_effect effect = {
	.style = SHADY_CLOSE_EFFECT_SLIDE_FADE,
	.duration = 1.25f,
	.strength = 1.0f,
	.direction_x = 0.0f,
	.direction_y = 0.0f,
};

static void apply_window(shady_window window) {
	if (!program || !window || !api->window_valid(host, window) ||
			!api->window_mapped(window))
		return;
	api->window_set_shader(host, window, program);
	api->window_set_close_effect(host, window, &effect);
}

static void on_event(shady_host event_host, const struct shady_event *event,
		void *user_data) {
	(void)event_host;
	(void)user_data;
	if (event->type == SHADY_EVENT_WINDOW_MAPPED ||
			event->type == SHADY_EVENT_WINDOW_STATE_CHANGED)
		apply_window(event->object.window);
}

/* The repository root: $SHADY_TOUHOU_DIR, or the parent of the directory
 * this library is in. */
static bool find_root(char *out, size_t size) {
	const char *env = getenv("SHADY_TOUHOU_DIR");
	if (env && *env) {
		snprintf(out, size, "%s", env);
		return true;
	}
	Dl_info info;
	if (!dladdr((void *)find_root, &info) || !info.dli_fname)
		return false;
	char path[PATH_MAX];
	if (!realpath(info.dli_fname, path))
		return false;
	char *slash = strrchr(path, '/');
	if (!slash) return false;
	*slash = '\0';
	snprintf(out, size, "%s/..", path);
	return true;
}

static bool init(struct shady_server *server) {
	(void)server;
	char root[PATH_MAX];
	if (!find_root(root, sizeof(root))) {
		api->log(SHADY_PLUGIN_LOG_ERROR, "point-items: cannot find its shaders");
		return false;
	}
	char vert[PATH_MAX + 64], frag[PATH_MAX + 64];
	snprintf(vert, sizeof(vert), "%s/plugins/shaders/point_items.vert", root);
	snprintf(frag, sizeof(frag), "%s/plugins/shaders/point_items.frag", root);
	program = api->shader_program_create(host, vert, frag);
	if (!program) {
		api->log(SHADY_PLUGIN_LOG_ERROR, "point-items: failed to load its shader");
		return false;
	}
	return true;
}

static void start(struct shady_server *server) {
	(void)server;
	for (size_t i = 0; i < api->window_count(host); i++)
		apply_window(api->window_at(host, i));
	api->schedule_render(host);
	api->log(SHADY_PLUGIN_LOG_INFO, "point-items: closing windows become items");
}

static void stop(struct shady_server *server) {
	(void)server;
	for (size_t i = 0; i < api->window_count(host); i++) {
		shady_window window = api->window_at(host, i);
		if (!api->window_valid(host, window)) continue;
		if (api->window_shader(window) == program)
			api->window_reset_shader(host, window);
		api->window_reset_close_effect(host, window);
	}
}

static void destroy(struct shady_server *server) {
	(void)server;
	if (program)
		api->shader_program_destroy(host, program);
	program = 0;
}

static const char *const provides[] = {
	"touhou.point-items",
	NULL,
};

static const char *const requires[] = {
	"spatial.window-state",
	NULL,
};

static const struct shady_module module = {
	.name = "point-items",
	.provides = provides,
	.requires = requires,
	.init = init,
	.start = start,
	.stop = stop,
	.destroy = destroy,
};

const struct shady_module *shady_plugin_entry_v1(uint32_t host_abi,
		const struct shady_plugin_api_v1 *host_api, shady_host host_handle) {
	if (host_abi != SHADY_PLUGIN_ABI_V1 || !host_api ||
			host_api->abi_version != SHADY_PLUGIN_ABI_V1 ||
			host_api->struct_size < sizeof(*host_api) ||
			!host_api->shader_program_create ||
			!host_api->shader_program_destroy ||
			!host_api->window_set_shader ||
			!host_api->window_reset_shader ||
			!host_api->window_shader ||
			!host_api->window_set_close_effect ||
			!host_api->window_reset_close_effect)
		return NULL;

	api = host_api;
	host = host_handle;
	api->subscribe_event(host, SHADY_EVENT_WINDOW_MAPPED, on_event, NULL);
	api->subscribe_event(host, SHADY_EVENT_WINDOW_STATE_CHANGED, on_event, NULL);
	return &module;
}
