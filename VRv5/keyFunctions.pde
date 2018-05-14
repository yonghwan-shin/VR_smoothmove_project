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
    success++;
    correct_selection = true;
    keyboard_avg       = keyboard_avg + (now - modeChangeTime);
    }
  
  // print the data about on/off target movements.
  printOnOffData(now); 

}