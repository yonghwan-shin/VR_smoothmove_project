/*
 * Run the correlations - check for performance problems. 
 */
public class Correlator
{
  PearsonsCorrelation pCorrelation;            // the correlation math object

  int numTargets;         // how many targets we are dealing with
  long windowSize;        // how many ms in a window 
  double correlThreshold; // correlation threshold to trigger selection

  double[][] corResults;  // the results of the coorelation - so we can check raw data....

  String correlData;      // this is the raw data used to compute the correlation matrix (useful for checks/debugging)

  long duration;          // how long the correlation calc takes....

  String stdDevStr;       // temp info about the std dev of the the data


  // log data
  double[] xHeadArray;
  double[] yHeadArray;
  long[]   timeHeadArray;  

  double[] xTarget0Array;
  double[] yTarget0Array;
  long[]   timeTargetsArray;

  // constructor and give default sizes/thresholds
  public Correlator(int _numTargets, long _windowSize, float _correlThreshold)
    {  
    correlData = "N/A";
    pCorrelation = new PearsonsCorrelation();
    adjustParameters(_numTargets, _windowSize, (double)_correlThreshold);
    }

  public void adjustParameters(int _numTargets, long _windowSize, float _correlThreshold)
    {adjustParameters(_numTargets, _windowSize, (double)_correlThreshold);}

  public void adjustParameters(int _numTargets, long _windowSize, double _correlThreshold)
    {
    numTargets      = _numTargets;
    correlThreshold = _correlThreshold; 
    windowSize      = _windowSize; 
    }
  
  
    

  // adjust sizes/thresholds
  public void setNumTargets          (int _numTargets) { 
    numTargets = _numTargets;
  }

  public void setCorrelationThreshold(double _correlThreshold) { 
    correlThreshold = _correlThreshold;
  }  

  public void setWindowSize          (long _windowSize) { 
    windowSize = _windowSize;
  }


  String getCorrel(int index)
  {
    String s = "";  
    if (corResults==null || index<0 || index>=corResults[0].length)
      return "-"; 

    return round((float)corResults[0][index]*100.0)/100.0 + ", " + round((float)corResults[1][index]*100.0)/100.0;
  }


  // utility to get the grid of correls
  String getCorrels()
  {  
    String s = "";  
    if (corResults==null)
      return ""; 

    for (int i=0; i<corResults.length; i++)
    {  
      for (int j=0; j<corResults[i].length; j++)
      {
        s+=((int)(100.0*corResults[i][j]))/100.0;
        if (j<corResults[i].length-1)
          s+=",";
      }
      s+=";";
    }
    return s;
  }


  // utility to print the grid of correls
  void printCorrels()
  {
    for (int i=0; i<corResults.length; i++)
    {  
      for (int j=0; j<corResults[i].length; j++)
        print( i + ", " +  j + " -> " +corResults[i][j] + "  "); 
      println();
    }
  }

  // utility to print the duration of a correl process
  void printDuration() {
    println("Duration: " + duration);
  }


