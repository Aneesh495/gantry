/*
 * GANTRY High-Assurance Cyber-Physical Automation Runtime
 * ANSI C Native Interface Test Suite
 *
 * Copyright (C) 2026 Aneesh Krishna. All rights reserved.
 */

#include "gantry.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <math.h>

static void test_engine_lifecycle(void) {
    printf("Running C API: Engine Lifecycle Tests...\n");
    gantry_engine_t* eng = gantry_engine_create("MAIN_CONTROLLER", 1000);
    assert(eng != NULL);

    int rc = gantry_register_digital_input(eng, "DI_ESTOP_PB", "Emergency Stop Pushbutton", false, 10);
    assert(rc == GANTRY_OK);

    rc = gantry_register_digital_output(eng, "DO_MAIN_CONTACTOR", "Main Power Contactor", false);
    assert(rc == GANTRY_OK);

    rc = gantry_register_analog_input(eng, "AI_BUS_VOLTAGE", "DC Bus Voltage", "V", 0.0, 1000.0, 0.0, 1000.0);
    assert(rc == GANTRY_OK);

    rc = gantry_register_analog_output(eng, "AO_VFD_FREQ_CMD", "VFD Frequency Reference", "Hz", 0.0, 60.0, 0.0, 60.0);
    assert(rc == GANTRY_OK);

    /* Duplicate tag registration should fail */
    rc = gantry_register_digital_input(eng, "DI_ESTOP_PB", "Duplicate tag", false, 0);
    assert(rc == GANTRY_ERR_DUPLICATE_TAG);

    gantry_engine_destroy(eng);
    printf("  -> Engine Lifecycle Tests: PASSED\n");
}

static void test_io_and_scan(void) {
    printf("Running C API: I/O and Cyclic Scan Tests...\n");
    gantry_engine_t* eng = gantry_engine_create("IO_CONTROLLER", 1000);
    assert(eng != NULL);

    gantry_register_digital_output(eng, "MOTOR_RUN", "Motor Run Contactor", false);
    gantry_register_analog_output(eng, "SPEED_SETPOINT", "Motor Speed", "RPM", 0, 3000, 0, 3000);

    /* Write and read */
    int rc = gantry_write_digital(eng, "MOTOR_RUN", true);
    assert(rc == GANTRY_OK);

    bool dval = false;
    rc = gantry_read_digital(eng, "MOTOR_RUN", &dval);
    assert(rc == GANTRY_OK && dval == true);

    rc = gantry_write_analog(eng, "SPEED_SETPOINT", 1750.5);
    assert(rc == GANTRY_OK);

    double aval = 0.0;
    rc = gantry_read_analog(eng, "SPEED_SETPOINT", &aval);
    assert(rc == GANTRY_OK && fabs(aval - 1750.5) < 0.001);

    /* Step cycle 100 times */
    for (int i = 0; i < 100; ++i) {
        rc = gantry_step_cycle(eng);
        assert(rc == GANTRY_OK);
    }

    gantry_cycle_stats_t stats;
    rc = gantry_get_cycle_stats(eng, &stats);
    assert(rc == GANTRY_OK);
    assert(stats.total_cycles == 100);

    gantry_engine_destroy(eng);
    printf("  -> I/O and Cyclic Scan Tests: PASSED\n");
}

