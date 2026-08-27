#ifndef AERO_CORE_FFI_H
#define AERO_CORE_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AeroOwnedBufferV1 {
  uint8_t *ptr;
  size_t len;
} AeroOwnedBufferV1;

enum AeroStatusV1 {
  AERO_STATUS_OK_V1 = 0,
  AERO_STATUS_INVALID_ARGUMENT_V1 = 1,
  AERO_STATUS_INVALID_PAYLOAD_V1 = 2,
  AERO_STATUS_RECONCILIATION_FAILED_V1 = 3,
  AERO_STATUS_PLAYBACK_PLAN_FAILED_V1 = 4,
  AERO_STATUS_SEARCH_FAILED_V1 = 5,
  AERO_STATUS_ANALYSIS_FAILED_V1 = 6,
  AERO_STATUS_DJ_FAILED_V1 = 7,
  AERO_STATUS_CACHE_FAILED_V1 = 8,
  AERO_STATUS_PANIC_V1 = 255,
};

uint32_t aero_core_abi_version_v1(void);

int32_t aero_core_reconcile_v1(const uint8_t *input_ptr,
                               size_t input_len,
                               AeroOwnedBufferV1 *out_buffer);

int32_t aero_core_plan_playback_v1(const uint8_t *input_ptr,
                                   size_t input_len,
                                   AeroOwnedBufferV1 *out_buffer);

int32_t aero_core_search_v1(const uint8_t *input_ptr,
                            size_t input_len,
                            AeroOwnedBufferV1 *out_buffer);

int32_t aero_core_analyze_pcm_v1(const uint8_t *input_ptr,
                                 size_t input_len,
                                 AeroOwnedBufferV1 *out_buffer);

int32_t aero_core_make_dj_v1(const uint8_t *input_ptr,
                             size_t input_len,
                             AeroOwnedBufferV1 *out_buffer);

int32_t aero_core_eviction_plan_v1(const uint8_t *input_ptr,
                                   size_t input_len,
                                   AeroOwnedBufferV1 *out_buffer);

void aero_core_buffer_free_v1(AeroOwnedBufferV1 buffer);

#ifdef __cplusplus
}
#endif

#endif
