float[] headDataProcess()
{
  /*
   * Get angles from the head transform
   */
  float[] headRotation = new float[4];
  pvr.headTransform.getQuaternion(headRotation, 0);
  float[] yprVR        = getYawPitchRoll(headRotation);   

  /*
   * Correct for a wrap
   */
  if (yprVR[0] >0)       yprVR[0] = 180-yprVR[0];
  else if (yprVR[0] <0)  yprVR[0] = -yprVR[0]-180;
  
  
  return new float[] {yprVR[0], yprVR[1]};
}