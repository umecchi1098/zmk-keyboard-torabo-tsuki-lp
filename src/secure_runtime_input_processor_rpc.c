/*
 * Copyright (c) 2026
 *
 * SPDX-License-Identifier: MIT
 */

#include <errno.h>
#include <string.h>

#include <zephyr/init.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(torabo_secure_runtime_input_processor_rpc,
                    CONFIG_ZMK_LOG_LEVEL);

/* 固定した上流モジュールがCustom Studio Protocolへ登録する識別子です。 */
#define RUNTIME_INPUT_PROCESSOR_SUBSYSTEM_ID "cormoran_rip"
#define CUSTOM_SETTINGS_SUBSYSTEM_ID "cormoran_custom_settings"

/*
 * 固定したZMK Custom Studio Protocolの登録情報と同じメモリー配置です。
 * 上流の構造や識別子が変わった場合は、リンクまたは識別子検査で失敗させます。
 */
enum torabo_rpc_security {
  TORABO_RPC_SECURED = 0,
  TORABO_RPC_UNSECURED = 1,
};

struct torabo_rpc_custom_subsystem_meta {
  char **ui_urls;
  size_t ui_urls_count;
  enum torabo_rpc_security security;
};

struct torabo_rpc_custom_subsystem {
  char *identifier;
  struct torabo_rpc_custom_subsystem_meta *meta;
  void *handler;
};

/* 固定したRuntime Input ProcessorとCustom Settingsが公開する登録情報です。 */
extern struct torabo_rpc_custom_subsystem
    zmk_rpc_custom_subsystem_cormoran_rip;
extern struct torabo_rpc_custom_subsystem
    zmk_rpc_custom_subsystem_cormoran_custom_settings;

/**
 * 指定した画面を、Studio Unlock後だけ呼び出せる状態へ変更します。
 *
 * 最初にSecureへ変更することで、識別子検査が失敗した場合も無保護になりません。
 */
static int secure_subsystem(struct torabo_rpc_custom_subsystem *subsystem,
                            const char *expected_identifier) {
  subsystem->meta->security = TORABO_RPC_SECURED;

  if (strcmp(subsystem->identifier, expected_identifier) != 0) {
    LOG_ERR("Unexpected RPC subsystem: %s", subsystem->identifier);
    return -EINVAL;
  }

  return 0;
}

/**
 * Runtime Input Processor専用RPCと、その保存領域を公開する汎用RPCを保護します。
 */
static int secure_runtime_input_processor_rpc_init(void) {
  int ret = secure_subsystem(&zmk_rpc_custom_subsystem_cormoran_rip,
                             RUNTIME_INPUT_PROCESSOR_SUBSYSTEM_ID);
  if (ret < 0) {
    return ret;
  }

  ret = secure_subsystem(&zmk_rpc_custom_subsystem_cormoran_custom_settings,
                         CUSTOM_SETTINGS_SUBSYSTEM_ID);
  if (ret < 0) {
    return ret;
  }

  LOG_INF("Runtime Input Processor RPC requires Studio Unlock");
  return 0;
}

SYS_INIT(secure_runtime_input_processor_rpc_init, APPLICATION,
         CONFIG_APPLICATION_INIT_PRIORITY);
