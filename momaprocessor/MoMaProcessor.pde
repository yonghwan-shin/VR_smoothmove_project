import java.util.List;

final String CODE_START      = "###START";
final String CODE_END_MOMA   = "###MOMA_CORRELATION_RESULT_END"; 
final String CODE_END        = "###OUT_TIMES_END"; 

final int TERM_BLOCK         = 1;
final int TERM_TRIAL         = 2;
final int TERM_TARGET        = 3;
final int TERM_CORRECT       = 4;
final int TERM_DURATION      = 5;

// MoMa has an extra selection target field at 5, pushing duration to 6
final int TERM_SELECTED_MOMA = 5;
final int TERM_DURATION_MOMA = 6;

class summaryData 
  {
  float timeMean;
  float timeB1;
  float timeB2;
  
  float errorMean;
  float errorB1;
  float errorB2;
  
  summaryData()
    {timeMean = timeB1 = timeB2 = errorMean = errorB1 = errorB2 = 0;}
  }


// we run practice until block 3 before and after the break at 10 blocks - basically exlcude blocks 0, 1, 2, 10, 11, 12. 
// so we have seven blocks (7*8 = 54) before and after the break for a total of 108/condition/participant for analysis
// So 18 * 108 * 3 = 5832 trials in total
int PRACTICE_UNTIL_BLOCK  = 3;
int PRACTICE_DEVISOR      = 10;

long totalTimeB1          = 0;
long totalCorrectB1       = 0;
long totalErrorB1         = 0;

long totalTimeB2          = 0;
long totalCorrectB2       = 0;
long totalErrorB2         = 0;

// dwell cols
int DWELL_B1_TIME      = 1;
int DWELL_B2_TIME      = 2;
int DWELL_ALL_TIME     = 3;
int DWELL_B1_ERROR     = 10;
int DWELL_B2_ERROR     = 11;
int DWELL_ALL_ERROR    = 12;

// keyboard cols
int KEYBOARD_B1_TIME   = 4;
int KEYBOARD_B2_TIME   = 5;
int KEYBOARD_ALL_TIME  = 6;
int KEYBOARD_B1_ERROR  = 13;
int KEYBOARD_B2_ERROR  = 14;
int KEYBOARD_ALL_ERROR = 15;

// MoMa cols
int MOMA_B1_TIME       = 7;
int MOMA_B2_TIME       = 8;
int MOMA_ALL_TIME      = 9;
int MOMA_B1_ERROR      = 16;
int MOMA_B2_ERROR      = 17;
int MOMA_ALL_ERROR     = 18;

int[] dwellIDs    = {DWELL_B1_TIME,     DWELL_B2_TIME,     DWELL_ALL_TIME,     DWELL_B1_ERROR,     DWELL_B2_ERROR,     DWELL_ALL_ERROR};
int[] keyboardIDs = {KEYBOARD_B1_TIME,  KEYBOARD_B2_TIME,  KEYBOARD_ALL_TIME,  KEYBOARD_B1_ERROR,  KEYBOARD_B2_ERROR,  KEYBOARD_ALL_ERROR};
int[] MoMaIDs     = {MOMA_B1_TIME,      MOMA_B2_TIME,      MOMA_ALL_TIME,      MOMA_B1_ERROR,      MOMA_B2_ERROR,      MOMA_ALL_ERROR};

