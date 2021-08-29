/*
 * GANTRY High-Assurance Cyber-Physical Automation Runtime
 * ANSI C Native Interface and System FFI Definitions
 *
 * Copyright (C) 2026 Aneesh Krishna. All rights reserved.
 */

#ifndef GANTRY_H
#define GANTRY_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) || defined(__CYGWIN__)
  #ifdef GANTRY_BUILD_SHARED
    #define GANTRY_API __declspec(dllexport)
  #else
    #define GANTRY_API __declspec(dllimport)
  #endif
#else
  #if __GNUC__ >= 4
    #define GANTRY_API __attribute__((visibility("default")))
  #else
    #define GANTRY_API
  #endif
#endif

/* Return and status error codes */
#define GANTRY_OK                     0
#define GANTRY_ERR_GENERIC           -1
#define GANTRY_ERR_INVALID_ARG       -2
#define GANTRY_ERR_TAG_NOT_FOUND     -3
#define GANTRY_ERR_DUPLICATE_TAG     -4
#define GANTRY_ERR_ESTOP_ACTIVE      -5
#define GANTRY_ERR_OVERRUN           -6
#define GANTRY_ERR_BUFFER_FULL       -7
#define GANTRY_ERR_CYCLE_FAULT       -8

/* IEC 61850 Signal Quality Flags */
#define GANTRY_QUALITY_GOOD          0x0000
#define GANTRY_QUALITY_INVALID       0x0001
#define GANTRY_QUALITY_OVERFLOW      0x0002
#define GANTRY_QUALITY_OUT_OF_BOUNDS 0x0004
#define GANTRY_QUALITY_BAD_REFERENCE 0x0008
#define GANTRY_QUALITY_OSCILLATORY   0x0010
#define GANTRY_QUALITY_TEST          0x0020
#define GANTRY_QUALITY_OPERATOR_OVR  0x0040

/* Safety Integrity Levels (IEC 61508) */
typedef enum {
    GANTRY_SIL_0 = 0,
    GANTRY_SIL_1 = 1,
    GANTRY_SIL_2 = 2,
    GANTRY_SIL_3 = 3,
    GANTRY_SIL_4 = 4
} gantry_sil_t;

/* Opaque runtime engine and simulation handles */
typedef struct gantry_engine gantry_engine_t;
typedef struct gantry_plant gantry_plant_t;

/* Cyclic executive telemetry statistics */
typedef struct {
    uint64_t total_cycles;
    uint64_t total_overruns;
    double last_scan_us;
    double avg_scan_us;
    double max_scan_us;
    double last_jitter_us;
    double max_jitter_us;
} gantry_cycle_stats_t;

/* Telemetry point metadata descriptor */
typedef struct {
    char tag[64];
    char description[128];
    char engineering_units[32];
    bool is_analog;
    bool is_output;
    double min_range;
    double max_range;
} gantry_point_desc_t;

/* Engine Lifecycle */
GANTRY_API gantry_engine_t* gantry_engine_create(const char* name, uint32_t scan_period_us);
GANTRY_API void gantry_engine_destroy(gantry_engine_t* engine);

/* I/O Registration */
GANTRY_API int gantry_register_digital_input(gantry_engine_t* engine, const char* tag, const char* desc, bool active_high, uint32_t debounce_ms);
GANTRY_API int gantry_register_digital_output(gantry_engine_t* engine, const char* tag, const char* desc, bool fail_safe_val);
GANTRY_API int gantry_register_analog_input(gantry_engine_t* engine, const char* tag, const char* desc, const char* eu, double raw_min, double raw_max, double eu_min, double eu_max);
GANTRY_API int gantry_register_analog_output(gantry_engine_t* engine, const char* tag, const char* desc, const char* eu, double raw_min, double raw_max, double eu_min, double eu_max);

/* Process Image Table Access */
GANTRY_API int gantry_read_digital(gantry_engine_t* engine, const char* tag, bool* out_val);
GANTRY_API int gantry_write_digital(gantry_engine_t* engine, const char* tag, bool val);
GANTRY_API int gantry_read_analog(gantry_engine_t* engine, const char* tag, double* out_val);
GANTRY_API int gantry_write_analog(gantry_engine_t* engine, const char* tag, double val);

/* Cyclic Executive Execution */
GANTRY_API int gantry_step_cycle(gantry_engine_t* engine);
GANTRY_API int gantry_get_cycle_stats(gantry_engine_t* engine, gantry_cycle_stats_t* out_stats);

/* Safety and Interlocking */
GANTRY_API int gantry_add_interlock_rule(gantry_engine_t* engine, const char* id, const char* cause_tag, const char* effect_tag, bool effect_trip_val, gantry_sil_t sil, uint32_t trip_delay_ms);
GANTRY_API int gantry_trip_estop(gantry_engine_t* engine, const char* operator_id, const char* reason);
GANTRY_API int gantry_reset_estop(gantry_engine_t* engine, const char* operator_id);
GANTRY_API bool gantry_is_estop_active(gantry_engine_t* engine);

/* Swinging Door Trending (SDT) Compression */
GANTRY_API int gantry_sdt_compress(
    const double* timestamps,
    const double* values,
    size_t count,
    double compression_deviation,
    double* out_timestamps,
    double* out_values,
    size_t* out_count
);

/* Cyber-Physical Simulation Models */
GANTRY_API gantry_plant_t* gantry_plant_create(const char* plant_type, gantry_engine_t* engine);
GANTRY_API int gantry_plant_step(gantry_plant_t* plant, double dt_sec, gantry_engine_t* engine);
GANTRY_API void gantry_plant_destroy(gantry_plant_t* plant);

#ifdef __cplusplus
}
#endif

#endif /* GANTRY_H */
