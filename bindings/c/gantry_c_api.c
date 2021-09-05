/*
 * GANTRY High-Assurance Cyber-Physical Automation Runtime
 * ANSI C Native Shared Library Implementation
 *
 * Copyright (C) 2026 Aneesh Krishna. All rights reserved.
 */

#include "gantry.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#define MAX_POINTS 1024
#define MAX_RULES 256
#define SDT_PI 3.14159265358979323846

typedef struct {
    char tag[64];
    char description[128];
    char engineering_units[32];
    bool is_analog;
    bool is_output;
    bool digital_val;
    double analog_val;
    uint16_t quality;
    uint64_t timestamp_ms;
    double raw_min;
    double raw_max;
    double eu_min;
    double eu_max;
    bool active_high;
    uint32_t debounce_ms;
    bool fail_safe_val;
    bool allocated;
} internal_point_t;

typedef struct {
    char id[32];
    char cause_tag[64];
    char effect_tag[64];
    bool effect_trip_val;
    gantry_sil_t sil;
    uint32_t trip_delay_ms;
    bool is_tripped;
    bool allocated;
} internal_rule_t;

struct gantry_engine {
    char name[64];
    uint32_t scan_period_us;
    internal_point_t points[MAX_POINTS];
    size_t point_count;
    internal_rule_t rules[MAX_RULES];
    size_t rule_count;
    bool estop_active;
    char estop_operator[64];
    char estop_reason[128];
    gantry_cycle_stats_t stats;
    uint64_t start_time_us;
};

/* Microsecond high-resolution clock helper */
static uint64_t get_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ((uint64_t)ts.tv_sec * 1000000ULL) + ((uint64_t)ts.tv_nsec / 1000ULL);
}

/* Engine Lifecycle */
gantry_engine_t* gantry_engine_create(const char* name, uint32_t scan_period_us) {
    if (!name || scan_period_us == 0) return NULL;
    gantry_engine_t* eng = (gantry_engine_t*)calloc(1, sizeof(gantry_engine_t));
    if (!eng) return NULL;

    strncpy(eng->name, name, sizeof(eng->name) - 1);
    eng->scan_period_us = scan_period_us;
    eng->start_time_us = get_time_us();
    return eng;
}

void gantry_engine_destroy(gantry_engine_t* engine) {
    if (engine) {
        free(engine);
    }
}

/* Point Lookup Helper */
static internal_point_t* find_point(gantry_engine_t* eng, const char* tag) {
    if (!eng || !tag) return NULL;
    for (size_t i = 0; i < eng->point_count; ++i) {
        if (eng->points[i].allocated && strcmp(eng->points[i].tag, tag) == 0) {
            return &eng->points[i];
        }
    }
    return NULL;
}

/* Point Registrations */
int gantry_register_digital_input(gantry_engine_t* engine, const char* tag, const char* desc, bool active_high, uint32_t debounce_ms) {
    if (!engine || !tag) return GANTRY_ERR_INVALID_ARG;
    if (find_point(engine, tag)) return GANTRY_ERR_DUPLICATE_TAG;
    if (engine->point_count >= MAX_POINTS) return GANTRY_ERR_BUFFER_FULL;

    internal_point_t* pt = &engine->points[engine->point_count++];
    memset(pt, 0, sizeof(*pt));
    strncpy(pt->tag, tag, sizeof(pt->tag) - 1);
    if (desc) strncpy(pt->description, desc, sizeof(pt->description) - 1);
    pt->is_analog = false;
    pt->is_output = false;
    pt->active_high = active_high;
    pt->debounce_ms = debounce_ms;
    pt->quality = GANTRY_QUALITY_GOOD;
    pt->allocated = true;
    return GANTRY_OK;
}

