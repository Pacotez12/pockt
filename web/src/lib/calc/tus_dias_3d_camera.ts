import * as THREE from 'three';

export interface TusDiasCameraFramingInput {
  weeks: number;
  days?: number;
  maxHeight: number;
  canvasWidth: number;
  canvasHeight: number;
  k: number; // 0 = 2D, 1 = 3D
  yaw?: number;
  pitch?: number; // Elevation in radians (default ~35.6°: Math.PI / 2 - 0.95)
  zoom?: number; // Zoom factor (default 1)
  cellSize?: number;
  coverage?: number; // default 0.85 (85% coverage of canvas)
}

export interface TusDiasCameraFramingResult {
  left: number;
  right: number;
  top: number;
  bottom: number;
  camPosition: { x: number; y: number; z: number };
  camTarget: { x: number; y: number; z: number };
  boxWidthCam: number;
  boxHeightCam: number;
  centerXCam: number;
  centerYCam: number;
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/**
 * Computes optimal orthographic camera bounds (left, right, top, bottom)
 * and camera position/lookAt by projecting the 3D bounding box corners
 * of the Tus Días grid and tallest bar into camera space.
 *
 * Guarantees that the scene occupies ~85% of the viewport with balanced margins,
 * adapting smoothly to both 8-week and 26-week datasets and through 2D<->3D transitions.
 */
export function computeTusDiasCameraFraming({
  weeks,
  days = 7,
  maxHeight,
  canvasWidth,
  canvasHeight,
  k,
  yaw = 0,
  pitch,
  zoom = 1,
  cellSize = 0.85,
  coverage = 0.85,
}: TusDiasCameraFramingInput): TusDiasCameraFramingResult {
  const W = Math.max(1, weeks);
  const D = Math.max(1, days);

  // Camera orientation matching TusDias.tsx
  const targetTilt = pitch !== undefined ? Math.PI / 2 - pitch : 0.95;
  const tilt = lerp(0.001, targetTilt, k);
  const az = lerp(0, -0.72, k) + yaw * k;
  const r = 60;

  const camPosition =
    k < 0.002
      ? { x: 0, y: 60, z: 0.001 }
      : {
          x: Math.sin(az) * Math.cos(Math.PI / 2 - tilt) * r,
          y: Math.sin(Math.PI / 2 - tilt) * r,
          z: Math.cos(az) * Math.cos(Math.PI / 2 - tilt) * r,
        };

  const camTarget = {
    x: 0,
    y: lerp(0, 1.2, k),
    z: 0,
  };

  const camera = new THREE.OrthographicCamera();
  camera.position.set(camPosition.x, camPosition.y, camPosition.z);
  camera.up.set(0, 1, 0);
  camera.lookAt(camTarget.x, camTarget.y, camTarget.z);
  camera.updateMatrixWorld(true);

  // Real bounding box of grid + tallest bar
  const minX = -(W - 1) / 2 - cellSize / 2;
  const maxX = (W - 1) / 2 + cellSize / 2;
  const minZ = -(D - 1) / 2 - cellSize / 2;
  const maxZ = (D - 1) / 2 + cellSize / 2;
  const minY = 0;
  const maxY = Math.max(0.12, maxHeight);

  const corners = [
    new THREE.Vector3(minX, minY, minZ),
    new THREE.Vector3(maxX, minY, minZ),
    new THREE.Vector3(minX, minY, maxZ),
    new THREE.Vector3(maxX, minY, maxZ),
    new THREE.Vector3(minX, maxY, minZ),
    new THREE.Vector3(maxX, maxY, minZ),
    new THREE.Vector3(minX, maxY, maxZ),
    new THREE.Vector3(maxX, maxY, maxZ),
  ];

  let minXCam = Infinity;
  let maxXCam = -Infinity;
  let minYCam = Infinity;
  let maxYCam = -Infinity;

  for (const c of corners) {
    c.applyMatrix4(camera.matrixWorldInverse);
    if (c.x < minXCam) minXCam = c.x;
    if (c.x > maxXCam) maxXCam = c.x;
    if (c.y < minYCam) minYCam = c.y;
    if (c.y > maxYCam) maxYCam = c.y;
  }

  const boxWidthCam = maxXCam - minXCam;
  const boxHeightCam = maxYCam - minYCam;
  const centerXCam = (minXCam + maxXCam) / 2;
  const centerYCam = (minYCam + maxYCam) / 2;

  const canvasAspect = canvasWidth / Math.max(1, canvasHeight);
  const halfWNeeded = (boxWidthCam / 2) / coverage;
  const halfHNeeded = (boxHeightCam / 2) / coverage;

  let halfW: number;
  let halfH: number;

  if (halfWNeeded / canvasAspect >= halfHNeeded) {
    halfW = halfWNeeded;
    halfH = halfWNeeded / canvasAspect;
  } else {
    halfH = halfHNeeded;
    halfW = halfHNeeded * canvasAspect;
  }

  const effectiveZoom = zoom && zoom > 0 ? zoom : 1;
  halfW /= effectiveZoom;
  halfH /= effectiveZoom;

  return {
    left: centerXCam - halfW,
    right: centerXCam + halfW,
    bottom: centerYCam - halfH,
    top: centerYCam + halfH,
    camPosition,
    camTarget,
    boxWidthCam,
    boxHeightCam,
    centerXCam,
    centerYCam,
  };
}