static void test_safety_interlocks(void) {
    printf("Running C API: Safety Interlocks and E-Stop Tests...\n");
    gantry_engine_t* eng = gantry_engine_create("SAFETY_PLC", 1000);
    assert(eng != NULL);

    gantry_register_digital_input(eng, "HIGH_PRESSURE_SWITCH", "Vessel pressure switch", false, 0);
    gantry_register_digital_output(eng, "INLET_VALVE", "Reactant inlet valve", false);

    /* Turn on inlet valve */
    gantry_write_digital(eng, "INLET_VALVE", true);

    /* Add interlock: if HIGH_PRESSURE_SWITCH trips, force INLET_VALVE to false */
    int rc = gantry_add_interlock_rule(eng, "IL_001", "HIGH_PRESSURE_SWITCH", "INLET_VALVE", false, GANTRY_SIL_3, 0);
    assert(rc == GANTRY_OK);

    /* Step with no trip */
    gantry_step_cycle(eng);
    bool valve_open = false;
    gantry_read_digital(eng, "INLET_VALVE", &valve_open);
    assert(valve_open == true);

    /* Cause trip */
    gantry_write_digital(eng, "HIGH_PRESSURE_SWITCH", true);
    gantry_step_cycle(eng);
    gantry_read_digital(eng, "INLET_VALVE", &valve_open);
    assert(valve_open == false);

    /* Test E-Stop */
    rc = gantry_trip_estop(eng, "OPERATOR_42", "Manual physical palm button trip");
    assert(rc == GANTRY_OK);
    assert(gantry_is_estop_active(eng) == true);

    /* Writing true to valve while E-Stop active must be overridden on next cycle */
    gantry_write_digital(eng, "INLET_VALVE", true);
    gantry_step_cycle(eng);
    gantry_read_digital(eng, "INLET_VALVE", &valve_open);
    assert(valve_open == false);

    /* Reset E-Stop */
    rc = gantry_reset_estop(eng, "SUPERVISOR_01");
    assert(rc == GANTRY_OK);
    assert(gantry_is_estop_active(eng) == false);

    gantry_engine_destroy(eng);
    printf("  -> Safety Interlocks and E-Stop Tests: PASSED\n");
}

static void test_sdt_compression(void) {
    printf("Running C API: Swinging Door Trending (SDT) Compression Tests...\n");
    const size_t N = 200;
    double timestamps[200];
    double values[200];

    /* Signal with steady plateau followed by linear ramp */
    for (size_t i = 0; i < N; ++i) {
        timestamps[i] = (double)i * 0.1;
        if (i < 100) {
            values[i] = 50.0 + (0.01 * sin((double)i)); /* flat noise */
        } else {
            values[i] = 50.0 + ((double)(i - 100) * 0.5); /* linear ramp */
        }
    }

    double out_ts[200];
    double out_vals[200];
    size_t out_count = 0;

    int rc = gantry_sdt_compress(timestamps, values, N, 0.1, out_ts, out_vals, &out_count);
    assert(rc == GANTRY_OK);
    assert(out_count > 0 && out_count < 30); /* >85% compression */
    assert(out_ts[0] == timestamps[0]);
    assert(out_vals[0] == values[0]);

    printf("  -> SDT Compressed %zu samples to %zu archive records (%.1f%% ratio)\n",
           N, out_count, (1.0 - ((double)out_count / (double)N)) * 100.0);
    printf("  -> SDT Compression Tests: PASSED\n");
}

static void test_plant_simulations(void) {
    printf("Running C API: Cyber-Physical Simulation Plant Tests...\n");
    gantry_engine_t* eng = gantry_engine_create("CRANE_CONTROLLER", 1000);
    assert(eng != NULL);

    gantry_plant_t* crane = gantry_plant_create("crane", eng);
    assert(crane != NULL);

    /* Command forward trolley thrust */
    gantry_write_analog(eng, "CRANE_TROLLEY_FORCE_CMD", 50.0);
    gantry_write_analog(eng, "CRANE_HOIST_VEL_CMD", 0.5);

    for (int i = 0; i < 50; ++i) {
        int rc = gantry_plant_step(crane, 0.05, eng);
        assert(rc == GANTRY_OK);
        rc = gantry_step_cycle(eng);
        assert(rc == GANTRY_OK);
    }

    double pos = 0.0;
    gantry_read_analog(eng, "CRANE_TROLLEY_POS", &pos);
    assert(pos > 10.0);

    double hoist = 0.0;
    gantry_read_analog(eng, "CRANE_HOIST_POS", &hoist);
    assert(hoist > 15.0);

    gantry_plant_destroy(crane);
    gantry_engine_destroy(eng);
    printf("  -> Plant Simulation Tests: PASSED\n");
}

int main(void) {
    printf("============================================================\n");
    printf("       GANTRY C API VERIFICATION AND NATIVE TEST HARNESS     \n");
    printf("============================================================\n\n");

    test_engine_lifecycle();
    test_io_and_scan();
    test_safety_interlocks();
    test_sdt_compression();
    test_plant_simulations();

    printf("\n============================================================\n");
    printf("       C API VERIFICATION COMPLETE: ALL ASSERTIONS PASSED   \n");
    printf("============================================================\n");
    return 0;
}
