#ifndef CEL_BRIDGE_H
#define CEL_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#define CEL_BRIDGE_ABI_VERSION 4

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CelBridgeBuffer {
    uint8_t* data;
    size_t len;
} CelBridgeBuffer;

char* cel_bridge_version(void);

char* cel_bridge_runtime_info(void);

char* cel_bridge_validate(
    const char* environment_json,
    const char* source
);

char* cel_bridge_validate_options(
    const char* environment_json,
    const char* source,
    const char* options_json
);

char* cel_bridge_evaluate(
    const char* environment_json,
    const char* source,
    const char* variables_json
);

char* cel_bridge_evaluate_options(
    const char* environment_json,
    const char* source,
    const char* variables_json,
    const char* options_json
);

char* cel_bridge_evaluate_many(
    const char* environment_json,
    const char* sources_json,
    const char* variables_json
);

char* cel_bridge_evaluate_requests(
    const char* environment_json,
    const char* requests_json,
    const char* options_json
);

char* cel_bridge_prepare(
    const char* environment_json,
    const char* source,
    const char* options_json
);

char* cel_bridge_evaluate_program(
    const char* program_id,
    const char* variables_json,
    const char* options_json
);

char* cel_bridge_release_program(
    const char* program_id
);

char* cel_bridge_close(void);

char* cel_bridge_create(
    const char* options_json
);

CelBridgeBuffer cel_bridge_call_v2(
    const uint8_t* request,
    size_t request_len
);

void cel_bridge_buffer_free(CelBridgeBuffer buffer);

void cel_bridge_free(char* value);

#ifdef __cplusplus
}
#endif

#endif
