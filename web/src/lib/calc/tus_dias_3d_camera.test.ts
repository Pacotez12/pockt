import { describe, it, expect } from 'vitest';
import { computeTusDiasCameraFraming } from './tus_dias_3d_camera';

describe('computeTusDiasCameraFraming', () => {
  it('frames an 8x7 grid so it occupies ~85% of the viewport with balanced margins', () => {
    const result = computeTusDiasCameraFraming({
      weeks: 8,
      days: 7,
      maxHeight: 3.55,
      canvasWidth: 800,
      canvasHeight: 340,
      k: 1, // 3D
      yaw: 0,
    });

    const viewWidth = result.right - result.left;
    const viewHeight = result.top - result.bottom;
    const aspect = viewWidth / viewHeight;
    const canvasAspect = 800 / 340;

    // Aspect ratio must match canvas aspect ratio
    expect(aspect).toBeCloseTo(canvasAspect, 2);

    // Coverage along the constraining dimension must be ~85%
    const coverageX = result.boxWidthCam / viewWidth;
    const coverageY = result.boxHeightCam / viewHeight;
    const maxCoverage = Math.max(coverageX, coverageY);
    expect(maxCoverage).toBeCloseTo(0.85, 2);

    // Centered in camera view
    expect(result.left + viewWidth / 2).toBeCloseTo(result.centerXCam, 4);
    expect(result.bottom + viewHeight / 2).toBeCloseTo(result.centerYCam, 4);
  });

  it('frames a 26x7 grid scaling view width appropriately to fit 85% of canvas', () => {
    const result8 = computeTusDiasCameraFraming({
      weeks: 8,
      days: 7,
      maxHeight: 3.55,
      canvasWidth: 800,
      canvasHeight: 340,
      k: 1,
      yaw: 0,
    });

    const result26 = computeTusDiasCameraFraming({
      weeks: 26,
      days: 7,
      maxHeight: 3.55,
      canvasWidth: 800,
      canvasHeight: 340,
      k: 1,
      yaw: 0,
    });

    const viewWidth8 = result8.right - result8.left;
    const viewWidth26 = result26.right - result26.left;

    // 26 weeks must have a wider camera span than 8 weeks
    expect(viewWidth26).toBeGreaterThan(viewWidth8 * 1.5);

    // Coverage of 26 weeks is still ~85%
    const coverageX = result26.boxWidthCam / viewWidth26;
    const coverageY = result26.boxHeightCam / (result26.top - result26.bottom);
    expect(Math.max(coverageX, coverageY)).toBeCloseTo(0.85, 2);
  });

  it('works in top-down 2D mode (k = 0) and during transition (k = 0.5)', () => {
    const res2D = computeTusDiasCameraFraming({
      weeks: 8,
      days: 7,
      maxHeight: 0.12,
      canvasWidth: 800,
      canvasHeight: 340,
      k: 0,
      yaw: 0,
    });

    expect(res2D.right - res2D.left).toBeGreaterThan(0);
    expect(res2D.top - res2D.bottom).toBeGreaterThan(0);

    const resMid = computeTusDiasCameraFraming({
      weeks: 8,
      days: 7,
      maxHeight: 1.8,
      canvasWidth: 800,
      canvasHeight: 340,
      k: 0.5,
      yaw: 0.1,
    });

    expect(resMid.right - resMid.left).toBeGreaterThan(0);
    expect(resMid.top - resMid.bottom).toBeGreaterThan(0);
  });
});