void setup()
  {
    // how many subs do we have?
    int folderCount = getFolderCount(sketchPath() + "/data/ExperimentData/");
    println("Found folders for " + folderCount + " participants.");
    
    // setup the table for the results
    Table results = new Table();
  
    results.addColumn("SubNum");
    
    results.addColumn("Dwell_B1_time");
    results.addColumn("Dwell_B2_time");
    results.addColumn("Dwell_All_time");
    
    results.addColumn("Keyboard_B1_time");
    results.addColumn("Keyboard_B2_time");
    results.addColumn("Keyboard_All_time");
    
    results.addColumn("MoMa_B1_time");
    results.addColumn("MoMa_B2_time");
    results.addColumn("MoMa_All_time");
    
    results.addColumn("Dwell_B1_error");
    results.addColumn("Dwell_B2_error");
    results.addColumn("Dwell_All_error");
    
    results.addColumn("Keyboard_B1_error");
    results.addColumn("Keyboard_B2_error");
    results.addColumn("Keyboard_All_error");
    
    results.addColumn("MoMa_B1_error");
    results.addColumn("MoMa_B2_error");
    results.addColumn("MoMa_All_error");
    
    for (int i=0;i<folderCount;i++)
      {
      results.addRow();
      results.setInt(i, 0, i+1); 
      }
      
    println("Initialized data store for " + results.getRowCount() + " participants."); 
    
    ArrayList<File> f = processFiles(false, "data/ExperimentData/", "_Keyboard", "data");
    for (int i=0;i<f.size();i++)
      {
      summaryData s = processOneFile(f.get(i).getPath(), false);
      results = setResults(results, getSubNum(f.get(i).getName(), "_Keyboard")-1, keyboardIDs, s); 
      }
    println("Processed keyboard files.");
    
    f = processFiles(false, "data/ExperimentData/", "_Dwell", "data");
    for (int i=0;i<f.size();i++)
      {
      summaryData s = processOneFile(f.get(i).getPath(), false);
      results = setResults(results, getSubNum(f.get(i).getName(), "_Dwell")-1, dwellIDs, s);
      }
    println("Processed dwell files.");
    
    f = processFiles(false, "data/ExperimentData/", "_MoMa", "data");
    for (int i=0;i<f.size();i++)
      {
      summaryData s = processOneFile(f.get(i).getPath(), true); // true here is for using MoMa format
      results = setResults(results, getSubNum(f.get(i).getName(), "_MoMa")-1, MoMaIDs, s);
      }
    println("Processed MoMa files.");
    
    saveTable(results, "results.csv");
    println("Data file saved to \"results.csv\".");
    
    // calculate means and stdevs for ease of reference - only on two all comparisons
    DescriptiveStatistics dwellMeanTime     = new DescriptiveStatistics();
    DescriptiveStatistics dwellMeanError    = new DescriptiveStatistics();
    DescriptiveStatistics keyboardMeanTime  = new DescriptiveStatistics();
    DescriptiveStatistics keyboardMeanError = new DescriptiveStatistics();
    DescriptiveStatistics MoMaMeanTime      = new DescriptiveStatistics();
    DescriptiveStatistics MoMaMeanError     = new DescriptiveStatistics();
    for (int i=0; i<folderCount; i++)
      {
      dwellMeanTime.addValue     (results.getFloat(i, DWELL_ALL_TIME));
      dwellMeanError.addValue   (results.getFloat(i, DWELL_ALL_ERROR));
      keyboardMeanTime.addValue  (results.getFloat(i, KEYBOARD_ALL_TIME));
      keyboardMeanError.addValue(results.getFloat(i, KEYBOARD_ALL_ERROR));
      MoMaMeanTime.addValue      (results.getFloat(i, MOMA_ALL_TIME));
      MoMaMeanError.addValue    (results.getFloat(i, MOMA_ALL_ERROR));
      }
    println("\n\nSummary");
    println("Dwell overall mean time: "      + dwellMeanTime.getMean()              + "ms and stdev: "  + (int)dwellMeanTime.getStandardDeviation()          + "ms.");
    println("Dwell overall mean errors: "    + percent(dwellMeanError.getMean())    + "% and stdev: "   + percent(dwellMeanError.getStandardDeviation())    + "%.");
    println();
    println("Keyboard overall mean time: "   + keyboardMeanTime.getMean()           + "ms and stdev: "  + (int)keyboardMeanTime.getStandardDeviation()       + "ms.");
    println("Keyboard overall mean errors: " + percent(keyboardMeanError.getMean()) + "% and stdev: "   + percent(keyboardMeanError.getStandardDeviation()) + "%.");
    println();
    println("MoMa overall mean time: "       + MoMaMeanTime.getMean()               + "ms and stdev: "  + (int)MoMaMeanTime.getStandardDeviation()           + "ms.");
    println("MoMa overall mean errors: "     + percent(MoMaMeanError.getMean())     + "% and stdev: "   + percent(MoMaMeanError.getStandardDeviation())     + "%.");
    
    // calculate basic ANOVAs
    println("\n\nStats");
    println("Warning: these don't include any assumption checks or corrections. Final values may differ."); 
    
    double[] timeDwell     = new double[folderCount]; 
    double[] timeKeyboard  = new double[folderCount]; 
    double[] timeMoMa      = new double[folderCount];
    double[] errorDwell    = new double[folderCount]; 
    double[] errorKeyboard = new double[folderCount]; 
    double[] errorMoMa     = new double[folderCount];
    for (int i=0;i<folderCount;i++)
      {
      timeDwell[i]      = dwellMeanTime.getElement(i); 
      timeKeyboard[i]   = keyboardMeanTime.getElement(i); 
      timeMoMa[i]       = MoMaMeanTime.getElement(i);
      errorDwell[i]     = dwellMeanError.getElement(i); 
      errorKeyboard[i]  = keyboardMeanError.getElement(i); 
      errorMoMa[i]      = MoMaMeanError.getElement(i);
      }
      
    println("\nANOVA");
    List times = new ArrayList();
    times.add(timeDwell);
    times.add(timeKeyboard);
    times.add(timeMoMa);
    
    List errors = new ArrayList();
    errors.add(errorDwell);
    errors.add(errorKeyboard);
    errors.add(errorMoMa);
    
    println("Time F = "  + TestUtils.oneWayAnovaFValue(times) + " p = "  + TestUtils.oneWayAnovaPValue(times)); 
    println("Error F = " + TestUtils.oneWayAnovaFValue(errors) + " p = " + TestUtils.oneWayAnovaPValue(errors)); 
    
    println("\nPairwise on time (P values need be 0.0167 to be significant at 0.05)");
    println("Dwell vs Keyboard: " + TestUtils.pairedTTest(timeDwell, timeKeyboard));
    println("Dwell vs MoMa: "     + TestUtils.pairedTTest(timeDwell, timeMoMa));
    println("Moma vs Keyboard: "  + TestUtils.pairedTTest(timeMoMa,  timeKeyboard));
    
    println("\nPairwise on error (P values need be 0.0167 to be significant at 0.05)");
    println("Dwell vs Keyboard: " + TestUtils.pairedTTest(errorDwell, errorKeyboard));
    println("Dwell vs MoMa: "     + TestUtils.pairedTTest(errorDwell, errorMoMa));
    println("Moma vs Keyboard: "  + TestUtils.pairedTTest(errorMoMa,  errorKeyboard));
    
    println("\nAll done."); 
    exit(); 
  }
  
