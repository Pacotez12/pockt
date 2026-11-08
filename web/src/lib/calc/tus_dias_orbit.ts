/**
 * Pure orbit physics and state management for Tus Días 3D Camera.
 *
 * Implements:
 * - 360° unconstrained horizontal rotation with smooth inertia decay and instant stop on grab.
 * - Vertical pitch / elevation bounded between 25° and 80° with Apple-style rubber-band spring rebound.
 * - Zoom bounded between 0.6x and 2.5x with spring rebound.
 * - Pure click vs drag discriminator (<= 5px threshold).
 * - Recentering and modified-state detection.
 */

export interface TusDiasOrbitState {
  yaw: number; // Azimuth angle in radians (continuous 360°)
  pitch: number; // Elevation angle in radians (~25° to 80°)
  zoom: number; // Scale multiplier (0.6x to 2.5x)
  yawVelocity: number; // Angular velocity (rad/s) for inertia
  pitchVelocity: number; // Velocity (rad/s) for spring rebound
  zoomVelocity: number; // Scale/s velocity for spring rebound
  isRecentering?: boolean; // When true, animates back to default with spring
}

export interface OrbitConfig {
  minPitch: number; // 25° in radians
  maxPitch: number; // 80° in radians
  defaultPitch: number; // ~36° in radians
  defaultYaw: number;
  defaultZoom: number;
  minZoom: number;
  maxZoom: number;
  clickThreshold: number; // 5 px
  yawFriction: number;
  springStiffness: number;
  springDamping: number;
}

export const DEFAULT_ORBIT_CONFIG: OrbitConfig = {
  minPitch: (25 * Math.PI) / 180, // ~0.43633 rad
  maxPitch: (80 * Math.PI) / 180, // ~1.39626 rad
  defaultPitch: (35.6 * Math.PI) / 180, // ~0.62134 rad (matches initial view)
  defaultYaw: 0,
  defaultZoom: 1.0,
  minZoom: 0.6,
  maxZoom: 2.5,
  clickThreshold: 5,
  yawFriction: 2.8, // Smooth physical decay
  springStiffness: 140, // Responsive Apple-style rebound
  springDamping: 20, // Critical damping without excessive bounce
};

export function createInitialOrbitState(
  overrides?: Partial<TusDiasOrbitState>,
  config: OrbitConfig = DEFAULT_ORBIT_CONFIG
): TusDiasOrbitState {
  return {
    yaw: config.defaultYaw,
    pitch: config.defaultPitch,
    zoom: config.defaultZoom,
    yawVelocity: 0,
    pitchVelocity: 0,
    zoomVelocity: 0,
    isRecentering: false,
    ...overrides,
  };
}

/**
 * Applies horizontal drag (yaw) and vertical drag (pitch) with rubberband resistance at limits.
 */
export function applyDragMove(
  state: TusDiasOrbitState,
  dx: number,
  dy: number,
  options: {
    sensitivityX?: number;
    sensitivityY?: number;
    config?: OrbitConfig;
  } = {}
): TusDiasOrbitState {
  const config = options.config ?? DEFAULT_ORBIT_CONFIG;
  const sensX = options.sensitivityX ?? 0.006;
  const sensY = options.sensitivityY ?? 0.005;

  const newYaw = state.yaw + dx * sensX;

  // Vertical movement: dragging up increases elevation (higher bird's-eye view)
  let deltaPitch = -dy * sensY;

  // Apply rubberband resistance if already outside limits
  if (state.pitch < config.minPitch && deltaPitch < 0) {
    const overscroll = config.minPitch - state.pitch;
    deltaPitch *= 1 / (1 + overscroll * 8);
  } else if (state.pitch > config.maxPitch && deltaPitch > 0) {
    const overscroll = state.pitch - config.maxPitch;
    deltaPitch *= 1 / (1 + overscroll * 8);
  }

  const newPitch = state.pitch + deltaPitch;

  return {
    ...state,
    yaw: newYaw,
    pitch: newPitch,
  };
}

/**
 * Applies pinch or wheel zoom with rubberband resistance.
 */
