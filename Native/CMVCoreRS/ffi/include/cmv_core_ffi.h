#ifndef CMV_CORE_FFI_H
#define CMV_CORE_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CMVOwnedBufferV1 {
  uint8_t *ptr;
  size_t len;
} CMVOwnedBufferV1;

enum CMVStatusV1 {
  CMV_STATUS_OK_V1 = 0,
  CMV_STATUS_INVALID_ARGUMENT_V1 = 1,
  CMV_STATUS_INVALID_PAYLOAD_V1 = 2,
  CMV_STATUS_RECONCILIATION_FAILED_V1 = 3,
  CMV_STATUS_PLAYBACK_PLAN_FAILED_V1 = 4,
  CMV_STATUS_SEARCH_FAILED_V1 = 5,
  CMV_STATUS_ANALYSIS_FAILED_V1 = 6,
  CMV_STATUS_DJ_FAILED_V1 = 7,
  CMV_STATUS_CACHE_FAILED_V1 = 8,
  CMV_STATUS_PANIC_V1 = 255,
};

uint32_t cmv_core_abi_version_v1(void);

int32_t cmv_core_reconcile_v1(const uint8_t *input_ptr,
                               size_t input_len,
                               CMVOwnedBufferV1 *out_buffer);

int32_t cmv_core_plan_playback_v1(const uint8_t *input_ptr,
                                   size_t input_len,
                                   CMVOwnedBufferV1 *out_buffer);

int32_t cmv_core_search_v1(const uint8_t *input_ptr,
                            size_t input_len,
                            CMVOwnedBufferV1 *out_buffer);

int32_t cmv_core_analyze_pcm_v1(const uint8_t *input_ptr,
                                 size_t input_len,
                                 CMVOwnedBufferV1 *out_buffer);

int32_t cmv_core_make_dj_v1(const uint8_t *input_ptr,
                             size_t input_len,
                             CMVOwnedBufferV1 *out_buffer);

int32_t cmv_core_eviction_plan_v1(const uint8_t *input_ptr,
                                   size_t input_len,
                                   CMVOwnedBufferV1 *out_buffer);

void cmv_core_buffer_free_v1(CMVOwnedBufferV1 buffer);

#ifdef __cplusplus
}
#endif

#endif
