int calculateDwell(long now, boolean onNewTarget)
{
  int currentTrial = getCurrentTrial();

  output_data.print(now+","); // print the timestamp
  output_data.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + "\n");
  output_raw.print ("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y);

  if (onNewTarget)
    dwellStartTime = now;

  if (over_target && now > dwellStartTime+DWELL_THRESHOLD) 
  {
    if (over_target_num == (int)trial_order.get(0))
    {
      success++;
      correct_selection = true;
      dwell_avg = dwell_avg + now - modeChangeTime;
    }

    printOnOffData(now); 

    return over_target_num;
  }

  return -1;
}