  // xHead and yHead come as separate arrayLists, whereas targets are all bunched together. 
  public int batchMatch_resample(ArrayList<Long> timeHead,    ArrayList<Float> xHead,               ArrayList<Float> yHead, 
                                 ArrayList<Long> timeTargets, ArrayList<ArrayList<Float>> targetXs, ArrayList<ArrayList<Float>> targetYs)
  {
    duration = millis();                        // measure the time this calc takes
    corResults = new double[2][numTargets];     // store the correlation of head with all targets 
    correlData = "";                            // not logged anything yet
  
    /*
     * Check we have some data. If not, quit
     */ 
    if (timeHead==null || timeHead.size()==0 || timeTargets==null || timeTargets.size()==0)
      return -1; // no data, fail

    /*
     * Record the current end point of the data. Singled threaded, so this shouldn't change in the course of the calc. But still, its convenient
     */
    int headSize    = timeHead.size();  
    int targetsSize = timeTargets.size();

    /*
     * Get windowsize of head data
     */
    int headStartIndex = headSize-1;
    while (headStartIndex>0 && timeHead.get(headSize-1)-timeHead.get(headStartIndex) < windowSize)
      headStartIndex--;
    if (headStartIndex<0)
      return -2; // not enough data in the head sample, fail 
    
    /*
     * Box headStartIndex to headSize of data as doubles
     */
    xHeadArray     = getArrayListRangeFloat(xHead, headStartIndex, headSize);
    yHeadArray     = getArrayListRangeFloat(yHead, headStartIndex, headSize);
    if (xHeadArray==null || yHeadArray==null)
      return -3; // failed to get windowSize of data  
    
    /*
     * Check the head data exceeds a movement threshold - this looks like a pretty slow way to do this calc...
     */
    DescriptiveStatistics statsX = new DescriptiveStatistics();
    DescriptiveStatistics statsY = new DescriptiveStatistics();
    for (int i=0; i<xHeadArray.length; i++)
      {
      statsX.addValue(xHeadArray[i]);
      statsY.addValue(yHeadArray[i]);
      }
    double xsd = statsX.getStandardDeviation();
    double ysd = statsY.getStandardDeviation();
    stdDevStr = ((int)(xsd*100.0))/100.0 +", " + ((int)(ysd*100.0))/100.0;
    if ((xsd + ysd) < 4) // look at the axes as a pair because SDs between axes may vary in the 1 second window
      return -4; // fail on low variance in head sample. This is just drift in the sensor. Fairly vaguely defined threshold.


    /*
     * Get windowsize of target data
     */
    int targetsStartIndex = targetsSize-1;
    while (targetsStartIndex>0 && timeTargets.get(targetsSize-1)-timeTargets.get(targetsStartIndex) < windowSize)
      targetsStartIndex--;
    if (targetsStartIndex<0) 
      return -5; // not enough data in the target sample.
      
     
    for (int i=0; i<numTargets; i++)
      {
      /*
       * Get the correls for this target
       */
      double[] xTargetArray = getArrayListRangeFloat(targetXs.get(i), targetsStartIndex, targetsSize);
      double[] yTargetArray = getArrayListRangeFloat(targetYs.get(i), targetsStartIndex, targetsSize);

      /*
       * Run the correls for this target
       */
      if (xTargetArray!=null && yTargetArray!=null)
        {
        try {  
          corResults[0][i] = pCorrelation.correlation(xHeadArray, xTargetArray);
          corResults[1][i] = pCorrelation.correlation(yHeadArray, yTargetArray);
          correlData+="T"+i+"Correls," + corResults[0][i] + ", " + corResults[1][i] + ", ";
          //println(correlData);
          }
        catch (Exception e)
          {
          println("Correlation exception: ", xHeadArray.length +":"+ xTargetArray.length, yHeadArray.length +":"+ yTargetArray.length); 
          }
        }
      }

    // pick a winner and return it
    int winner = checkCorrelations(corResults);

    // update the duration
    duration               = millis()-duration;
    //println("Correl calc duration: " + duration);
    return winner;
  }





  int checkCorrelations(double[][] xyList) 
  {
    return checkCorrelationsCombi(xyList);
  }


 





  // Correlates the user's pursuits with several objects' trajectories.
  // the correlations come in as a list of correlation with x trajectories (xyList[0]) and a similar list for y (xyList[1]) 
  int checkCorrelationsCombi(double[][] xyList) 
  {
    // see discussion at top of sketch, but we expect <<yaw neg to x>> and <<pitch pos to y>> 
    int numberCombWinners =  0; 

    // got to have two channels of data
    if (xyList.length!=2)
      return -1;

    String all = ""; 
    ArrayList<Integer> winners = new ArrayList<Integer>(); 
    for (int i=0; i<xyList[0].length; i++)
    {
      all += xyList[0][i] +","+ xyList[1][i] +";";

      if (xyList[0][i]<-correlThreshold && xyList[1][i]>correlThreshold) // neg and pos
        winners.add(i);

      if (xyList[1][i] - xyList[0][i] > correlThreshold*2)
        numberCombWinners++;
    }

    if (numberCombWinners>1) // more than one target where the two axes combine to > double the correl threshold
    {
      //  print("\n" + numberCombWinners + " combi winners: "); 
      //  println(all); 
      return -3;
    } else if (winners.size()==1) // one winner where each axis beats the correl threshold
    {
      //println("\nClear winner: " + winners.get(0));  
      //println(all); 
      return winners.get(0);
    } else if (winners.size()>1) // several winners - cannot occur because we return if we have >1 combi winner.
    {
      print("\nERROR - " + winners.size() + " possible winners (should be impossible): ");
      for (int i=0; i<winners.size(); i++)
        print(winners.get(i) + " ");
      println("\n" + all); 
      return -2;
    }

    return -1; // nothing to report at the moment
  }
  
  
    double[] getArrayListRangeFloat(ArrayList<Float> data, int startIndex, int stopIndex)
  {
    if (startIndex>=0 && stopIndex<=data.size())
    {
      double[] out = new double[stopIndex - startIndex];
      for (int i=startIndex; i<stopIndex; i++)
        out[i - startIndex] = data.get(i); 
      return out;
    }
    return null;
  }
}