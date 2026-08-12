if(CONFIG_SHIELD_TORABO_TSUKI_LP_LEFT OR CONFIG_SHIELD_TORABO_TSUKI_LP_RIGHT)
  zephyr_library()
  zephyr_include_directories(${APPLICATION_SOURCE_DIR}/include)
  zephyr_library_sources(src/mini_trackpad_init_reg.c)

  # 上流Runtime Comboの独自RPCを、このキーボードではUnlock必須にします。
  zephyr_library_sources_ifdef(CONFIG_TORABO_TSUKI_LP_SECURE_RUNTIME_COMBO_RPC
                               src/secure_runtime_combo_rpc.c)

  # Zephyr 4.1では左右間BLEが切断される可能性があるため、
  # 独自の省電力処理は明示的に有効化した場合だけ組み込みます。
  zephyr_library_sources_ifdef(CONFIG_TORABO_TSUKI_LP_SPLIT_POWER_MGMT src/board.c)
endif()
