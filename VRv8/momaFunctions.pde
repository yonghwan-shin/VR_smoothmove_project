/*
 * Acquire head angles
 */
float[] getHeadAngles()
  {
  float[] headRotation = new float[4];
  pvr.headTransform.getQuaternion(headRotation, 0);
  float[] yprVR        = getYawPitchRoll(headRotation);   

  if (yprVR[0] >0)       yprVR[0] = 180-yprVR[0];
  else if (yprVR[0] <0)  yprVR[0] = -yprVR[0]-180;

  return yprVR; 
  }