int gantry_register_digital_output(gantry_engine_t* engine, const char* tag, const char* desc, bool fail_safe_val) {
    if (!engine || !tag) return GANTRY_ERR_INVALID_ARG;
    if (find_point(engine, tag)) return GANTRY_ERR_DUPLICATE_TAG;
    if (engine->point_count >= MAX_POINTS) return GANTRY_ERR_BUFFER_FULL;

    internal_point_t* pt = &engine->points[engine->point_count++];
    memset(pt, 0, sizeof(*pt));
    strncpy(pt->tag, tag, sizeof(pt->tag) - 1);
    if (desc) strncpy(pt->description, desc, sizeof(pt->description) - 1);
    pt->is_analog = false;
    pt->is_output = true;
    pt->fail_safe_val = fail_safe_val;
    pt->digital_val = fail_safe_val;
    pt->quality = GANTRY_QUALITY_GOOD;
    pt->allocated = true;
    return GANTRY_OK;
}

int gantry_register_analog_input(gantry_engine_t* engine, const char* tag, const char* desc, const char* eu, double raw_min, double raw_max, double eu_min, double eu_max) {
    if (!engine || !tag || raw_min >= raw_max) return GANTRY_ERR_INVALID_ARG;
    if (find_point(engine, tag)) return GANTRY_ERR_DUPLICATE_TAG;
    if (engine->point_count >= MAX_POINTS) return GANTRY_ERR_BUFFER_FULL;

    internal_point_t* pt = &engine->points[engine->point_count++];
    memset(pt, 0, sizeof(*pt));
    strncpy(pt->tag, tag, sizeof(pt->tag) - 1);
    if (desc) strncpy(pt->description, desc, sizeof(pt->description) - 1);
    if (eu) strncpy(pt->engineering_units, eu, sizeof(pt->engineering_units) - 1);
    pt->is_analog = true;
    pt->is_output = false;
    pt->raw_min = raw_min;
    pt->raw_max = raw_max;
    pt->eu_min = eu_min;
    pt->eu_max = eu_max;
    pt->analog_val = eu_min;
    pt->quality = GANTRY_QUALITY_GOOD;
    pt->allocated = true;
    return GANTRY_OK;
}

int gantry_register_analog_output(gantry_engine_t* engine, const char* tag, const char* desc, const char* eu, double raw_min, double raw_max, double eu_min, double eu_max) {
    if (!engine || !tag || raw_min >= raw_max) return GANTRY_ERR_INVALID_ARG;
    if (find_point(engine, tag)) return GANTRY_ERR_DUPLICATE_TAG;
    if (engine->point_count >= MAX_POINTS) return GANTRY_ERR_BUFFER_FULL;

    internal_point_t* pt = &engine->points[engine->point_count++];
    memset(pt, 0, sizeof(*pt));
    strncpy(pt->tag, tag, sizeof(pt->tag) - 1);
    if (desc) strncpy(pt->description, desc, sizeof(pt->description) - 1);
    if (eu) strncpy(pt->engineering_units, eu, sizeof(pt->engineering_units) - 1);
    pt->is_analog = true;
    pt->is_output = true;
    pt->raw_min = raw_min;
    pt->raw_max = raw_max;
    pt->eu_min = eu_min;
    pt->eu_max = eu_max;
    pt->analog_val = eu_min;
    pt->quality = GANTRY_QUALITY_GOOD;
    pt->allocated = true;
    return GANTRY_OK;
}

/* Process Image Table Access */
int gantry_read_digital(gantry_engine_t* engine, const char* tag, bool* out_val) {
    if (!engine || !tag || !out_val) return GANTRY_ERR_INVALID_ARG;
    internal_point_t* pt = find_point(engine, tag);
    if (!pt || pt->is_analog) return GANTRY_ERR_TAG_NOT_FOUND;
    *out_val = pt->digital_val;
    return GANTRY_OK;
}

int gantry_write_digital(gantry_engine_t* engine, const char* tag, bool val) {
    if (!engine || !tag) return GANTRY_ERR_INVALID_ARG;
    internal_point_t* pt = find_point(engine, tag);
    if (!pt || pt->is_analog) return GANTRY_ERR_TAG_NOT_FOUND;
    pt->digital_val = val;
    pt->timestamp_ms = get_time_us() / 1000ULL;
    return GANTRY_OK;
}