export function applyZoom(
  state: TusDiasOrbitState,
  factor: number,
  config: OrbitConfig = DEFAULT_ORBIT_CONFIG
): TusDiasOrbitState {
  let target = state.zoom * factor;

  if (target < config.minZoom) {
    const over = config.minZoom - target;
    target = config.minZoom - over / (1 + over * 4);
  } else if (target > config.maxZoom) {
    const over = target - config.maxZoom;
    target = config.maxZoom + over / (1 + over * 4);
  }

  return {
    ...state,
    zoom: target,
  };
}

/**
 * Advances orbit physics by dt seconds:
 * - Decays yaw inertia
 * - Rebounds pitch and zoom to their limits using critically damped springs
 */
export function stepOrbitPhysics(
  state: TusDiasOrbitState,
  dt: number,
  options: {
    reduceMotion?: boolean;
    config?: OrbitConfig;
  } = {}
): TusDiasOrbitState {
  const config = options.config ?? DEFAULT_ORBIT_CONFIG;
  const reduceMotion = options.reduceMotion ?? false;

  if (reduceMotion) {
    return {
      yaw: state.isRecentering ? config.defaultYaw : state.yaw,
      pitch: state.isRecentering
        ? config.defaultPitch
        : Math.max(config.minPitch, Math.min(config.maxPitch, state.pitch)),
      zoom: state.isRecentering
        ? config.defaultZoom
        : Math.max(config.minZoom, Math.min(config.maxZoom, state.zoom)),
      yawVelocity: 0,
      pitchVelocity: 0,
      zoomVelocity: 0,
      isRecentering: false,
    };
  }

  const clampedDt = Math.min(0.05, Math.max(0.001, dt));

  // 0. Smooth Spring Recentering
  if (state.isRecentering) {
    let nextYaw = state.yaw;
    let nextYawVel = state.yawVelocity;
    const dYaw = nextYaw - config.defaultYaw;
    const fYaw = -config.springStiffness * dYaw - config.springDamping * nextYawVel;
    nextYawVel += fYaw * clampedDt;
    nextYaw += nextYawVel * clampedDt;

    let nextPitch = state.pitch;
    let nextPitchVel = state.pitchVelocity;
    const dPitch = nextPitch - config.defaultPitch;
    const fPitch = -config.springStiffness * dPitch - config.springDamping * nextPitchVel;
    nextPitchVel += fPitch * clampedDt;
    nextPitch += nextPitchVel * clampedDt;

    let nextZoom = state.zoom;
    let nextZoomVel = state.zoomVelocity;
    const dZoom = nextZoom - config.defaultZoom;
    const fZoom = -config.springStiffness * dZoom - config.springDamping * nextZoomVel;
    nextZoomVel += fZoom * clampedDt;
    nextZoom += nextZoomVel * clampedDt;

    const settled =
      Math.abs(dYaw) < 0.003 &&
      Math.abs(nextYawVel) < 0.02 &&
      Math.abs(dPitch) < 0.003 &&
      Math.abs(nextPitchVel) < 0.02 &&
      Math.abs(dZoom) < 0.003 &&
      Math.abs(nextZoomVel) < 0.02;

    if (settled) {
      return {
        yaw: config.defaultYaw,
        pitch: config.defaultPitch,
        zoom: config.defaultZoom,
        yawVelocity: 0,
        pitchVelocity: 0,
        zoomVelocity: 0,
        isRecentering: false,
      };
    }

    return {
      yaw: nextYaw,
      pitch: nextPitch,
      zoom: nextZoom,
      yawVelocity: nextYawVel,
      pitchVelocity: nextPitchVel,
      zoomVelocity: nextZoomVel,
      isRecentering: true,
    };
  }

  // 1. Horizontal Yaw Inertia
  let nextYaw = state.yaw + state.yawVelocity * clampedDt;
  let nextYawVel = state.yawVelocity * Math.exp(-config.yawFriction * clampedDt);
  if (Math.abs(nextYawVel) < 0.02) {
    nextYawVel = 0;
  }

  // 2. Vertical Pitch Rubberband Rebound
  let nextPitch = state.pitch;
  let nextPitchVel = state.pitchVelocity;

  if (nextPitch < config.minPitch) {
    const displacement = nextPitch - config.minPitch;
    const force =
      -config.springStiffness * displacement - config.springDamping * nextPitchVel;
    nextPitchVel += force * clampedDt;
    nextPitch += nextPitchVel * clampedDt;
    if (Math.abs(nextPitch - config.minPitch) < 0.001 && Math.abs(nextPitchVel) < 0.01) {
      nextPitch = config.minPitch;
      nextPitchVel = 0;
    }
  } else if (nextPitch > config.maxPitch) {
    const displacement = nextPitch - config.maxPitch;
    const force =
      -config.springStiffness * displacement - config.springDamping * nextPitchVel;
    nextPitchVel += force * clampedDt;
    nextPitch += nextPitchVel * clampedDt;
    if (Math.abs(nextPitch - config.maxPitch) < 0.001 && Math.abs(nextPitchVel) < 0.01) {
      nextPitch = config.maxPitch;
      nextPitchVel = 0;
    }
  } else {
    // In-bounds velocity damping
    nextPitchVel *= Math.exp(-config.yawFriction * clampedDt * 3);
    if (Math.abs(nextPitchVel) < 0.002) nextPitchVel = 0;
  }

  // 3. Zoom Spring Rebound
  let nextZoom = state.zoom;
  let nextZoomVel = state.zoomVelocity;

  if (nextZoom < config.minZoom) {
    const displacement = nextZoom - config.minZoom;
    const force =
      -config.springStiffness * displacement - config.springDamping * nextZoomVel;
    nextZoomVel += force * clampedDt;
    nextZoom += nextZoomVel * clampedDt;
    if (Math.abs(nextZoom - config.minZoom) < 0.001 && Math.abs(nextZoomVel) < 0.01) {
      nextZoom = config.minZoom;
      nextZoomVel = 0;
    }
  } else if (nextZoom > config.maxZoom) {
    const displacement = nextZoom - config.maxZoom;
    const force =
      -config.springStiffness * displacement - config.springDamping * nextZoomVel;
    nextZoomVel += force * clampedDt;
    nextZoom += nextZoomVel * clampedDt;
    if (Math.abs(nextZoom - config.maxZoom) < 0.001 && Math.abs(nextZoomVel) < 0.01) {
      nextZoom = config.maxZoom;
      nextZoomVel = 0;
    }
  } else {
    nextZoomVel *= Math.exp(-config.yawFriction * clampedDt * 3);
    if (Math.abs(nextZoomVel) < 0.002) nextZoomVel = 0;
  }

  return {
    yaw: nextYaw,
    pitch: nextPitch,
    zoom: nextZoom,
    yawVelocity: nextYawVel,
    pitchVelocity: nextPitchVel,
    zoomVelocity: nextZoomVel,
    isRecentering: false,
  };
}

