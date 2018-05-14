/*
 * Utility functions for quat to angles
 */
static float[] getYawPitchRollRad(float[] q) {
  float[] ypr = new float[3]; // ypr
  float gx, gy, gz; // estimated gravity direction

  gx = 2 * (q[1]*q[3] - q[0]*q[2]);
  gy = 2 * (q[0]*q[1] + q[2]*q[3]);
  gz = q[0]*q[0] - q[1]*q[1] - q[2]*q[2] + q[3]*q[3];

  ypr[0] = atan2(2 * q[1] * q[2] - 2 * q[0] * q[3], 2 * q[0]*q[0] + 2 * q[1] * q[1] - 1);
  ypr[1] = atan(gx / sqrt(gy*gy + gz*gz));
  ypr[2] = atan(gy / sqrt(gx*gx + gz*gz));
  return ypr;
}

static float[] getYawPitchRoll(float[] q) {
  return arrayRadToDeg(getYawPitchRollRad(q));
}

static float[] arrayRadToDeg(float[] arr) {
  for (int i=0; i<arr.length; i++)
    arr[i] *= 180.0/PI;
  return arr;
}


/*
 * Utility function for ray-plane intersection
 */
public PVector intersectRayPlane(PVector rayOrigin, PVector rayPointOnPath, PVector planePoint, PVector planeNormal) 
{
  PVector P2SubPs = PVector.sub(rayPointOnPath, rayOrigin);
  PVector P3SubPs = PVector.sub(planePoint, rayOrigin);
  float u = planeNormal.dot(P3SubPs) / planeNormal.dot(P2SubPs);
  PVector P = PVector.add(rayOrigin, PVector.mult(P2SubPs, u));
  return P;
}