int gantry_read_analog(gantry_engine_t* engine, const char* tag, double* out_val) {
    if (!engine || !tag || !out_val) return GANTRY_ERR_INVALID_ARG;
    internal_point_t* pt = find_point(engine, tag);
    if (!pt || !pt->is_analog) return GANTRY_ERR_TAG_NOT_FOUND;
    *out_val = pt->analog_val;
    return GANTRY_OK;
}

int gantry_write_analog(gantry_engine_t* engine, const char* tag, double val) {
    if (!engine || !tag) return GANTRY_ERR_INVALID_ARG;
    internal_point_t* pt = find_point(engine, tag);
    if (!pt || !pt->is_analog) return GANTRY_ERR_TAG_NOT_FOUND;
    pt->analog_val = val;
    pt->timestamp_ms = get_time_us() / 1000ULL;
    return GANTRY_OK;
}

/* Cyclic Executive Execution */
int gantry_step_cycle(gantry_engine_t* engine) {
    if (!engine) return GANTRY_ERR_INVALID_ARG;
    uint64_t t_start = get_time_us();

    /* 1. Evaluate Cause and Effect safety interlock rules */
    for (size_t i = 0; i < engine->rule_count; ++i) {
        internal_rule_t* r = &engine->rules[i];
        if (!r->allocated) continue;

        internal_point_t* cause = find_point(engine, r->cause_tag);
        internal_point_t* effect = find_point(engine, r->effect_tag);

        if (cause && effect) {
            bool cause_tripped = cause->is_analog ? (cause->analog_val > 0.0) : cause->digital_val;
            if (cause_tripped) {
                r->is_tripped = true;
                if (!effect->is_analog) {
                    effect->digital_val = r->effect_trip_val;
                }
            } else {
                r->is_tripped = false;
            }
        }
    }

    /* 2. Enforce Emergency Stop condition */
    if (engine->estop_active) {
        for (size_t i = 0; i < engine->point_count; ++i) {
            internal_point_t* pt = &engine->points[i];
            if (pt->allocated && pt->is_output) {
                if (!pt->is_analog) {
                    pt->digital_val = pt->fail_safe_val;
                } else {
                    pt->analog_val = pt->eu_min;
                }
            }
        }
    }

    /* 3. Compute execution time and update jitter/scan statistics */
    uint64_t t_end = get_time_us();
    double scan_us = (double)(t_end - t_start);

    engine->stats.total_cycles++;
    engine->stats.last_scan_us = scan_us;
    if (scan_us > engine->stats.max_scan_us) {
        engine->stats.max_scan_us = scan_us;
    }
    double n = (double)engine->stats.total_cycles;
    engine->stats.avg_scan_us = ((engine->stats.avg_scan_us * (n - 1.0)) + scan_us) / n;

    if (scan_us > (double)engine->scan_period_us) {
        engine->stats.total_overruns++;
    }

    double jitter = fabs(scan_us - (double)engine->scan_period_us);
    engine->stats.last_jitter_us = jitter;
    if (jitter > engine->stats.max_jitter_us) {
        engine->stats.max_jitter_us = jitter;
    }

    return GANTRY_OK;
}

int gantry_get_cycle_stats(gantry_engine_t* engine, gantry_cycle_stats_t* out_stats) {
    if (!engine || !out_stats) return GANTRY_ERR_INVALID_ARG;
    *out_stats = engine->stats;
    return GANTRY_OK;
}

