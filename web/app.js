/**
 * GANTRY Operator Supervisory Control & Data Acquisition (SCADA) Engine
 * High-Assurance Cyber-Physical Automation Runtime
 *
 * Copyright (C) 2026 Aneesh Krishna. All rights reserved.
 */

(function () {
  'use strict';

  // --- Plant States ---
  const state = {
    currentPlant: 'crane',
    estopActive: false,
    estopTrippedBy: '',
    simTimeSec: 0,
    cycleCount: 0,
    scanUs: 42,
    jitterUs: 3.2,

    // Crane
    crane: {
      trolleyPos: 10.0,
      trolleyVel: 0.0,
      trolleyForceCmd: 35.0,
      hoistDepth: 15.0,
      hoistVelCmd: 0.2,
      swayAngle: 0.0,
      swayRate: 0.0,
      westLs: false,
      eastLs: false
    },

    // Reactor
    reactor: {
      temp: 65.0,
      pressure: 15.0,
      feedRateCmd: 220.0,
      coolantFlowCmd: 40.0,
      ventValve: false,
      burstDiscBlown: false
    },

    // Rail
    rail: {
      trainPos: 0.0,
      pointPos: 0, // 0: Normal, 1: Reverse, -1: In transit
      pointTarget: 0,
      transitTimer: 0.0,
      pointCmdRev: false,
      tc1: true,
      tc2: false,
      tc3: false,
      signalAspect: 'GREEN' // RED, YELLOW, GREEN
    },

    // Alarms (ISA-18.2 State: 0: NORMAL, 1: UNACK, 2: ACK, 3: RTN_UNACK)
    alarms: [
      { id: 'ALM_01', tag: 'CRANE_SWAY_HIGH', desc: 'Payload pendulum sway angle > 12.0 deg', state: 0, prio: 'HIGH' },
      { id: 'ALM_02', tag: 'CRANE_TRAVEL_LIMIT', desc: 'Trolley approached end-of-track buffer', state: 0, prio: 'CRITICAL' },
      { id: 'ALM_03', tag: 'REACTOR_HIGH_TEMP', desc: 'Bulk core temp exceeded safety limit (80C)', state: 0, prio: 'HIGH' },
      { id: 'ALM_04', tag: 'REACTOR_HIGH_PRESS', desc: 'Vessel vapor pressure approaching design limit (85 bar)', state: 0, prio: 'CRITICAL' },
      { id: 'ALM_05', tag: 'RAIL_CONFLICT_ROUTE', desc: 'Turnout switch commanded while section occupied', state: 0, prio: 'CRITICAL' }
    ],

    // Cause and Effect Matrix Rules
    cem: [
      { id: 'IL-CRANE-01', plant: 'crane', cause: 'CRANE_SWAY_HIGH', condition: 'Sway > 15.0 deg', effect: 'CRANE_TROLLEY_DRIVE', failSafe: 'TRIP (0 kN)', sil: 'SIL-3', tripped: false },
      { id: 'IL-CRANE-02', plant: 'crane', cause: 'CRANE_LIMIT_WEST', condition: 'West LS Tripped', effect: 'CRANE_WEST_MOTOR', failSafe: 'INHIBIT REVERSE', sil: 'SIL-3', tripped: false },
      { id: 'IL-REACT-01', plant: 'reactor', cause: 'REACTOR_PRESS_TRIP', condition: 'Press > 85.0 bar', effect: 'EMERGENCY_VENT_VALVE', failSafe: 'ENERGIZE OPEN', sil: 'SIL-4', tripped: false },
      { id: 'IL-REACT-02', plant: 'reactor', cause: 'REACTOR_TEMP_TRIP', condition: 'Temp > 110.0 degC', effect: 'FEED_PUMP_CUTOFF', failSafe: 'DE-ENERGIZE OFF', sil: 'SIL-3', tripped: false },
      { id: 'IL-RAIL-01', plant: 'rail', cause: 'TURNOUT_OCCUPIED', condition: 'TC2 Track Circuit Active', effect: 'POINT_MACHINE_MOTOR', failSafe: 'LOCK IN PLACE', sil: 'SIL-4', tripped: false }
    ],

    // Historian & SDT stats
    sdt: {
      rawCount: 0,
      archiveCount: 0
    },

    soe: []
  };

  // --- Time-Series Strip Chart Buffer ---
  const chartHistory = {
    time: [],
    series1: [],
    series2: []
  };
  const MAX_CHART_POINTS = 120;

  // --- DOM Elements ---
  const dom = {
    scanRate: document.getElementById('telemetry-scan-rate'),
    scanUs: document.getElementById('telemetry-scan-us'),
    jitterUs: document.getElementById('telemetry-jitter-us'),
    btnEstop: document.getElementById('btn-estop'),
    btnResetEstop: document.getElementById('btn-reset-estop'),
    svgViewport: document.getElementById('svg-viewport'),
    actuatorControls: document.getElementById('actuator-controls'),
    cemBody: document.getElementById('cem-body'),
    interlockStatus: document.getElementById('interlock-status'),
    stripChart: document.getElementById('strip-chart'),
    chartLegend: document.getElementById('chart-legend'),
    alarmBanner: document.getElementById('alarm-banner'),
    alarmSummaryText: document.getElementById('alarm-summary-text'),
    alarmTiles: document.getElementById('alarm-tiles'),
    btnAckAlarms: document.getElementById('btn-ack-alarms'),
    btnSilenceHorn: document.getElementById('btn-silence-horn'),
    soeBody: document.getElementById('soe-body'),
    stCodeView: document.getElementById('st-code-view'),
    sdtRawCount: document.getElementById('sdt-raw-count'),
    sdtArchiveCount: document.getElementById('sdt-archive-count'),
    plantTabs: document.querySelectorAll('.plant-tabs .tab-btn')
  };

  // --- Helper Functions ---
  function logSOE(tag, desc, val) {
    const now = new Date();
    const timeStr = now.toISOString().substring(11, 23);
    const item = { time: timeStr, tag: tag, desc: desc, val: val };
    state.soe.unshift(item);
    if (state.soe.length > 50) state.soe.pop();

    const row = document.createElement('tr');
    row.innerHTML = `<td>${item.time}</td><td><strong>${item.tag}</strong></td><td>${item.desc}</td><td>${item.val}</td>`;
    dom.soeBody.prepend(row);
    if (dom.soeBody.children.length > 30) {
      dom.soeBody.removeChild(dom.soeBody.lastChild);
    }
  }

  // --- Plant Switching ---
  function setPlant(plant) {
    state.currentPlant = plant;
    dom.plantTabs.forEach(function (btn) {
      btn.classList.toggle('active', btn.dataset.plant === plant);
    });
    renderActuatorControls();
    updateCodeView();
    updateChartLegend();
    logSOE('SYS_PLANT', 'Operator switched supervisory context to ' + plant.toUpperCase(), plant);
  }

  dom.plantTabs.forEach(function (btn) {
    btn.addEventListener('click', function () {
      setPlant(this.dataset.plant);
    });
  });

  // --- E-Stop Handler ---
  dom.btnEstop.addEventListener('click', function () {
    if (!state.estopActive) {
      state.estopActive = true;
      state.estopTrippedBy = 'OPERATOR_DESK';
      dom.btnEstop.classList.add('active');
      dom.btnResetEstop.disabled = false;
      logSOE('SAFETY_ESTOP', 'Master Emergency Stop palm switch pushed', 'LATCHED_TRIP');
    }
  });

  dom.btnResetEstop.addEventListener('click', function () {
    if (state.estopActive) {
      state.estopActive = false;
      dom.btnEstop.classList.remove('active');
      dom.btnResetEstop.disabled = true;
      logSOE('SAFETY_ESTOP', 'Master Emergency Stop reset verified by supervisor', 'CLEARED');
    }
  });

  // --- Alarm Annunciator Controls ---
  dom.btnAckAlarms.addEventListener('click', function () {
    state.alarms.forEach(function (a) {
      if (a.state === 1) a.state = 2; // UNACK -> ACK
      if (a.state === 3) a.state = 0; // RTN_UNACK -> NORMAL
    });
    renderAlarms();
  });

  dom.btnSilenceHorn.addEventListener('click', function () {
    dom.alarmBanner.classList.remove('active-alarm');
  });

  // --- Actuator Controls Render ---
  function renderActuatorControls() {
    if (state.currentPlant === 'crane') {
      dom.actuatorControls.innerHTML = `
        <div class="ctrl-row">
          <span class="ctrl-label">Trolley Thrust Command (kN):</span>
          <span class="ctrl-val" id="val-trolley-thrust">${state.crane.trolleyForceCmd} kN</span>
          <input type="range" class="slider-input" id="slide-thrust" min="-80" max="80" value="${state.crane.trolleyForceCmd}">
        </div>
        <div class="ctrl-row">
          <span class="ctrl-label">Hoist Winch Speed (m/s):</span>
          <span class="ctrl-val" id="val-hoist-speed">${state.crane.hoistVelCmd} m/s</span>
          <input type="range" class="slider-input" id="slide-hoist" min="-2.0" max="2.0" step="0.1" value="${state.crane.hoistVelCmd}">
        </div>
      `;
      document.getElementById('slide-thrust').addEventListener('input', function (e) {
        state.crane.trolleyForceCmd = parseFloat(e.target.value);
        document.getElementById('val-trolley-thrust').textContent = state.crane.trolleyForceCmd + ' kN';
      });
      document.getElementById('slide-hoist').addEventListener('input', function (e) {
        state.crane.hoistVelCmd = parseFloat(e.target.value);
        document.getElementById('val-hoist-speed').textContent = state.crane.hoistVelCmd + ' m/s';
      });

    } else if (state.currentPlant === 'reactor') {
      dom.actuatorControls.innerHTML = `
        <div class="ctrl-row">
          <span class="ctrl-label">Reactant Feed Rate (kg/h):</span>
          <span class="ctrl-val" id="val-feed-rate">${state.reactor.feedRateCmd} kg/h</span>
          <input type="range" class="slider-input" id="slide-feed" min="0" max="500" value="${state.reactor.feedRateCmd}">
        </div>
        <div class="ctrl-row">
          <span class="ctrl-label">Cooling Jacket Flow (m3/h):</span>
          <span class="ctrl-val" id="val-coolant-flow">${state.reactor.coolantFlowCmd} m3/h</span>
          <input type="range" class="slider-input" id="slide-coolant" min="0" max="100" value="${state.reactor.coolantFlowCmd}">
        </div>
        <div class="ctrl-row">
          <span class="ctrl-label">Emergency Flare Vent Valve:</span>
          <button id="btn-vent" class="btn-subtle" style="width: 140px;">${state.reactor.ventValve ? 'CLOSE VENT' : 'OPEN VENT'}</button>
        </div>
      `;
      document.getElementById('slide-feed').addEventListener('input', function (e) {
        state.reactor.feedRateCmd = parseFloat(e.target.value);
        document.getElementById('val-feed-rate').textContent = state.reactor.feedRateCmd + ' kg/h';
      });
      document.getElementById('slide-coolant').addEventListener('input', function (e) {
        state.reactor.coolantFlowCmd = parseFloat(e.target.value);
        document.getElementById('val-coolant-flow').textContent = state.reactor.coolantFlowCmd + ' m3/h';
      });
      document.getElementById('btn-vent').addEventListener('click', function () {
        state.reactor.ventValve = !state.reactor.ventValve;
        this.textContent = state.reactor.ventValve ? 'CLOSE VENT' : 'OPEN VENT';
        logSOE('REACTOR_VENT', 'Emergency vent valve commanded ' + (state.reactor.ventValve ? 'OPEN' : 'CLOSED'), state.reactor.ventValve);
      });

    } else if (state.currentPlant === 'rail') {
      dom.actuatorControls.innerHTML = `
        <div class="ctrl-row">
          <span class="ctrl-label">Turnout Point Alignment:</span>
          <span class="ctrl-val" id="val-point-align">${state.rail.pointPos === 0 ? 'NORMAL (MAIN)' : (state.rail.pointPos === 1 ? 'REVERSE (BRANCH)' : 'IN TRANSIT')}</span>
          <button id="btn-switch-point" class="btn-subtle" style="width: 140px;">SWITCH TURNOUT</button>
        </div>
        <div class="ctrl-row">
          <span class="ctrl-label">Home Interlocking Signal:</span>
          <span class="ctrl-val" style="color: ${state.rail.signalAspect === 'GREEN' ? '#10b981' : '#ef4444'}">${state.rail.signalAspect}</span>
          <span style="font-size: 10px; color: var(--text-dim);">AUTOMATIC BLOCK</span>
        </div>
      `;
      document.getElementById('btn-switch-point').addEventListener('click', function () {
        if (state.rail.tc2) {
          logSOE('RAIL_INTERLOCK_FAULT', 'Turnout switch command rejected: Track circuit TC2 occupied', 'INHIBITED');
          return;
        }
        state.rail.pointCmdRev = !state.rail.pointCmdRev;
        state.rail.pointTarget = state.rail.pointCmdRev ? 1 : 0;
        state.rail.pointPos = -1;
        state.rail.transitTimer = 0.0;
        logSOE('RAIL_POINT_MACHINE', 'Point motor commanded to ' + (state.rail.pointTarget === 1 ? 'REVERSE' : 'NORMAL'), 'IN_TRANSIT');
      });
    }
  }

  // --- ST Code Inspector View ---
  function updateCodeView() {
    if (state.currentPlant === 'crane') {
      dom.stCodeView.textContent =
`// Automated Gantry Crane Anti-Sway Cyclic Executive
VAR
  trolley_pos : REAL;
  sway_deg    : REAL;
  thrust_cmd  : REAL;
END_VAR

// Check physical safety envelopes
IF trolley_pos < 1.0 OR trolley_pos > 79.0 THEN
  thrust_cmd := 0.0;
  ALARM_LIMIT_BUFFER := TRUE;
ELSIF ABS(sway_deg) > 12.0 THEN
  // Engage non-linear sway damping counter-thrust
  thrust_cmd := -1.8 * sway_deg;
  ALARM_SWAY_HIGH := TRUE;
ELSE
  ALARM_SWAY_HIGH := FALSE;
END_IF;`;
    } else if (state.currentPlant === 'reactor') {
      dom.stCodeView.textContent =
`// CSTR Exothermic Runaway Protection Task
VAR
  reactor_temp : REAL;
  reactor_press: REAL;
  vent_valve   : BOOL;
END_VAR

// Overpressure safety trip
IF reactor_press >= 85.0 THEN
  vent_valve := TRUE; // Emergency dump
  ALARM_OVERPRESSURE := TRUE;
ELSIF reactor_temp > 80.0 THEN
  coolant_flow_cmd := 100.0; // Max jacket cooling
  ALARM_HIGHTEMP := TRUE;
END_IF;`;
    } else if (state.currentPlant === 'rail') {
      dom.stCodeView.textContent =
`// Railway Turnout Interlocking Safety Task
VAR
  tc2_occupied : BOOL;
  point_motor  : BOOL;
  signal_aspect: INT;
END_VAR

// Route interlocking mutually exclusive condition
IF tc2_occupied THEN
  point_motor := FALSE; // Inhibit motor switch
  signal_aspect := 1;   // RED aspect
ELSE
  signal_aspect := 3;   // GREEN aspect
END_IF;`;
    }
  }

  // --- Strip Chart Legend ---
  function updateChartLegend() {
    if (state.currentPlant === 'crane') {
      dom.chartLegend.innerHTML = `
        <span><span class="legend-dot" style="background: #38bdf8;"></span>Trolley Pos (m)</span>
        <span><span class="legend-dot" style="background: #f59e0b;"></span>Sway Angle (deg)</span>
      `;
    } else if (state.currentPlant === 'reactor') {
      dom.chartLegend.innerHTML = `
        <span><span class="legend-dot" style="background: #ef4444;"></span>Temp (degC)</span>
        <span><span class="legend-dot" style="background: #38bdf8;"></span>Pressure (bar)</span>
      `;
    } else if (state.currentPlant === 'rail') {
      dom.chartLegend.innerHTML = `
        <span><span class="legend-dot" style="background: #10b981;"></span>Train Pos (m/5)</span>
        <span><span class="legend-dot" style="background: #a855f7;"></span>Point State</span>
      `;
    }
  }

  // --- Physical Simulation Step ---
  function stepPhysics(dt) {
    state.simTimeSec += dt;
    state.cycleCount++;
    state.sdt.rawCount += 2;

    // Simulate microsecond scan jitter
    state.scanUs = Math.floor(40 + (Math.random() * 6));
    state.jitterUs = (2.8 + (Math.random() * 0.9)).toFixed(1);
    dom.scanUs.innerHTML = state.scanUs + ' &mu;s';
    dom.jitterUs.innerHTML = state.jitterUs + ' &mu;s';

    // 1. Crane Physics
    const c = state.crane;
    let thrust = c.trolleyForceCmd * 1000.0;
    if (state.estopActive) thrust = 0.0;

    // Check Cause and Effect Interlock Trips
    state.cem[0].tripped = Math.abs(c.swayAngle * 57.2958) > 15.0;
    if (state.cem[0].tripped) thrust = 0.0;

    const accel = (thrust - (1500.0 * c.trolleyVel)) / 25000.0;
    c.trolleyVel += accel * dt;
    c.trolleyPos += c.trolleyVel * dt;

    if (c.trolleyPos < 0.5) { c.trolleyPos = 0.5; c.trolleyVel = 0.0; c.westLs = true; }
    else { c.westLs = false; }
    if (c.trolleyPos > 79.5) { c.trolleyPos = 79.5; c.trolleyVel = 0.0; c.eastLs = true; }
    else { c.eastLs = false; }

    state.cem[1].tripped = c.westLs;

    c.hoistDepth += (state.estopActive ? 0.0 : c.hoistVelCmd) * dt;
    if (c.hoistDepth < 2.0) c.hoistDepth = 2.0;
    if (c.hoistDepth > 30.0) c.hoistDepth = 30.0;

    // Pendulum ODE
    const l = c.hoistDepth;
    const swayAcc = (- (9.80665 / l) * Math.sin(c.swayAngle)) - ((accel / l) * Math.cos(c.swayAngle)) - (0.05 * c.swayRate);
    c.swayRate += swayAcc * dt;
    c.swayAngle += c.swayRate * dt;

    // 2. Reactor Physics
    const r = state.reactor;
    let feed = state.estopActive ? 0.0 : r.feedRateCmd;
    let coolant = r.coolantFlowCmd;
    if (state.cem[3].tripped) feed = 0.0;

    const qRxn = feed * 0.15 * (1.0 + Math.pow(r.temp / 50.0, 2));
    const qCool = coolant * 0.8 * (r.temp - 20.0);
    const dtTemp = (qRxn - qCool) * 0.05;
    r.temp += dtTemp * dt;
    if (r.temp < 15.0) r.temp = 15.0;

    r.pressure = 1.0 + (Math.pow(r.temp / 100.0, 3) * 15.0);
    if (r.ventValve || state.cem[2].tripped) {
      r.pressure *= 0.4;
    }
    if (r.pressure >= 95.0) r.burstDiscBlown = true;
    if (r.burstDiscBlown) r.pressure = 1.5;

    state.cem[2].tripped = r.pressure >= 85.0;
    state.cem[3].tripped = r.temp >= 110.0;

    // 3. Rail Physics
    const rl = state.rail;
    rl.trainPos += 15.0 * dt;
    if (rl.trainPos > 500.0) rl.trainPos = 0.0;

    rl.tc1 = rl.trainPos < 100.0;
    rl.tc2 = rl.trainPos >= 100.0 && rl.trainPos < 200.0;
    rl.tc3 = rl.trainPos >= 200.0 && rl.pointPos === 0;

    state.cem[4].tripped = rl.tc2;

    if (rl.pointPos === -1) {
      rl.transitTimer += dt;
      if (rl.transitTimer >= 3.0) {
        rl.pointPos = rl.pointTarget;
      }
    }
    rl.signalAspect = rl.tc2 ? 'RED' : (rl.tc1 ? 'YELLOW' : 'GREEN');

    // 4. Update Alarm Conditions
    checkAlarms();

    // 5. Update SDT Compression
    if (state.cycleCount % 15 === 0) {
      state.sdt.archiveCount++;
    }
    dom.sdtRawCount.textContent = state.sdt.rawCount.toLocaleString() + ' pkts';
    dom.sdtArchiveCount.textContent = state.sdt.archiveCount.toLocaleString() + ' records';
  }

  // --- Alarm Check & Annunciator ---
  function checkAlarms() {
    const swayDeg = Math.abs(state.crane.swayAngle * 57.2958);
    updateAlarmState(0, swayDeg > 12.0);
    updateAlarmState(1, state.crane.trolleyPos < 2.0 || state.crane.trolleyPos > 78.0);
    updateAlarmState(2, state.reactor.temp > 80.0);
    updateAlarmState(3, state.reactor.pressure > 85.0);
    updateAlarmState(4, state.rail.tc2 && state.rail.pointPos === -1);
    renderAlarms();
  }

  function updateAlarmState(idx, isViolated) {
    const a = state.alarms[idx];
    if (isViolated) {
      if (a.state === 0) {
        a.state = 1; // NORMAL -> UNACK
        logSOE(a.tag, a.desc, 'TRIPPED (UNACK)');
      }
    } else {
      if (a.state === 1) {
        a.state = 3; // UNACK -> RTN_UNACK
      } else if (a.state === 2) {
        a.state = 0; // ACK -> NORMAL
        logSOE(a.tag, a.desc, 'RETURNED TO NORMAL');
      }
    }
  }

  function renderAlarms() {
    let unackCount = 0;
    let activeCount = 0;

    dom.alarmTiles.innerHTML = '';
    state.alarms.forEach(function (a) {
      const tile = document.createElement('div');
      tile.className = 'alarm-tile';
      let stateLabel = 'NORMAL';

      if (a.state === 1) {
        tile.classList.add('state-unack');
        stateLabel = 'UNACK ALARM';
        unackCount++;
        activeCount++;
      } else if (a.state === 2) {
        tile.classList.add('state-ack');
        stateLabel = 'ACKNOWLEDGED';
        activeCount++;
      } else if (a.state === 3) {
        tile.classList.add('state-unack');
        stateLabel = 'RTN UNACK';
        unackCount++;
      }

      tile.innerHTML = `
        <span class="tile-tag">${a.tag}</span>
        <span class="tile-state">${stateLabel}</span>
      `;
      dom.alarmTiles.appendChild(tile);
    });

    if (activeCount > 0 || unackCount > 0) {
      dom.alarmBanner.classList.add('active-alarm');
      dom.alarmSummaryText.textContent = `${activeCount} ACTIVE ALARMS (${unackCount} UNACKNOWLEDGED)`;
    } else {
      dom.alarmBanner.classList.remove('active-alarm');
      dom.alarmSummaryText.textContent = '0 ACTIVE ALARMS: SYSTEM NORMAL';
    }
  }

  // --- Render Cause and Effect Matrix ---
  function renderCEM() {
    dom.cemBody.innerHTML = '';
    let anyTripped = false;

    state.cem.forEach(function (r) {
      if (r.plant === state.currentPlant) {
        const tr = document.createElement('tr');
        if (r.tripped) {
          tr.classList.add('tripped');
          anyTripped = true;
        }
        tr.innerHTML = `
          <td><strong>${r.id}</strong></td>
          <td>${r.cause}</td>
          <td>${r.condition}</td>
          <td>${r.effect}</td>
          <td>${r.failSafe}</td>
          <td><span class="badge sil4">${r.sil}</span></td>
          <td>${r.tripped ? '<span style="color: #ef4444;">TRIPPED</span>' : '<span style="color: #10b981;">ARMED</span>'}</td>
        `;
        dom.cemBody.appendChild(tr);
      }
    });

    dom.interlockStatus.className = anyTripped ? 'status-indicator tripped' : 'status-indicator normal';
    dom.interlockStatus.textContent = anyTripped ? 'SAFETY INTERLOCK TRIPPED' : 'ALL INTERLOCKS HEALTHY';
  }

  // --- Render SVG Plant Visualizer ---
  function renderSVG() {
    if (state.currentPlant === 'crane') {
      const c = state.crane;
      const trolleyX = 40 + (c.trolleyPos / 80.0) * 300;
      const hoistY = 55 + (c.hoistDepth / 35.0) * 110;
      const swayRad = c.swayAngle;
      const spreaderX = trolleyX + Math.sin(swayRad) * (hoistY - 55);
      const spreaderY = 55 + Math.cos(swayRad) * (hoistY - 55);

      dom.svgViewport.innerHTML = `
        <svg viewBox="0 0 400 240">
          <!-- Sky / Background -->
          <rect x="0" y="0" width="400" height="240" fill="#070c14"/>
          <!-- Wharf Quay -->
          <rect x="0" y="200" width="400" height="40" fill="#1e293b"/>
          <line x1="0" y1="200" x2="400" y2="200" stroke="#334155" stroke-width="2"/>

          <!-- Crane Framework -->
          <line x1="40" y1="200" x2="70" y2="50" stroke="#475569" stroke-width="6"/>
          <line x1="360" y1="200" x2="330" y2="50" stroke="#475569" stroke-width="6"/>
          <!-- Horizontal Boom Rail -->
          <rect x="30" y="45" width="340" height="10" fill="#334155" stroke="#64748b" stroke-width="1"/>

          <!-- Limit Switches -->
          <circle cx="45" cy="50" r="4" fill="${c.westLs ? '#ef4444' : '#10b981'}"/>
          <circle cx="355" cy="50" r="4" fill="${c.eastLs ? '#ef4444' : '#10b981'}"/>

          <!-- Trolley Carriage -->
          <rect x="${trolleyX - 15}" y="42" width="30" height="14" fill="#38bdf8" rx="2"/>

          <!-- Hoist Cable -->
          <line x1="${trolleyX}" y1="55" x2="${spreaderX}" y2="${spreaderY}" stroke="#94a3b8" stroke-width="2"/>

          <!-- Spreader & Container -->
          <g transform="translate(${spreaderX}, ${spreaderY}) rotate(${swayRad * 57.2958})">
            <!-- Spreader bar -->
            <rect x="-20" y="0" width="40" height="5" fill="#f59e0b"/>
            <!-- 40ft Shipping Container -->
            <rect x="-24" y="5" width="48" height="26" fill="#0284c7" stroke="#38bdf8" stroke-width="1.5" rx="1"/>
            <text x="0" y="21" font-size="7" font-weight="bold" fill="#ffffff" text-anchor="middle">GANTRY-40</text>
          </g>

          <text x="15" y="225" font-size="10" fill="#64748b" font-family="monospace">RAIL: 80m | BUFFER TO BUFFER</text>
        </svg>
      `;

    } else if (state.currentPlant === 'reactor') {
      const r = state.reactor;
      const fillHeight = 60 + Math.min(80, (r.temp / 150.0) * 80);
      const isBlown = r.burstDiscBlown;

      dom.svgViewport.innerHTML = `
        <svg viewBox="0 0 400 240">
          <rect x="0" y="0" width="400" height="240" fill="#070c14"/>

          <!-- Reactor Jacket -->
          <path d="M 120 40 L 120 180 C 120 210, 280 210, 280 180 L 280 40 Z" fill="#1e293b" stroke="#475569" stroke-width="4"/>

          <!-- Core Fluid with Heat Gradient -->
          <path d="M 130 90 L 130 180 C 130 200, 270 200, 270 180 L 270 90 Z" fill="${r.temp > 80.0 ? '#ef4444' : '#0284c7'}" opacity="0.8"/>

          <!-- Agitator Impeller Shaft -->
          <line x1="200" y1="20" x2="200" y2="160" stroke="#94a3b8" stroke-width="4"/>
          <line x1="170" y1="160" x2="230" y2="160" stroke="#f59e0b" stroke-width="4"/>
          <!-- Drive Motor -->
          <rect x="185" y="10" width="30" height="20" fill="#334155" stroke="#38bdf8" rx="2"/>

          <!-- Relief Valve / Rupture Disc Assembly -->
          <line x1="260" y1="50" x2="310" y2="50" stroke="#94a3b8" stroke-width="4"/>
          <circle cx="310" cy="50" r="8" fill="${isBlown ? '#ef4444' : (r.ventValve ? '#f59e0b' : '#10b981')}"/>
          <text x="325" y="53" font-size="9" fill="#94a3b8" font-family="monospace">${isBlown ? 'BURST DISC BLOWN' : (r.ventValve ? 'VENT OPEN' : 'ARMED')}</text>

          <!-- Digital Readouts -->
          <rect x="20" y="30" width="90" height="46" fill="#0f172a" stroke="#334155" rx="4"/>
          <text x="26" y="46" font-size="9" fill="#64748b" font-family="monospace">CORE TEMP</text>
          <text x="26" y="66" font-size="14" font-weight="bold" fill="${r.temp > 80.0 ? '#ef4444' : '#38bdf8'}" font-family="monospace">${r.temp.toFixed(1)} &deg;C</text>

          <rect x="20" y="85" width="90" height="46" fill="#0f172a" stroke="#334155" rx="4"/>
          <text x="26" y="101" font-size="9" fill="#64748b" font-family="monospace">PRESSURE</text>
          <text x="26" y="121" font-size="14" font-weight="bold" fill="${r.pressure > 85.0 ? '#ef4444' : '#10b981'}" font-family="monospace">${r.pressure.toFixed(1)} bar</text>
        </svg>
      `;

    } else if (state.currentPlant === 'rail') {
      const rl = state.rail;
      const trainX = 20 + (rl.trainPos / 500.0) * 340;
      const isReverse = rl.pointPos === 1;

      dom.svgViewport.innerHTML = `
        <svg viewBox="0 0 400 240">
          <rect x="0" y="0" width="400" height="240" fill="#070c14"/>

          <!-- Track Blocks -->
          <!-- Approach Block (TC1) -->
          <line x1="20" y1="120" x2="140" y2="120" stroke="${rl.tc1 ? '#ef4444' : '#475569'}" stroke-width="5"/>
          <text x="60" y="105" font-size="8" fill="#64748b" font-family="monospace">TC1: APPROACH</text>

          <!-- Turnout Block (TC2) -->
          <line x1="140" y1="120" x2="240" y2="120" stroke="${rl.tc2 ? '#ef4444' : '#475569'}" stroke-width="5"/>
          <text x="170" y="105" font-size="8" fill="#64748b" font-family="monospace">TC2: TURNOUT</text>

          <!-- Main Departure (TC3) -->
          <line x1="240" y1="120" x2="380" y2="120" stroke="${rl.tc3 ? '#ef4444' : '#475569'}" stroke-width="5"/>
          <text x="290" y="105" font-size="8" fill="#64748b" font-family="monospace">TC3: MAIN</text>

          <!-- Branch Turnout Departure -->
          <path d="M 200 120 C 230 120, 260 160, 380 160" stroke="#334155" stroke-width="5" fill="none"/>
          <text x="290" y="180" font-size="8" fill="#64748b" font-family="monospace">BRANCHLINE</text>

          <!-- Switch Blade Visualizer -->
          <line x1="200" y1="120" x2="225" y2="${isReverse ? 132 : 120}" stroke="#f59e0b" stroke-width="4"/>

          <!-- Home Signal Head -->
          <circle cx="135" cy="80" r="6" fill="${rl.signalAspect === 'RED' ? '#ef4444' : '#1e293b'}"/>
          <circle cx="135" cy="65" r="6" fill="${rl.signalAspect === 'YELLOW' ? '#f59e0b' : '#1e293b'}"/>
          <circle cx="135" cy="50" r="6" fill="${rl.signalAspect === 'GREEN' ? '#10b981' : '#1e293b'}"/>
          <line x1="135" y1="86" x2="135" y2="120" stroke="#94a3b8" stroke-width="2"/>

          <!-- Moving Train Consist -->
          <rect x="${trainX - 16}" y="112" width="32" height="16" fill="#38bdf8" rx="2"/>
          <text x="${trainX}" y="124" font-size="8" font-weight="bold" fill="#000" text-anchor="middle">TR-1</text>
        </svg>
      `;
    }
  }

  // --- Render Oscilloscope Strip Chart ---
  function renderChart() {
    const canvas = dom.stripChart;
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;

    ctx.fillStyle = '#06090e';
    ctx.fillRect(0, 0, w, h);

    // Draw Gridlines
    ctx.strokeStyle = '#1a2233';
    ctx.lineWidth = 1;
    for (let x = 0; x < w; x += 50) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, h);
      ctx.stroke();
    }
    for (let y = 0; y < h; y += 30) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    // Push new data points into history
    let v1 = 0, v2 = 0;
    if (state.currentPlant === 'crane') {
      v1 = state.crane.trolleyPos; // 0..80
      v2 = (state.crane.swayAngle * 57.2958) + 40; // centered at 40
    } else if (state.currentPlant === 'reactor') {
      v1 = state.reactor.temp; // 0..150
      v2 = state.reactor.pressure; // 0..150
    } else if (state.currentPlant === 'rail') {
      v1 = state.rail.trainPos / 5.0; // 0..100
      v2 = (state.rail.pointPos + 1) * 30; // 0, 30, 60
    }

    chartHistory.series1.push(v1);
    chartHistory.series2.push(v2);
    if (chartHistory.series1.length > MAX_CHART_POINTS) {
      chartHistory.series1.shift();
      chartHistory.series2.shift();
    }

    const n = chartHistory.series1.length;
    if (n < 2) return;

    // Draw Series 1
    ctx.strokeStyle = state.currentPlant === 'reactor' ? '#ef4444' : (state.currentPlant === 'rail' ? '#10b981' : '#38bdf8');
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const x = (i / MAX_CHART_POINTS) * w;
      const y = h - (chartHistory.series1[i] / 100.0) * h;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // Draw Series 2
    ctx.strokeStyle = state.currentPlant === 'reactor' ? '#38bdf8' : (state.currentPlant === 'rail' ? '#a855f7' : '#f59e0b');
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const x = (i / MAX_CHART_POINTS) * w;
      const y = h - (chartHistory.series2[i] / 100.0) * h;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }

  // --- Main Animation & Simulation Loop ---
  let lastTime = performance.now();

  function loop(now) {
    const dt = Math.min(0.1, (now - lastTime) / 1000.0);
    lastTime = now;

    stepPhysics(dt);
    renderSVG();
    renderCEM();
    renderChart();

    requestAnimationFrame(loop);
  }

  // --- Initialization ---
  renderActuatorControls();
  updateCodeView();
  updateChartLegend();
  renderAlarms();
  logSOE('SYS_BOOT', 'Gantry high-assurance cyclic executive runtime initialized', 'OK');

  requestAnimationFrame(loop);

})();