/**
 * Returns true if total pointer displacement is <= threshold (counts as click, not drag).
 */
export function isClickGesture(
  startPos: { x: number; y: number },
  endPos: { x: number; y: number },
  threshold: number = DEFAULT_ORBIT_CONFIG.clickThreshold
): boolean {
  return Math.hypot(endPos.x - startPos.x, endPos.y - startPos.y) <= threshold;
}

/**
 * Detects if current orbit differs from default (to display Recentrar button).
 */
export function isOrbitModified(
  state: TusDiasOrbitState,
  tolerance: number = 0.02,
  config: OrbitConfig = DEFAULT_ORBIT_CONFIG
): boolean {
  const yawDiff = Math.abs(state.yaw - config.defaultYaw);
  const pitchDiff = Math.abs(state.pitch - config.defaultPitch);
  const zoomDiff = Math.abs(state.zoom - config.defaultZoom);

  return yawDiff > tolerance || pitchDiff > tolerance || zoomDiff > tolerance;
}

/**
 * Target values to spring back to when recentering.
 */
export function recenterOrbitTarget(
  _state: TusDiasOrbitState,
  config: OrbitConfig = DEFAULT_ORBIT_CONFIG
): { targetYaw: number; targetPitch: number; targetZoom: number } {
  return {
    targetYaw: config.defaultYaw,
    targetPitch: config.defaultPitch,
    targetZoom: config.defaultZoom,
  };
}
