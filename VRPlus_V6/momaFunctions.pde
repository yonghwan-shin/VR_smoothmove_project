// run MoMa all the time on data, capped at 1000ms window size
// prior to 1000ms, adjust spring stregnths, post 1000ms, select targets

/*
 * These manage when we change the weights in the spring system
 */
long  lastApplied = -1;  // last time
int   lastIndex   = -1;  // last target index
float lastValue   = -1;  // last correl val
void resetWeightVars()   // reset it all
  {
  lastApplied = -1;
  lastIndex = -1;
  lastValue = -1;
  }

int calculateMoMa(long now, long duration)
{
  output_data.print(now+","); // print the timestamp

  String dWeights = "";
  dWeights = applyDynamicWeights(APPLY_DYNAMIC, now, duration); // apply dynamic weights (if used)
  
  boolean[] enabled = showHideTargets(false); // show and hide targets (if used)

  // save all target coords - get half from each set of spinners. 
  float[] xs  = new float[TARGET_NUM];
  float[] ys  = new float[TARGET_NUM];
  
  for (int i = 0; i < spinsCW.getSize(); i++) 
    {
    spinner target_tmp = spinsCW.getSpinner(i);
    xs[i] = target_tmp.getOrbitX();
    ys[i] = target_tmp.getOrbitY();
    String s = "*Target "+ i +","+ xs[i] +","+  ys[i] +",";
    output_data.print(s);
    output_raw.print (s);
    }
  
  for (int i = 0; i < spinsCCW.getSize(); i++) 
    {  
    spinner target_tmp = spinsCCW.getSpinner(i);
    xs[i+spinsCW.getSize()] = target_tmp.getOrbitX(); // add in an offset from the first set of spinners
    ys[i+spinsCW.getSize()] = target_tmp.getOrbitY(); // add in an offset from the first set of spinners
    String s = "*Target "+ (i + spinsCW.getSize()) +","+ xs[i+spinsCW.getSize()] +","+  ys[i+spinsCW.getSize()] +",";
    output_data.print(s);
    output_raw.print (s);
    }
  
  // print cursor data
  output_data.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
  output_raw.print ("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
  //println("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
  
  // read, return (and print) the head angles
  float[] yprVR = getHeadAngles(); 
    
  addTargetData(now, xs, ys);                                              // store target data
  
  if (APPLY_CURSOR) // if we are using the cusor, don't use head angle, user cursor positions.... (and if it falls off the board??)
    addHeadData  (now, -cursor_pos.x, cursor_pos.y);                        // store head data
  else
    addHeadData  (now, yprVR[1], yprVR[0]);                                // store head data
  
  int winner = processIMUData(now, modeChangeTime, enabled);    // process head data - capture and compute correlations against stored target data.
  
  // check for stop event
  boolean stop = true; // default is true, because the default is not using the stop event. 
  
  if (APPLY_STOP)
    {
    stop = false;
    int stopResult = stopEvent(now, new PVector(yprVR[1], yprVR[0]), winner);
    if (stopResult>=0)
      {
      stop = true;
      winner = stopResult;
      println("Stop!");
      }
    }
  
  if (stop) 
    processWinner(winner, now, modeChangeTime); 
  
  if (APPLY_FEEDBACK)
    {
    if (correlator.soloWinner>=spinsCW.getSize())
      spinsCCW.getSpinner(correlator.soloWinner-spinsCW.getSize()).addHighlight(duration);
    else if (correlator.soloWinner>=0)
      spinsCW.getSpinner(correlator.soloWinner).addHighlight(duration);
    }
  
  //print our the correlations if we are calcuating them. 
  output_data.print(correlator.correlData);
  output_raw. print(correlator.correlData);
  //print(correlator.correlData);
  
  // print the highlight info (if any)  
  output_data.print(dWeights); 
  // println(dWeights);
  
  if (winner >= 0 && winner <= TARGET_NUM && now-modeChangeTime > (MOMA_STARTUP + MOMA_DURATION) && stop) 
    {
    printMoMaResults(now, winner);
    resetWeightVars();
    output_data.print("\n");// always print an eol
    return winner;// return the data
    }
  output_data.print("\n");// always print an eol  
  return -1;
}

/*
 * Acquire head angles
 */
float[] getHeadAngles()
  {
  /*
   * Get angles from the head transform
   */
  float[] headRotation = new float[4];
  
  // VR_SPECIFIC
  pvr.headTransform.getQuaternion(headRotation, 0);
  
  float[] yprVR        = getYawPitchRoll(headRotation);   

  /*
   * Correct for a wrap
   */
  if (yprVR[0] >0)       yprVR[0] = 180-yprVR[0];
  else if (yprVR[0] <0)  yprVR[0] = -yprVR[0]-180;
  
  /*
   * output to file
   */
  output_data.print("*HEAD"+","+yprVR[1]+","+yprVR[0]+",");
  output_raw.print ("*HEAD"+","+yprVR[1]+","+yprVR[0]+",");
  
  /*
   * Return the head angles
   */
  return yprVR; 
  }




/*
 * Correlates head and target data
 */
// VR_SPECIFIC
int processIMUData(long now, long start, boolean[] enabled)
//int processIMUData(long now, long start)
{  
  // Run the correlations always
  int winner = -1;
  try {winner = correlator.batchMatch_resample(_timeHead, _xHead, _yHead, _timeTargets, _targetXs, _targetYs, enabled);}
  catch (Exception e) {println("MoMa Exception: " + e.getMessage()); println(e.getStackTrace());}
  
  if (winner >= 0 && winner <= TARGET_NUM && !correlator.lowSD && now-start > (MOMA_DURATION + MOMA_STARTUP)) 
    return winner;   // correl success - not checked if its the right target
  else if (winner<0)
    return winner;   // various error conds from the correlator

  return -1;         // correl success (winner>=0) but not meeting other req's
  }
  

void processWinner(int winner, long now, long start)
  {
  if (winner < 0 || winner >= TARGET_NUM)
    return; // not sucessful 
    
  over_target_num = winner; // this is the selected target
  if (over_target_num == (int)trial_order.get(0))
    {
    println("MoMa trial successully finished in "   + (now-start), over_target_num, (int)trial_order.get(0)); 
    successCount++;
    correct_selection = true;
    total_trial_time = total_trial_time + (now-start);
    }
  else
    {
    println("MoMa trial error finished in "   + (now-start), over_target_num, (int)trial_order.get(0));
    errorCount++;
    }
   }
  
  
void printMoMaResults(long now, int winner)
  {
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
  
  

  
  
  
String applyDynamicWeights(boolean useWeights, long now, long duration)
  {
  if (TARGET_NUM==16) 
    return applyDynamicWeights16(useWeights, now, duration); 
  else
    return applyDynamicWeights8(useWeights, now, duration);
  }


// This applies a force to the target 
String applyDynamicWeights8(boolean useWeights, long now, long duration)
  {
  float[] weights = new float[spinsCW.getSize()];
  
  // update the CW spinners with weights from the correlator (logged last time through the loop)
  int cIndex   = lastIndex;
  float cValue = lastValue; 
  if (lastApplied == -1 || now-lastApplied>MOMA_STARTUP_DYN_GAP) // only update this once in a while... 
    {
    cIndex = lastIndex = correlator.getMaxScoreIndex();
    cValue = lastValue = correlator.getMaxScore();
    lastApplied = now; 
    }
  
  // activate the main target
  for (int i=0;i<spinsCW.getSize();i++)
    weights[i] = 0.0;
  if (useWeights && now-modeChangeTime > MOMA_STARTUP_DYN  && cValue > FOCUS_THRESHOLD && cIndex >= 0 && cIndex < spinsCW.getSize()) 
    weights[cIndex] = FORCE_HIGHLIGHT;
  spinsCW. updateSpinners(useWeights, weights, duration);
  
  for (int i=0;i<spinsCCW.getSize();i++)
    weights[i] = 0.0;
  if (useWeights && now-modeChangeTime > MOMA_STARTUP_DYN  && cValue > FOCUS_THRESHOLD && cIndex >= spinsCW.getSize() && cIndex < spinsCW.getSize() + spinsCCW.getSize())
    weights[negMod(cIndex, spinsCCW.getSize())] = FORCE_HIGHLIGHT;
  spinsCCW. updateSpinners(useWeights, weights, duration);
  
  String data = ""; 
  if (now-modeChangeTime > MOMA_STARTUP_DYN  && cValue > FOCUS_THRESHOLD && useWeights)
    data = "Focus," + cIndex + ", Target, " + (int)trial_order.get(0);
  return data; 
  }
  
  
  
String applyDynamicWeights16(boolean useWeights, long now, long duration)
  {
  float[] weights = new float[spinsCW.getSize()];
  
  // update the CW spinners with weights from the correlator (logged last time through the loop)
  int cIndex   = lastIndex;
  float cValue = lastValue; 
  if (lastApplied == -1 || now-lastApplied>MOMA_STARTUP_DYN_GAP) // only update this once in a while... 
    {
    cIndex = lastIndex = correlator.getMaxScoreIndex();
    cValue = lastValue = correlator.getMaxScore();
    lastApplied = now; 
    }
  int next = -1;
  int prev = -1;
  float dist = 0;
  float dist2 = 0;
  boolean twice = false;
  
  // in this design, we activate the two around the max selection
  // this is a dying design for three targets, a bad design for four target sets and ok for higher numbers (up to 8?)
  // in these larger groups, it equally spaces the three targets around the top target. This is reasonable.
  // in smaller groups it mushes them up (3 targets) or does nothing (4 targets). 
  // for 4 targets, slam the middle target with extra force.
  // we may want to apply this only once, as continually varying it doesn't really seem to be helpful.
  for (int i=0;i<spinsCW.getSize();i++)
    weights[i] = 0.0;
  if (useWeights && now-modeChangeTime > MOMA_STARTUP_DYN  && cValue > FOCUS_THRESHOLD && cIndex >= 0 && cIndex < spinsCW.getSize()) 
    {  
    next = negMod(cIndex+1, spinsCW.getSize()); // so if its index 7, we go one up to 0
    prev = negMod(cIndex-1, spinsCW.getSize()); // so if its index 0, we go one down to 7
    weights[next] = FORCE_HIGHLIGHT;
    weights[prev] = FORCE_HIGHLIGHT;
    dist  = abs(spinsCW.getSpinner(cIndex).aPos - spinsCW.getSpinner(next).aPos);
    dist2 = abs(spinsCW.getSpinner(cIndex).aPos - spinsCW.getSpinner(prev).aPos);
    }
  spinsCW. updateSpinners(useWeights, weights, duration);
  
  for (int i=0;i<spinsCCW.getSize();i++)
    weights[i] = 0.0;
  if (useWeights && now-modeChangeTime > MOMA_STARTUP_DYN  && cValue > FOCUS_THRESHOLD && cIndex >= spinsCW.getSize() && cIndex < spinsCW.getSize() + spinsCCW.getSize())
    {  
    if (next!=-1)
      twice = true;
    next = negMod(cIndex+1, spinsCCW.getSize()); // so if its index 15, we go one up to 8
    prev = negMod(cIndex-1, spinsCCW.getSize()); // so if its index 8, we go one down to 15
    weights[next] = FORCE_HIGHLIGHT;
    weights[prev] = FORCE_HIGHLIGHT;
    dist  = abs(spinsCCW.getSpinner(cIndex-spinsCW.getSize()).aPos - spinsCCW.getSpinner(next).aPos);
    dist2 = abs(spinsCCW.getSpinner(cIndex-spinsCW.getSize()).aPos - spinsCCW.getSpinner(prev).aPos);
    next+=spinsCW.getSize();
    prev+=spinsCW.getSize();
    }
  spinsCCW. updateSpinners(useWeights, weights, duration);
  
  String data = ""; 
  if (now-modeChangeTime > MOMA_STARTUP_DYN  && cValue > FOCUS_THRESHOLD)
    data = "Focus," + prev + ", " + cIndex + "," + next + ", Dists, " + dist*360.0 + ", " + dist2*360.0 + ", Target, " + (int)trial_order.get(0) + "," + twice;// + "," + winner;
  return data; 
  }
  