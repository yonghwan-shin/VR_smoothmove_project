int calculateDwell(long now)
{
  int currentTrial = getCurrentTrial();

  output_data.print(now+","); // print the timestamp
  output_data.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + "\n");
  output_raw.print ("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y);

  if (over_target && now > over_target_time+DWELL_THRESHOLD) 
  {
    if (over_target_num == (int)trial_order.get(0))
    {
      println("Dwell trial finished in "   + (now-modeChangeTime)); 
      successCount++;
      correct_selection = true;
      total_trial_time = total_trial_time + (now - modeChangeTime);
    }
    else
      errorCount++;

    printOnOffData(now); 

    return over_target_num;
  }

  return -1;
}