void draw()
  {
  }
  
  
summaryData processOneFile(String fn, boolean useMoMa)
  {
  String[] lines = loadStrings(fn);
  
  totalTimeB1   = 0;
  totalCorrectB1= 0;
  totalErrorB1  = 0;
  totalTimeB2   = 0;
  totalCorrectB2= 0;
  totalErrorB2  = 0;
  
  boolean foundStart = false; 
  int trialID = 0; 
  int startID = -1; 
  for (int i=0;i<lines.length;i++)
    {
    if (!foundStart && lines[i].length()>CODE_START.length() && trim(lines[i]).substring(0, CODE_START.length()).equals(CODE_START))
      {
      foundStart = true;   
      startID = i; 
      }
      
    else if (foundStart && lines[i].length()>getEndCode(useMoMa).length() && trim(lines[i]).substring(0, getEndCode(useMoMa).length()).equals(getEndCode(useMoMa)))
      {
      processOneTrial(startID, i, trialID, lines, useMoMa); 
      trialID++; 
      foundStart = false;
      startID = -1; 
      }
    }
    
  //println("B1 - Mean time: " + (totalTimeB1/totalCorrectB1) + "ms over " +totalCorrectB1+ " sucessful trials, error rate: " + ((int)(10000.0*((float)totalErrorB1/(float)(totalCorrectB1+totalErrorB1))))/100.0 + "% ("+totalErrorB1+").");
  //println("B2 - Mean time: " + (totalTimeB2/totalCorrectB2) + "ms over " +totalCorrectB1+ " sucessful trials, error rate: " + ((int)(10000.0*((float)totalErrorB2/(float)(totalCorrectB2+totalErrorB2))))/100.0 + "% ("+totalErrorB2+").");
  
  summaryData s = new summaryData();
  s.timeB1 = totalTimeB1/totalCorrectB1;
  s.timeB2 = totalTimeB2/totalCorrectB2;
  s.timeMean = (s.timeB1 + s.timeB2)/2;
  
  s.errorB1 = (float)totalErrorB1/(float)(totalCorrectB1+totalErrorB1); 
  s.errorB2 = (float)totalErrorB2/(float)(totalCorrectB2+totalErrorB2); 
  s.errorMean = (s.errorB1 + s.errorB2)/2.0;
  
  return s; 
  }
  
  
  void processOneTrial(int start, int end, int id, String[] lines, boolean useMoMa)
    { 
    String[] parts = split(lines[end], ",");
    int block = getFigure(TERM_BLOCK, parts); 
    
    if (block%PRACTICE_DEVISOR>=PRACTICE_UNTIL_BLOCK)
      {
      //println("found trial " + id, block, parts[2], start, end, lines[end].indexOf("true")!=-1);
      // log the time and the error count
      if (getCorrect(parts))
        {
        if (block<PRACTICE_DEVISOR)
          {
          totalCorrectB1++;
          totalTimeB1+=getFigure(getDurationIndex(useMoMa), parts);
          }
        else
          {
          totalCorrectB2++;
          totalTimeB2+=getFigure(getDurationIndex(useMoMa), parts);
          }
        }
      else
        {
        if (block<PRACTICE_DEVISOR)
          totalErrorB1++;
        else
          totalErrorB2++;
        }
      }
    }
    
    
  Table setResults(Table results, int row, int[] cols, summaryData data)  
    {
    results.setFloat(row, cols[0], data.timeB1);
    results.setFloat(row, cols[1], data.timeB2);
    results.setFloat(row, cols[2], data.timeMean);
    
    results.setFloat(row, cols[3], data.errorB1);
    results.setFloat(row, cols[4], data.errorB2);
    results.setFloat(row, cols[5], data.errorMean);
    
    return results; // not needed. 
    }
    
  boolean getCorrect(String[] parts)
    {return parts[TERM_CORRECT].indexOf("true")!=-1;}
  int getFigure(int index, String[] parts)
    {return Integer.parseInt(parts[index].trim());}
  int getFigure(int index, String line)
    {String[] parts = split(line, ","); return getFigure(index, parts);}
    
  int getDurationIndex(boolean useMoMa)
    {if (useMoMa) return TERM_DURATION_MOMA; else return TERM_DURATION;}
    
  String getEndCode(boolean useMoMa)
    {if (useMoMa) return CODE_END_MOMA; else return CODE_END;}
    
  int getSubNum(String filename, String cond)
    {
    int start = filename.indexOf(cond) + cond.length() + 1;
    int end   = filename.substring(start).indexOf("_");
    return Integer.parseInt(filename.substring(start, start+end)); 
    }
    
  float percent(double in)
    {
    return (float)((int)(in*10000.0))/100.0; 
    }