/* Safety Interlocking */
int gantry_add_interlock_rule(gantry_engine_t* engine, const char* id, const char* cause_tag, const char* effect_tag, bool effect_trip_val, gantry_sil_t sil, uint32_t trip_delay_ms) {
    if (!engine || !id || !cause_tag || !effect_tag) return GANTRY_ERR_INVALID_ARG;
    if (engine->rule_count >= MAX_RULES) return GANTRY_ERR_BUFFER_FULL;

    internal_rule_t* r = &engine->rules[engine->rule_count++];
    memset(r, 0, sizeof(*r));
    strncpy(r->id, id, sizeof(r->id) - 1);
    strncpy(r->cause_tag, cause_tag, sizeof(r->cause_tag) - 1);
    strncpy(r->effect_tag, effect_tag, sizeof(r->effect_tag) - 1);
    r->effect_trip_val = effect_trip_val;
    r->sil = sil;
    r->trip_delay_ms = trip_delay_ms;
    r->allocated = true;
    return GANTRY_OK;
}

int gantry_trip_estop(gantry_engine_t* engine, const char* operator_id, const char* reason) {
    if (!engine) return GANTRY_ERR_INVALID_ARG;
    engine->estop_active = true;
    if (operator_id) strncpy(engine->estop_operator, operator_id, sizeof(engine->estop_operator) - 1);
    if (reason) strncpy(engine->estop_reason, reason, sizeof(engine->estop_reason) - 1);

    /* Immediately latch all outputs to fail-safe safe state */
    for (size_t i = 0; i < engine->point_count; ++i) {
        internal_point_t* pt = &engine->points[i];
        if (pt->allocated && pt->is_output) {
            if (!pt->is_analog) {
                pt->digital_val = pt->fail_safe_val;
            } else {
                pt->analog_val = pt->eu_min;
            }
        }
    }
    return GANTRY_OK;
}

int gantry_reset_estop(gantry_engine_t* engine, const char* operator_id) {
    if (!engine) return GANTRY_ERR_INVALID_ARG;
    engine->estop_active = false;
    memset(engine->estop_operator, 0, sizeof(engine->estop_operator));
    memset(engine->estop_reason, 0, sizeof(engine->estop_reason));
    return GANTRY_OK;
}

bool gantry_is_estop_active(gantry_engine_t* engine) {
    return engine ? engine->estop_active : false;
}

/* Swinging Door Trending (SDT) Compression */
int gantry_sdt_compress(
    const double* timestamps,
    const double* values,
    size_t count,
    double compression_deviation,
    double* out_timestamps,
    double* out_values,
    size_t* out_count
) {
    if (!timestamps || !values || !out_timestamps || !out_values || !out_count) {
        return GANTRY_ERR_INVALID_ARG;
    }
    if (count == 0) {
        *out_count = 0;
        return GANTRY_OK;
    }

    size_t out_idx = 0;

    /* Always record initial point */
    out_timestamps[out_idx] = timestamps[0];
    out_values[out_idx] = values[0];
    out_idx++;

    if (count == 1) {
        *out_count = out_idx;
        return GANTRY_OK;
    }

    double pivot_t = timestamps[0];
    double pivot_v = values[0];
    double slope_max = (values[1] + compression_deviation - pivot_v) / (timestamps[1] - pivot_t);
    double slope_min = (values[1] - compression_deviation - pivot_v) / (timestamps[1] - pivot_t);

    for (size_t i = 2; i < count; ++i) {
        double dt = timestamps[i] - pivot_t;
        if (dt <= 0.0) continue;

        double s_upper = (values[i] + compression_deviation - pivot_v) / dt;
        double s_lower = (values[i] - compression_deviation - pivot_v) / dt;

        if (s_upper < slope_max) slope_max = s_upper;
        if (s_lower > slope_min) slope_min = s_lower;

        if (slope_min > slope_max) {
            /* Door closed: retain previous point i-1 as archive point */
            out_timestamps[out_idx] = timestamps[i - 1];
            out_values[out_idx] = values[i - 1];
            out_idx++;

            /* Reset pivot to point i-1 */
            pivot_t = timestamps[i - 1];
            pivot_v = values[i - 1];
            double dt_new = timestamps[i] - pivot_t;
            slope_max = (values[i] + compression_deviation - pivot_v) / dt_new;
            slope_min = (values[i] - compression_deviation - pivot_v) / dt_new;
        }
    }

    /* Always preserve final point */
    out_timestamps[out_idx] = timestamps[count - 1];
    out_values[out_idx] = values[count - 1];
    out_idx++;

    *out_count = out_idx;
    return GANTRY_OK;
}

