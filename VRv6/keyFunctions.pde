void calculateKey(long now)
  {
  output_data.print(now+","); // print the timestamp
  output_data.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + "\n");
  output_raw. print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y);
  }


void keySelection()
{
  long now = millis();
   
  if (over_target_num == (int)trial_order.get(0))
    {
    println("Key trial finished in "   + (now-modeChangeTime)); 
    successCount++;
    correct_selection = true;
    total_trial_time  = total_trial_time + (now - modeChangeTime);
    }
  else
    errorCount++; 
  
  // print the data about on/off target movements.
  printOnOffData(now); 

}