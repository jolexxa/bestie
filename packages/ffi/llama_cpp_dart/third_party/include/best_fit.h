#pragma once

// best_fit: per-device memory predictor for llama.cpp.
//
// Predicts the bytes a real load would allocate on each device for the given
// (model, mparams, cparams), with no fudge factors — only what llama.cpp
// itself does. Any safety budget is the caller's job (via headroom_per_device).

#include "ggml.h"
#include "llama.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// BEST_FIT_API: export decoration for the C ABI below. Mirrors LLAMA_API's
// pattern (see include/llama.h):
//   - Linux .so / macOS .dylib: __attribute__((visibility("default"))) ensures
//     the symbol is exported even if someone later builds with
//     -fvisibility=hidden.
//   - Windows .dll (MSVC native): __declspec(dllexport) when building
//     llama-common (LLAMA_COMMON_BUILD set by the CMake target), or
//     __declspec(dllimport) for compile-time consumers. FFI consumers using
//     LoadLibrary+GetProcAddress (e.g. Dart) don't need dllimport.
//   - MinGW and static builds: no decoration needed.
#ifdef LLAMA_SHARED
#    if defined(_WIN32) && !defined(__MINGW32__)
#        ifdef LLAMA_COMMON_BUILD
#            define BEST_FIT_API __declspec(dllexport)
#        else
#            define BEST_FIT_API __declspec(dllimport)
#        endif
#    else
#        define BEST_FIT_API __attribute__ ((visibility ("default")))
#    endif
#else
#    define BEST_FIT_API
#endif

#define BEST_FIT_MAX_DEVICES 16

enum best_fit_status {
    BEST_FIT_STATUS_SUCCESS = 0,
    BEST_FIT_STATUS_FAILURE = 1,  // model doesn't fit at n_ctx_min
    BEST_FIT_STATUS_ERROR   = 2,  // hard error (file missing, load failed, etc.)
};

#ifdef __cplusplus
extern "C" {
#endif

struct best_fit_device_breakdown {
    char     name[128];
    size_t   total_bytes;
    size_t   free_bytes;
    size_t   weights_bytes;
    size_t   kv_cache_bytes;
    size_t   recurrent_state_bytes;
    size_t   compute_bytes;
    size_t   total_used_bytes;       // weights + kv + recurrent + compute
};

struct best_fit_prediction {
    enum best_fit_status status;
    int      n_devices;              // excluding host (last entry: devices[n_devices])
    struct best_fit_device_breakdown devices[BEST_FIT_MAX_DEVICES + 1];
    char     error_msg[256];
};

struct best_fit_max_ctx_result {
    enum best_fit_status status;
    uint32_t n_ctx_chosen;
    struct best_fit_prediction prediction_at_chosen;
    int      n_iterations;
    char     error_msg[256];
};

// Pure prediction; never mutates inputs.
BEST_FIT_API struct best_fit_prediction best_fit_predict(
    const char                        * path_model,
    const struct llama_model_params   * mparams,
    const struct llama_context_params * cparams);

// Binary-search the largest n_ctx in [n_ctx_min, n_ctx_max] (capped at the
// model's n_ctx_train) such that every device's predicted bytes plus the
// caller-supplied headroom_per_device[i] fits inside its free_bytes.
BEST_FIT_API struct best_fit_max_ctx_result best_fit_max_ctx(
    const char                        * path_model,
    const struct llama_model_params   * mparams,
    const struct llama_context_params * cparams,
    const size_t                      * headroom_per_device,  // length n_devices + 1; last is host
    uint32_t                            n_ctx_min,
    uint32_t                            n_ctx_max);

#ifdef __cplusplus
}
#endif
