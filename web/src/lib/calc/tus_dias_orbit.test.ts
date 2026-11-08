import { describe, it, expect } from 'vitest';
import {
  createInitialOrbitState,
  stepOrbitPhysics,
  applyDragMove,
  applyZoom,
  isClickGesture,
  isOrbitModified,
  recenterOrbitTarget,
  DEFAULT_ORBIT_CONFIG,
  type TusDiasOrbitState,
} from './tus_dias_orbit';

describe('tus_dias_orbit', () => {
  it('la inercia decae a 0', () => {
    let state: TusDiasOrbitState = {
      ...createInitialOrbitState(),
      yawVelocity: 3.5, // initial spin
    };

    // Step physics forward in small frames (e.g. 16ms)
    for (let i = 0; i < 120; i++) {
      state = stepOrbitPhysics(state, 0.016);
    }

    // Velocity should smoothly decay to exactly 0
    expect(state.yawVelocity).toBe(0);
    // Yaw should have advanced during inertia
    expect(state.yaw).toBeGreaterThan(0);
  });

  it('la inclinación respeta los límites con rebote', () => {
    // 1. Below minimum pitch (< 25°)
    let belowState: TusDiasOrbitState = {
      ...createInitialOrbitState(),
      pitch: DEFAULT_ORBIT_CONFIG.minPitch - 0.15, // displaced beyond lower limit
      pitchVelocity: 0,
    };

    // Physics step should spring back up towards minPitch
    for (let i = 0; i < 90; i++) {
      belowState = stepOrbitPhysics(belowState, 0.016);
    }

    expect(belowState.pitch).toBeCloseTo(DEFAULT_ORBIT_CONFIG.minPitch, 2);
    expect(belowState.pitch).toBeGreaterThanOrEqual(DEFAULT_ORBIT_CONFIG.minPitch - 0.005);

    // 2. Above maximum pitch (> 80°)
    let aboveState: TusDiasOrbitState = {
      ...createInitialOrbitState(),
      pitch: DEFAULT_ORBIT_CONFIG.maxPitch + 0.15, // displaced beyond upper limit
      pitchVelocity: 0,
    };

    // Physics step should spring back down towards maxPitch
    for (let i = 0; i < 90; i++) {
      aboveState = stepOrbitPhysics(aboveState, 0.016);
    }

    expect(aboveState.pitch).toBeCloseTo(DEFAULT_ORBIT_CONFIG.maxPitch, 2);
    expect(aboveState.pitch).toBeLessThanOrEqual(DEFAULT_ORBIT_CONFIG.maxPitch + 0.005);
  });

  it('el zoom respeta los límites', () => {
    // 1. Below minZoom (0.6)
    let tooSmallZoom: TusDiasOrbitState = {
      ...createInitialOrbitState(),
      zoom: 0.4,
      zoomVelocity: 0,
    };

    for (let i = 0; i < 90; i++) {
      tooSmallZoom = stepOrbitPhysics(tooSmallZoom, 0.016);
    }

    expect(tooSmallZoom.zoom).toBeCloseTo(DEFAULT_ORBIT_CONFIG.minZoom, 2);
    expect(tooSmallZoom.zoom).toBeGreaterThanOrEqual(DEFAULT_ORBIT_CONFIG.minZoom - 0.01);

    // 2. Above maxZoom (2.5)
    let tooLargeZoom: TusDiasOrbitState = {
      ...createInitialOrbitState(),
      zoom: 3.2,
      zoomVelocity: 0,
    };

    for (let i = 0; i < 90; i++) {
      tooLargeZoom = stepOrbitPhysics(tooLargeZoom, 0.016);
    }

    expect(tooLargeZoom.zoom).toBeCloseTo(DEFAULT_ORBIT_CONFIG.maxZoom, 2);
    expect(tooLargeZoom.zoom).toBeLessThanOrEqual(DEFAULT_ORBIT_CONFIG.maxZoom + 0.01);
  });

  it('un movimiento menor a 5 px cuenta como clic', () => {
    const origin = { x: 100, y: 100 };

    // 0 px move: click
    expect(isClickGesture(origin, { x: 100, y: 100 })).toBe(true);

    // 3 px move: click
    expect(isClickGesture(origin, { x: 103, y: 100 })).toBe(true);

    // 4.9 px move: click (hypot(3, 3) = 4.24 px)
    expect(isClickGesture(origin, { x: 103, y: 103 })).toBe(true);

    // 5.0 px move: click
    expect(isClickGesture(origin, { x: 105, y: 100 })).toBe(true);

    // 5.1 px move: NOT a click (it is a drag)
    expect(isClickGesture(origin, { x: 105.1, y: 100 })).toBe(false);

    // 20 px move: NOT a click
    expect(isClickGesture(origin, { x: 115, y: 115 })).toBe(false);
  });

  it('applyDragMove aplica resistencia elástica fuera de límites de pitch', () => {
    const initial = createInitialOrbitState();
    // Regular move inside bounds
    const movedNormal = applyDragMove(initial, 10, -10);
    expect(movedNormal.yaw).not.toBe(initial.yaw);
    expect(movedNormal.pitch).not.toBe(initial.pitch);

    // Moving beyond max pitch has increased resistance (dragging up increases pitch)
    const atMax = { ...initial, pitch: DEFAULT_ORBIT_CONFIG.maxPitch };
    const movedBeyond = applyDragMove(atMax, 0, -50);
    // It should allow slight overscroll with resistance, but much less than linear
    expect(movedBeyond.pitch).toBeGreaterThan(DEFAULT_ORBIT_CONFIG.maxPitch);
    expect(movedBeyond.pitch - DEFAULT_ORBIT_CONFIG.maxPitch).toBeLessThan(0.3);
  });

  it('isOrbitModified detecta cuando la cámara cambió respecto a la inicial', () => {
    const initial = createInitialOrbitState();
    expect(isOrbitModified(initial)).toBe(false);

    const rotated = { ...initial, yaw: 0.2 };
    expect(isOrbitModified(rotated)).toBe(true);

    const tilted = { ...initial, pitch: initial.pitch + 0.1 };
    expect(isOrbitModified(tilted)).toBe(true);

    const zoomed = { ...initial, zoom: 1.5 };
    expect(isOrbitModified(zoomed)).toBe(true);
  });

  it('recenterOrbitTarget devuelve el estado en reposo hacia los valores iniciales', () => {
    const modified: TusDiasOrbitState = {
      yaw: 1.5,
      pitch: 1.2,
      zoom: 2.0,
      yawVelocity: 2.0,
      pitchVelocity: 0.5,
      zoomVelocity: 0.1,
    };

    const recentered = recenterOrbitTarget(modified);
    expect(recentered.targetYaw).toBe(0);
    expect(recentered.targetPitch).toBe(DEFAULT_ORBIT_CONFIG.defaultPitch);
    expect(recentered.targetZoom).toBe(1.0);
  });

  it('recenters smoothly with spring physics until settled at default values', () => {
    let state = createInitialOrbitState({
      yaw: 1.5,
      pitch: 1.2,
      zoom: 1.8,
      isRecentering: true,
    });

    for (let i = 0; i < 90; i++) {
      state = stepOrbitPhysics(state, 1 / 60);
    }

    expect(state.isRecentering).toBe(false);
    expect(state.yaw).toBeCloseTo(DEFAULT_ORBIT_CONFIG.defaultYaw, 2);
    expect(state.pitch).toBeCloseTo(DEFAULT_ORBIT_CONFIG.defaultPitch, 2);
    expect(state.zoom).toBeCloseTo(DEFAULT_ORBIT_CONFIG.defaultZoom, 2);
  });
});