/* Cyber-Physical Simulation Models */
typedef enum {
    PLANT_TYPE_CRANE,
    PLANT_TYPE_REACTOR,
    PLANT_TYPE_RAIL
} plant_kind_t;

struct gantry_plant {
    plant_kind_t kind;
    double sim_time_sec;

    /* Crane state */
    double trolley_pos_m;
    double trolley_vel_mps;
    double hoist_pos_m;
    double hoist_vel_mps;
    double sway_angle_rad;
    double sway_rate_radps;

    /* Reactor state */
    double reactor_temp_c;
    double reactor_press_bar;
    bool burst_disc_blown;

    /* Rail junction state */
    double train_pos_m;
    int point_position;
    int point_target;
    double transition_timer_sec;
};

gantry_plant_t* gantry_plant_create(const char* plant_type, gantry_engine_t* engine) {
    if (!plant_type) return NULL;
    gantry_plant_t* p = (gantry_plant_t*)calloc(1, sizeof(gantry_plant_t));
    if (!p) return NULL;

    if (strcmp(plant_type, "crane") == 0) {
        p->kind = PLANT_TYPE_CRANE;
        p->trolley_pos_m = 10.0;
        p->hoist_pos_m = 15.0;

        if (engine) {
            gantry_register_analog_input(engine, "CRANE_TROLLEY_POS", "Trolley position", "m", 0, 100, 0, 100);
            gantry_register_analog_input(engine, "CRANE_HOIST_POS", "Hoist depth", "m", 0, 50, 0, 50);
            gantry_register_analog_input(engine, "CRANE_SWAY_ANGLE", "Sway angle", "deg", -45, 45, -45, 45);
            gantry_register_digital_input(engine, "CRANE_TROLLEY_WEST_LS", "West limit", false, 0);
            gantry_register_digital_input(engine, "CRANE_TROLLEY_EAST_LS", "East limit", false, 0);
            gantry_register_analog_output(engine, "CRANE_TROLLEY_FORCE_CMD", "Trolley thrust", "kN", -100, 100, -100, 100);
            gantry_register_analog_output(engine, "CRANE_HOIST_VEL_CMD", "Hoist winch velocity", "m/s", -3, 3, -3, 3);

            gantry_write_analog(engine, "CRANE_TROLLEY_POS", p->trolley_pos_m);
            gantry_write_analog(engine, "CRANE_HOIST_POS", p->hoist_pos_m);
            gantry_write_analog(engine, "CRANE_SWAY_ANGLE", 0.0);
            gantry_write_digital(engine, "CRANE_TROLLEY_WEST_LS", false);
            gantry_write_digital(engine, "CRANE_TROLLEY_EAST_LS", false);
        }
    } else if (strcmp(plant_type, "reactor") == 0) {
        p->kind = PLANT_TYPE_REACTOR;
        p->reactor_temp_c = 65.0;
        p->reactor_press_bar = 15.0;

        if (engine) {
            gantry_register_analog_input(engine, "REACTOR_TEMP", "Reactor temp", "degC", 0, 300, 0, 300);
            gantry_register_analog_input(engine, "REACTOR_PRESS", "Vessel pressure", "bar", 0, 150, 0, 150);
            gantry_register_digital_input(engine, "BURST_DISC_STATUS", "Rupture disc", false, 0);
            gantry_register_analog_output(engine, "COOLANT_FLOW_CMD", "Coolant flow", "m3/h", 0, 100, 0, 100);
            gantry_register_analog_output(engine, "FEED_RATE_CMD", "Chemical feed rate", "kg/h", 0, 500, 0, 500);
            gantry_register_digital_output(engine, "EMERGENCY_VENT_VALVE", "Vent valve", false);

            gantry_write_analog(engine, "REACTOR_TEMP", p->reactor_temp_c);
            gantry_write_analog(engine, "REACTOR_PRESS", p->reactor_press_bar);
            gantry_write_digital(engine, "BURST_DISC_STATUS", false);
        }
    } else if (strcmp(plant_type, "rail") == 0) {
        p->kind = PLANT_TYPE_RAIL;
        p->train_pos_m = 0.0;
        p->point_position = 0;

        if (engine) {
            gantry_register_digital_input(engine, "RAIL_TC1_APPROACH", "Approach track circuit", false, 0);
            gantry_register_digital_input(engine, "RAIL_TC2_TURNOUT", "Turnout track circuit", false, 0);
            gantry_register_digital_input(engine, "RAIL_TC3_MAIN", "Mainline departure", false, 0);
            gantry_register_digital_input(engine, "RAIL_POINT_NORMAL_IND", "Point normal", false, 0);
            gantry_register_digital_input(engine, "RAIL_POINT_REVERSE_IND", "Point reverse", false, 0);
            gantry_register_digital_output(engine, "RAIL_POINT_MOTOR_REV_CMD", "Switch to reverse", false);

            gantry_write_digital(engine, "RAIL_POINT_NORMAL_IND", true);
            gantry_write_digital(engine, "RAIL_POINT_REVERSE_IND", false);
            gantry_write_digital(engine, "RAIL_TC1_APPROACH", true);
            gantry_write_digital(engine, "RAIL_TC2_TURNOUT", false);
            gantry_write_digital(engine, "RAIL_TC3_MAIN", false);
        }
    } else {
        free(p);
        return NULL;
    }

    return p;
}

