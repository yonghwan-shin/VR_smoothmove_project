int calculateMoMa(long now, long duration)
{
  output_data.print(now+","); // print the timestamp

  for (Target target : targets) 
    target.moveOrbit(duration);      

  // save all target coords
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

  // print cursor data
  output_data.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
  output_raw.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");

  float[] headData = new float[2];
  headData = headDataProcess();
  /*
   * output to file
   */
  output_data.print("*HEAD"+","+headData[1]+","+headData[0]+",");
  output_raw.print ("*HEAD"+","+headData[1]+","+headData[0]+",");

  if (now - modeChangeTime > MOMA_STARTUP)
  {
    // TODO - remove globals here - make it clearer!
    addTargetData(now, xs, ys);                                              // store target data
    int winner = processIMUData(now, modeChangeTime + MOMA_STARTUP, pvr);    // process head data - capture and correlate against stored target data.

    // print correls if we don't have a winner; if we have a winner they are printed in long form.... We can probably simplify and change this... 
    if (winner == -1) 
    {
      output_data.print(correlator.correlData);
      output_raw. print(correlator.correlData);
      //println("Test: " + correlator.correlData);
    }
    output_data.print("\n");
    return winner;
  }

  output_data.print("\n");
  //output_raw.print("\n"); // where is this? 
  return -1;  // default no winner.
}




/*
 * Correlates head and target data
 */
int processIMUData(long now, long start, PGraphicsVR pvr)
{ 
  int currentTrial = getCurrentTrial();

  ///*
  // * Get angles from the head transform
  // */
  //float[] headRotation = new float[4];
  //pvr.headTransform.getQuaternion(headRotation, 0);
  //float[] yprVR        = getYawPitchRoll(headRotation);   

  ///*
  // * Correct for a wrap
  // */
  //if (yprVR[0] >0)       yprVR[0] = 180-yprVR[0];
  //else if (yprVR[0] <0)  yprVR[0] = -yprVR[0]-180;

  float[] headData = new float[2];
  headData = headDataProcess();
  /*
   * Add the data
   */
  addHeadData(now, headData[1], headData[0]);

  /*
   * output to file
   */
  //output_data.print("*HEAD"+","+headData[1]+","+headData[0]+",");
  //output_raw.print ("*HEAD"+","+headData[1]+","+headData[0]+",");

  // Run the correlations - only if we have more than MOMA_DURATION of data!
  int winner = -1;
  try {
    if (now - start > MOMA_DURATION)
      winner = correlator.batchMatch_resample(_timeHead, _xHead, _yHead, _timeTargets, _targetXs, _targetYs);
  }
  catch (Exception e) {
    println("MoMa Exception: " + e.getMessage()); 
    println(e.getStackTrace());
  }

  if ((winner >= 0 && winner <= TARGET_NUM && now-start > MOMA_DURATION)) 
  {
    over_target_num = winner;
    if (over_target_num == (int)trial_order.get(0))
    {
      println("MoMa trial successully finished in "   + (now-modeChangeTime)); 
      successCount++;
      correct_selection = true;
      total_trial_time = total_trial_time + (now-modeChangeTime);
    } else
    {
      println("MoMa trial error finished in "   + (now-modeChangeTime));
      errorCount++;
    }

    /* 
     * Print results.
     */
    String boilerPlate = currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+","+(over_target_num == trial_order.get(0))+","+winner+","+(now-modeChangeTime)+"\n";
    output_data.print("\n###END," + boilerPlate + "\n");
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