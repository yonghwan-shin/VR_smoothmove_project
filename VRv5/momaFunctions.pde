int calculateMoMa(long now)
{
  output_data.print(now+","); // print the timestamp

  for (Target target : targets) target.moveOrbit();      // save all target coords
  float[] xs  = new float[TARGET_NUM];
  float[] ys  = new float[TARGET_NUM];
  for (int i = 0; i < TARGET_NUM; i++) 
    {
    Target target_tmp = targets.get(i);
    xs[i] = target_tmp.getOrbitX();
    ys[i] = target_tmp.getOrbitY();
    String s = "*Target "+ i +","+ xs[i] +","+  ys[i] +",";
    output_data.print(s);
    output_raw.print (s);
    }
  if (now - modeChangeTime > MOMA_ACTIVATION_THRESHOLD) 
    addTargetData(now, xs, ys);          // process target data
  
  output_data.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
  output_raw.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
  
  return processIMUData(now, modeChangeTime + MOMA_ACTIVATION_THRESHOLD, pvr);            // process head data
}




/*
 * Correlates head and target data
 */
int processIMUData(long now, long start, PGraphicsVR pvr)
{ 
  int currentTrial = getCurrentTrial();
  
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
  
  /*
   * Add the data
   */
  addHeadData(now, yprVR[1], yprVR[0]);

  /*
   * output to file
   */
  output_data.print("*HEAD"+","+yprVR[1]+","+yprVR[0]+",\n");
  output_raw.print("*HEAD"+","+yprVR[1]+","+yprVR[0]);

  // Run the correlations
  int winner = -1;
  if (now - start > MOMA_THRESHOLD)
    winner = correlator.batchMatch_resample(_timeHead, _xHead, _yHead, _timeTargets, _targetXs, _targetYs); 
  
  if ((winner >= 0 && winner <= TARGET_NUM && now-start > MOMA_THRESHOLD)) 
  {
    //correlator.printDuration();
    //correlator.printCorrels();
    //println("Winner: " + winner);
    //println("TARGET IS : " + trial_order.get(0));
    //println(" MOMA CAL TIME : " + abs(startTrialTime - now));
    moma_avg = moma_avg + -(modeChangeTime - now);
    
    over_target_num = winner;
    if (over_target_num == (int)trial_order.get(0))
      {
      success++;
      correct_selection = true;
      }

    /* 
     * Print results.
     */
    String boilerPlate = currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+","+(over_target_num == trial_order.get(0))+","+winner+","+(now-modeChangeTime)+"\n";
    output_data.print(  "###END," + boilerPlate + "\n");
    output_raw.print ("\n###END," + boilerPlate + "\n");
    output_data.print("###MOMA_CORRELATION_RESULT_START," + boilerPlate);
    output_raw.print ("###MOMA_CORRELATION_RESULT_START," + boilerPlate);
    for (int i=0; i<correlator.corResults.length; i++)
    {  
      //output_data.print("\n");
      for (int j=0; j<correlator.corResults[i].length; j++) {
        output_data.print( i + ", " +  j + " ," +correlator.corResults[i][j] + "  \n");
        output_raw.print ( i + ", " +  j + " ," +correlator.corResults[i][j] + "  \n");
      }
    }
    output_data.print("###MOMA_CORRELATION_RESULT_END,"+boilerPlate);
    output_raw.print ("###MOMA_CORRELATION_RESULT_END,"+boilerPlate);
  }
  
 return winner; 
}