// todo - add code to check for and make the study dir. If the dir doesn't exist, the app currently crashes. 

import java.text.SimpleDateFormat;
import java.util.Calendar;

String FOLDER   = "/sdcard/study/";
String PREFIX   = "logMoMa";
String SUFFIX   = ".csv"; 
String DATAFILE = "data";
String RAWFILE  = "raw";
String SPACER   = "_";

PrintWriter output_raw = null;
PrintWriter output_data = null;

void setupFileNames(String mode, int sub)
{
  String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(Calendar.getInstance().getTime());
  String fn = FOLDER + PREFIX + SPACER + timeStamp + SPACER + mode + SPACER + sub + SPACER;  
  initLogFiles(fn);
}


void initLogFiles(String header)
{
  boolean fileError = false;

  try {
    if (output_data ==null) {                    //Make data log file
      output_data = new PrintWriter(header + DATAFILE + SUFFIX, "UTF-8");
      output_data.println("@@@Starting_Logging: " + header + DATAFILE + SUFFIX);
      output_data.flush();
    }
  }
  catch (Exception e)
  {
    println("Error on creating "+DATAFILE+" log file");
    fileError = true;
  }

  try {
    if (output_raw ==null) {                    //Make raw log file
      output_raw = new PrintWriter(header + RAWFILE + SUFFIX, "UTF-8");
      output_raw.println("@@@Starting_Logging: " + header + RAWFILE + SUFFIX);
      output_raw.flush();
    }
  }
  catch (Exception e)
  {
    println("Error on creating "+RAWFILE+" log file");
    fileError = true;
  }

  if (fileError)
    println("Failed to create log files!");
  else
    println("Log files created successfully.");
}



void writeStudyEnd()
{
  output_data.print("\n ###SUMMARY_START \n");
  output_raw.print("\n ###SUMMARY_START \n");
  println("EXPERIMENT OVER");

  println("Success Rate : " + successCount+ " / " + ((BLOCKS)*(TARGET_NUM)));
  output_data.print("Success Rate : ," + successCount+ " / " + ((BLOCKS)*(TARGET_NUM))+"\n");
  output_raw.print ("Success Rate : ," + successCount+ " / " + ((BLOCKS)*(TARGET_NUM))+"\n");
  
  println("Error Rate : " + errorCount+ " / " + (successCount+errorCount));
  output_data.print("Error Rate : ," + errorCount+ " / " + (successCount+errorCount)+"\n");
  output_raw.print ("Error Rate : ," + errorCount+ " / " + (successCount+errorCount)+"\n");

  output_data.print("Average time : ,"+ total_trial_time/(BLOCKS*TARGET_NUM)+"\n");
  output_raw.print ("Average time : ,"+ total_trial_time/(BLOCKS*TARGET_NUM)+"\n");
  
  output_data.print("###SUMMARY_END \n");
  output_raw.print("###SUMMARY_END \n");
  output_data.flush();
  output_raw.flush();
  output_data.close();
  output_raw.close();
}

/*
 * Print target on/off data for dwell and keyboard
 */
void printOnOffData(long now)
  {
  String boilerPlate = currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+ ","+(over_target_num == trial_order.get(0))+","+(now-modeChangeTime)+"\n";
  
  output_data.print(  "###END,"                  +boilerPlate);
  output_raw.print ("\n###END,"                  +boilerPlate); 
        
  // write out the in count data 
  output_data.print("\n###IN_COUNT_START," +boilerPlate);
  output_raw.print ("\n###IN_COUNT_START," +boilerPlate);
  for (int i =0; i<TARGET_NUM; i++) 
    {
    output_data.print(in_count[i]+ ",");
    output_raw.print (in_count[i]+ ",");
    }
  output_data.print("\n###IN_COUNT_END,"   +boilerPlate);
  output_raw.print ("\n###IN_COUNT_END,"   +boilerPlate);
        
  // write out the in times data 
  output_raw.print ("\n###IN_TIMES_START," +boilerPlate);
  output_data.print("\n###IN_TIMES_START," +boilerPlate);
  for (int i=0; i<TARGET_NUM; i++) 
    {
    for (int j=0; j <MAX_ON_OFFS; j++) 
      {
      output_data.print(in_time[i][j]+ ",");
      output_raw.print (in_time[i][j]+ ",");
       }
    output_data.print("\n");
    output_raw.print ("\n");
    }
  output_data.print("###IN_TIMES_END," +boilerPlate);
  output_raw.print ("###IN_TIMES_END," +boilerPlate);
    
  // write out the out count data  
  output_data.print("\n###OUT_COUNT_START," +boilerPlate);
  output_raw.print ("\n###OUT_COUNT_START," +boilerPlate);
  for (int i =0; i<TARGET_NUM; i++) 
    {
    output_data.print(out_count[i]+ ",");
    output_raw.print (out_count[i]+ ",");
    }
  output_data.print("\n###OUT_COUNT_END," +boilerPlate);
  output_raw.print ("\n###OUT_COUNT_END," +boilerPlate);
    
  // write out the out times data  
  output_data.print("\n###OUT_TIMES_START," +boilerPlate);
  output_raw.print ("\n###OUT_TIMES_START," +boilerPlate);
  for (int i=0; i<TARGET_NUM; i++) 
    {
    for (int j=0; j <MAX_ON_OFFS; j++) 
      {
      output_data.print(out_time[i][j]+ ",");
      output_raw. print(out_time[i][j]+ ",");
      }
    output_data.print("\n");
    output_raw. print("\n");
    }
  
  // and finish.
  output_data.print("###OUT_TIMES_END," +boilerPlate);
  output_raw.print ("###OUT_TIMES_END," +boilerPlate);
  }