#ifndef CEL_BRIDGE_H
#define CEL_BRIDGE_H

#define CEL_BRIDGE_ABI_VERSION 1

#ifdef __cplusplus
extern "C" {
#endif

char* cel_bridge_version(void);

char* cel_bridge_runtime_info(void);

char* cel_bridge_validate(
    const char* environment_json,
    const char* source
);

char* cel_bridge_evaluate(
    const char* environment_json,
    const char* source,
    const char* variables_json
);

void cel_bridge_free(char* value);

#ifdef __cplusplus
}
#endif

#endif
