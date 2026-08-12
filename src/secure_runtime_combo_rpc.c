/*
 * Copyright (c) 2026
 *
 * SPDX-License-Identifier: MIT
 */

#include <errno.h>
#include <string.h>

#include <zephyr/init.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(torabo_secure_runtime_combo_rpc, CONFIG_ZMK_LOG_LEVEL);

/* 上流Runtime ComboがCustom Studio Protocolへ登録する固定識別子です。 */
#define RUNTIME_COMBO_SUBSYSTEM_ID "cormoran__runtime_combo"

/*
 * 固定したZMK Custom Studio Protocolの登録情報と同じメモリー配置です。
 * protobufを生成する前でもコンパイルできるよう、ここでは必要な項目だけを宣言します。
 * 上流の識別子や構造が変わるとリンクまたは識別子検査で失敗し、無保護で進みません。
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

/* 固定したRuntime Comboモジュールが公開する登録情報です。 */
extern struct torabo_rpc_custom_subsystem
    zmk_rpc_custom_subsystem_cormoran__runtime_combo;

/**
 * Runtime Combo画面を、Studio Unlock後だけ呼び出せる状態へ変更します。
 *
 * 固定した上流版では設定値の書き込み権限はSecureですが、Runtime Combo独自RPCは
 * Unsecuredとして登録されています。このままでは独自RPCからLockを迂回できるため、
 * ZMKがRPC受付を開始する前にsubsystem全体をSecureへ変更します。
 */
static int secure_runtime_combo_rpc_init(void) {
  struct torabo_rpc_custom_subsystem *subsystem =
      &zmk_rpc_custom_subsystem_cormoran__runtime_combo;

  /*
   * 識別子検査が失敗した場合も無保護にならないよう、
   * 最初にSecureへ変更します。
   */
  subsystem->meta->security = TORABO_RPC_SECURED;

  if (strcmp(subsystem->identifier, RUNTIME_COMBO_SUBSYSTEM_ID) != 0) {
    LOG_ERR("Unexpected Runtime Combo RPC subsystem: %s",
            subsystem->identifier);
    return -EINVAL;
  }

  LOG_INF("Runtime Combo RPC requires Studio Unlock");
  return 0;
}

SYS_INIT(secure_runtime_combo_rpc_init, APPLICATION,
         CONFIG_APPLICATION_INIT_PRIORITY);