int gantry_plant_step(gantry_plant_t* plant, double dt_sec, gantry_engine_t* engine) {
    if (!plant || !engine || dt_sec <= 0.0) return GANTRY_ERR_INVALID_ARG;

    plant->sim_time_sec += dt_sec;

    if (plant->kind == PLANT_TYPE_CRANE) {
        double thrust_kn = 0.0;
        double hoist_cmd = 0.0;
        gantry_read_analog(engine, "CRANE_TROLLEY_FORCE_CMD", &thrust_kn);
        gantry_read_analog(engine, "CRANE_HOIST_VEL_CMD", &hoist_cmd);

        double thrust_n = thrust_kn * 1000.0;
        double accel = (thrust_n - (1500.0 * plant->trolley_vel_mps)) / 25000.0;
        plant->trolley_vel_mps += accel * dt_sec;
        plant->trolley_pos_m += plant->trolley_vel_mps * dt_sec;

        if (plant->trolley_pos_m < 0.5) {
            plant->trolley_pos_m = 0.5;
            plant->trolley_vel_mps = 0.0;
        } else if (plant->trolley_pos_m > 79.5) {
            plant->trolley_pos_m = 79.5;
            plant->trolley_vel_mps = 0.0;
        }

        plant->hoist_pos_m += hoist_cmd * dt_sec;
        if (plant->hoist_pos_m < 1.0) plant->hoist_pos_m = 1.0;
        if (plant->hoist_pos_m > 35.0) plant->hoist_pos_m = 35.0;

        /* Pendulum sway ODE: theta_ddot = - (g/L) sin(theta) - (accel/L) cos(theta) - damping*theta_dot */
        double l = plant->hoist_pos_m;
        double sway_acc = (- (9.80665 / l) * sin(plant->sway_angle_rad)) - ((accel / l) * cos(plant->sway_angle_rad)) - (0.05 * plant->sway_rate_radps);
        plant->sway_rate_radps += sway_acc * dt_sec;
        plant->sway_angle_rad += plant->sway_rate_radps * dt_sec;

        /* Synchronize to image table */
        gantry_write_analog(engine, "CRANE_TROLLEY_POS", plant->trolley_pos_m);
        gantry_write_analog(engine, "CRANE_HOIST_POS", plant->hoist_pos_m);
        gantry_write_analog(engine, "CRANE_SWAY_ANGLE", plant->sway_angle_rad * (180.0 / SDT_PI));
        gantry_write_digital(engine, "CRANE_TROLLEY_WEST_LS", plant->trolley_pos_m <= 1.0);
        gantry_write_digital(engine, "CRANE_TROLLEY_EAST_LS", plant->trolley_pos_m >= 79.0);

    } else if (plant->kind == PLANT_TYPE_REACTOR) {
        double feed_rate = 100.0;
        double coolant_flow = 20.0;
        bool vent_open = false;
        gantry_read_analog(engine, "FEED_RATE_CMD", &feed_rate);
        gantry_read_analog(engine, "COOLANT_FLOW_CMD", &coolant_flow);
        gantry_read_digital(engine, "EMERGENCY_VENT_VALVE", &vent_open);

        double q_rxn = feed_rate * 0.15 * (1.0 + pow(plant->reactor_temp_c / 50.0, 2));
        double q_cool = coolant_flow * 0.8 * (plant->reactor_temp_c - 20.0);
        double dt_temp = (q_rxn - q_cool) * 0.05;
        plant->reactor_temp_c += dt_temp * dt_sec;
        if (plant->reactor_temp_c < 10.0) plant->reactor_temp_c = 10.0;

        plant->reactor_press_bar = 1.0 + (pow(plant->reactor_temp_c / 100.0, 3) * 15.0);
        if (vent_open) plant->reactor_press_bar *= 0.4;

        if (plant->reactor_press_bar >= 95.0) plant->burst_disc_blown = true;
        if (plant->burst_disc_blown) plant->reactor_press_bar = 1.5;

        gantry_write_analog(engine, "REACTOR_TEMP", plant->reactor_temp_c);
        gantry_write_analog(engine, "REACTOR_PRESS", plant->reactor_press_bar);
        gantry_write_digital(engine, "BURST_DISC_STATUS", plant->burst_disc_blown);

    } else if (plant->kind == PLANT_TYPE_RAIL) {
        bool rev_cmd = false;
        gantry_read_digital(engine, "RAIL_POINT_MOTOR_REV_CMD", &rev_cmd);

        if (rev_cmd && plant->point_target != 1) {
            plant->point_target = 1;
            plant->point_position = -1;
            plant->transition_timer_sec = 0.0;
        } else if (!rev_cmd && plant->point_target != 0) {
            plant->point_target = 0;
            plant->point_position = -1;
            plant->transition_timer_sec = 0.0;
        }

        if (plant->point_position == -1) {
            plant->transition_timer_sec += dt_sec;
            if (plant->transition_timer_sec >= 3.0) {
                plant->point_position = plant->point_target;
            }
        }

        plant->train_pos_m += 15.0 * dt_sec;
        if (plant->train_pos_m > 500.0) plant->train_pos_m = 0.0;

        gantry_write_digital(engine, "RAIL_TC1_APPROACH", plant->train_pos_m < 100.0);
        gantry_write_digital(engine, "RAIL_TC2_TURNOUT", plant->train_pos_m >= 100.0 && plant->train_pos_m < 200.0);
        gantry_write_digital(engine, "RAIL_TC3_MAIN", plant->train_pos_m >= 200.0 && plant->point_position == 0);
        gantry_write_digital(engine, "RAIL_POINT_NORMAL_IND", plant->point_position == 0);
        gantry_write_digital(engine, "RAIL_POINT_REVERSE_IND", plant->point_position == 1);
    }

    return GANTRY_OK;
}

void gantry_plant_destroy(gantry_plant_t* plant) {
    if (plant) {
        free(plant);
    }
}
