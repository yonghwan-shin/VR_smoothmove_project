/*
 * Run the correlations - check for performance problems. 
 */
public class Correlator
{
  PearsonsCorrelation pCorrelation;            // the correlation math object

  int numTargets;         // how many targets we are dealing with
  int windowSize;         // how many screen samples in a correlation window
  float screenFrameRate;  // how many screen updates per second...
  long sampleDuration;    // how long one window size is - basically how long is windowSize in terms of of the screenFrameRate 
  double correlThreshold; // correlation threshold to trigger selection

  double[][] corResults;  // the results of the coorelation - so we can check raw data....

  String[] correlData;    // this is the raw data used to compute the correlation matrix (useful for checks/debugging)

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
  public Correlator(int _numTargets, int _windowSize, float _correlThreshold, float _screenFrameRate)
  {
    pCorrelation = new PearsonsCorrelation();
    adjustParameters(_numTargets, _windowSize, _correlThreshold, _screenFrameRate);
  }

  public void adjustParameters(int _numTargets, int _windowSize, double _correlThreshold, float _screenFrameRate)
  {
    numTargets      = _numTargets;
    correlThreshold = _correlThreshold; 
    windowSize      = _windowSize;
    screenFrameRate = _screenFrameRate; 
    sampleDuration = (long)(((float)windowSize/(float)screenFrameRate)*1000.0);
  }

  public void adjustParameters(int _numTargets, int _windowSize, float _correlThreshold, float _screenFrameRate)
  {
    numTargets      = _numTargets;
    correlThreshold = _correlThreshold; 
    windowSize      = _windowSize;
    screenFrameRate = _screenFrameRate; 
    sampleDuration = (long)(((float)windowSize/(float)screenFrameRate)*1000.0);
  }


  // adjust sizes/thresholds
  public void setNumTargets          (int _numTargets) { 
    numTargets = _numTargets;
  }

  public void setCorrelationThreshold(double _correlThreshold) { 
    correlThreshold = _correlThreshold;
  }  

  public void setWindowSize          (int _windowSize) { 
    adjustParameters(numTargets, _windowSize, correlThreshold, screenFrameRate);
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


  // utility to unbox and convert an arraylist into an array of doubles
  // takes the this.windowSize last items.
  double[] convertTail(ArrayList<Float> in)
  {
    double[] ret = new double[windowSize];
    //int finalSize = in.size();
    int count = 0; 
    //for (int i = finalSize-windowSize; i < finalSize; i++)
    int finalMod = in.size()-windowSize;
    for (int i = 0; i < windowSize; i++)
    {
      try {
        ret[i] = in.get(i+finalMod);
      }
      catch (ArrayIndexOutOfBoundsException e) {
        println("convertTail oob: " + ret.length, count, i, in);
      }
      count++;
    }
    return ret;
  }


  // utility to unbox and convert an arraylist into an array of doubles
  // takes the this.windowSize last items.
  long[] convertTailLong(ArrayList<Long> in)
  {
    long[] ret = new long[windowSize];
    //int finalSize = in.size();
    int count = 0; 
    //for (int i = finalSize-windowSize; i < finalSize; i++)
    int finalMod = in.size()-windowSize;
    for (int i = 0; i < windowSize; i++)
    {
      try {
        ret[i] = in.get(i+finalMod);
      }
      catch (ArrayIndexOutOfBoundsException e) {
        println("convertTail oob: " + ret.length, count, i, in);
      }
      count++;
    }
    return ret;
  }

  // xHead and yHead come as separate arrayLists, whereas targets are all bunched together. 
  public int batchMatch_resample(ArrayList<Long> timeHead, ArrayList<Float> xHead, ArrayList<Float> yHead, 
    ArrayList<Long> timeTargets, ArrayList<ArrayList<Float>> targetXs, ArrayList<ArrayList<Float>> targetYs)
  {
    duration = millis(); 

    // check is we have any data 
    if (timeHead==null || timeHead.size()==0 || timeTargets==null || timeTargets.size()==0)
      return -1; // if not, just fail

    // mark the end points we are dealing with
    int headSize    = timeHead.size();  
    int targetsSize = timeTargets.size();

    long sampleDuration = (long)(((float)windowSize/(float)screenFrameRate)*1000.0); 

    // get the head array for data for the sampleDuration window. 
    int headStartIndex = headSize-1;
    long headEndTime   = timeHead.get(headStartIndex); 
    long headStartTime = headEndTime;
    while (headStartIndex>0 && headEndTime-headStartTime < sampleDuration)
    {
      headStartIndex--;
      headStartTime   = timeHead.get(headStartIndex);
    }
    if (headStartIndex<0)
      return -2; // not enough data in the head sample. 

    // box the data in arrays
    xHeadArray     = getArrayListRangeFloat(xHead, headStartIndex, headSize);
    yHeadArray     = getArrayListRangeFloat(yHead, headStartIndex, headSize);
    timeHeadArray  = getArrayListRangeLong (timeHead, headStartIndex, headSize);
    if (xHeadArray==null || yHeadArray==null || timeHeadArray==null)
      return -3;
    // now we have one sampleDuration of head data. 

    // check it exceeds a threshold - this looks like a pretty slow way to do this calc... 
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


    // now get data about the targets. 
    // get the target array of data for the sampleDuration window. 
    int targetsStartIndex = targetsSize-1;
    long targetsEndTime   = timeTargets.get(targetsStartIndex); 
    long targetsStartTime = targetsEndTime;
    while (targetsStartIndex>0 && targetsEndTime-targetsStartTime < sampleDuration)
    {
      targetsStartIndex--;
      targetsStartTime   = timeTargets.get(targetsStartIndex);
    }
    if (targetsStartIndex<0) // check there's space for one more step back. WHY? REMOVED.
    {
      //println(targetsEndTime, targetsStartTime, sampleDuration, targetsStartIndex); 
      return -5; // not enough data in the target sample.
    }

    timeTargetsArray  = getArrayListRangeLong(timeTargets, targetsStartIndex, targetsSize);      
    if (timeTargetsArray==null)
      return -6;

    // a class variable to store the correlation of head with all targets
    corResults = new double[2][numTargets]; 

    // zero both of the time arrays - this will between 0 and 1 sample of noise
    long sub = timeHeadArray[0]; 
    for (int i=0; i<timeHeadArray.length; i++)
    {
      timeHeadArray[i] -= sub; 
      //print (timeHeadArray[i] + ",");
    }
    //println("--" +timeHeadArray.length+ "--");

    sub = timeTargetsArray[0];
    for (int i=0; i<timeTargetsArray.length; i++)
    {
      timeTargetsArray[i] -= sub;
      //print (timeTargetsArray[i] + ",");
    }
    //println("$$" +timeTargetsArray.length+ "$$");


    // here we run all the correlations.... should store this somehow. 
    correlData = new String[xHeadArray.length];
    for (int i=0; i<numTargets; i++)
    {
      // get the last windowSize items
      double[] xTargetArray = getArrayListRangeFloat(targetXs.get(i), targetsStartIndex, targetsSize);
      double[] yTargetArray = getArrayListRangeFloat(targetYs.get(i), targetsStartIndex, targetsSize);

      // resample the target arrays to the size of the sensor array - this works well because the targets
      // move basically linearly. The other option (to resample the head motion) would be more efficient
      // as it could be done once for each round. 
      xTargetArray = reSample(xTargetArray, timeTargetsArray, timeHeadArray);
      yTargetArray = reSample(yTargetArray, timeTargetsArray, timeHeadArray);

      // run and store the correlation 
      if (xHeadArray!=null && xTargetArray!=null)
        corResults[0][i] = pCorrelation.correlation(xHeadArray, xTargetArray);
      else
        println("xcorrels are null");

      if (yHeadArray!=null && yTargetArray!=null)
        corResults[1][i] = pCorrelation.correlation(yHeadArray, yTargetArray);
      else
        println("ycorrels are null");

      /* 
       * This is for logging (optional). Its a full list of the data we run the correls on. Can use it to check fail cases.  
       */
      if (i==0)
        for (int a=0; a<xHeadArray.length; a++)
          correlData[a] = xHeadArray[a] + "," + yHeadArray[a] +",";
      // append on the sensor data
      for (int a=0; a<xHeadArray.length; a++) // should be same length as target arrays...
      {
        correlData[a] += xTargetArray[a] + "," + yTargetArray[a]; 
        if (i<numTargets-1)
          correlData[a] += ",";
      }
    }

    // pick a winner and return it
    int winner = checkCorrelations(corResults);

    // update the duration
    duration = millis()-duration;
    println("Correl calc duration: " + duration);
    return winner;
  }





  int checkCorrelations(double[][] xyList) 
  {
    return checkCorrelationsCombi(xyList);
  }


  // Correlates the user's pursuits with several objects' trajectories.
  // the correlations come in as a list of correlation with x trajectories (xyList[0]) and a similar list for y (xyList[1]) 
  // this strict version requires 
  //   1) both individual correlations to be above threshold
  //   2) there to be no other targets in this situation. 
  int checkCorrelationsStrict(double[][] xyList) 
  {
    // see discussion at top of sketch, but we expect <<yaw neg to x>> and <<pitch pos to y>>

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
    }

    if (winners.size()==1)
    {
      //println("Clear winner: " + winners.get(0));  
      println(all + "\n"); 
      return winners.get(0);
    } else if (winners.size()>1)
    {
      print(winners.size() + " possible winners: ");
      for (int i=0; i<winners.size(); i++)
        print(winners.get(i) + " ");
      println("\n" + all + "\n"); 
      return -2;
    }

    return -1; // nothing to report at the moment
  }





  // Correlates the user's pursuits with several objects' trajectories.
  // the correlations come in as a list of correlation with x trajectories (xyList[0]) and a similar list for y (xyList[1]) 
  int checkCorrelationsOrg(double[][] xyList) 
  {
    // see discussion at top of sketch, but we expect <<yaw neg to x>> and <<pitch pos to y>>
    double lowestCorrelX      =  1;
    double highestCorrelY     = -1;
    int lowestIndexX          = -1;
    int highestIndexY         = -1;

    int numberCombWinners     =  0; 

    // got to have two channels of data
    if (xyList.length!=2)
      return -1;

    String all = ""; 
    for (int i=0; i<xyList[0].length; i++)
    {
      all += xyList[0][i] +","+ xyList[1][i] +";";

      if (xyList[0][i]<lowestCorrelX) // neg
      {
        lowestCorrelX = xyList[0][i];
        lowestIndexX  = i;
      }

      if (xyList[1][i]>highestCorrelY) // pos 
      {
        highestCorrelY = xyList[1][i];
        highestIndexY  = i;
      }

      if (xyList[1][i] - xyList[0][i] > correlThreshold*2)
        numberCombWinners++;
    }

    if (numberCombWinners>1) // if we have more than one option?
    {
      //  println("WARNING: " +numberCombWinners +" pairs over mean threshold. Give up.");
      //  println("The best two.", lowestIndexX, lowestCorrelX, xyList[1][lowestIndexX], " -- ", highestIndexY, xyList[0][highestIndexY], highestCorrelY);
      //  println("All:" +  all);
      return -2; // confused.
    }

    if (lowestIndexX == highestIndexY) // we agree on the best candidate, regardless 
    {
      if (lowestCorrelX<-correlThreshold && highestCorrelY>correlThreshold) // standalone works - this is ideal case
      {
        //   println("RETURNING: both over threshold.");
        return lowestIndexX;
      } else if (lowestCorrelX<0 && highestCorrelY>0 && highestCorrelY-lowestCorrelX > correlThreshold*2) // combined effort is good - only ever happened for target...
      {
        //   println("RETURNING: mean over threshold, but one axes is below", lowestCorrelX, highestCorrelY);
        return lowestIndexX;
      } else 
      return -3; // fail to exceed thresholds when there's only one clear candidate.
    } else  // consider two candidates. Pick the highest aggregate so long as it is above the threshold. Probably not required given prior checks....s
    {
      double xCand = -lowestCorrelX  + xyList[1][lowestIndexX];  // the winning x correl and its losing y partner
      double yCand =  highestCorrelY - xyList[0][highestIndexY]; // the winning y correl and its losing x partner
      if (xCand>yCand)
      {
        if (xCand> correlThreshold*2)
        {
          //    println("RETURNING: two candidates. Picked best.", lowestIndexX, lowestCorrelX, xyList[1][lowestIndexX], " -- ", highestIndexY, xyList[0][highestIndexY], highestCorrelY);  
          return lowestIndexX;
        }
      } else
      {
        if (yCand> correlThreshold*2)
        {
          //     println("RETURNING: two candidates. Picked best.", lowestIndexX, lowestCorrelX, xyList[1][lowestIndexX], " -- ", highestIndexY, xyList[0][highestIndexY], highestCorrelY);   
          return highestIndexY;
        }
      }
      //  println("WARNING: two candidates. Neither good.", lowestIndexX, lowestCorrelX, xyList[1][lowestIndexX], " -- ", highestIndexY, xyList[0][highestIndexY], highestCorrelY);
    }
    return -4;
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
      println("\nClear winner: " + winners.get(0));  
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


  long[] getArrayListRangeLong(ArrayList<Long> data, int startIndex, int stopIndex)
  {
    if (startIndex>=0 && stopIndex<=data.size())
    {
      long[] out = new long[stopIndex - startIndex];
      for (int i=startIndex; i<stopIndex; i++)
        out[i - startIndex] = data.get(i); 
      return out;
    }
    return null;
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


  // take the source data and map it onto the dest data
  // the original sample times for the source and dest are provided
  // simple algorithm assumes a stable sample rate (not true in many cases)
  // better solution would position all the source data at the right moments in destTimes
  // and then intepolate 
  double[] reSample(double[] sourceData, long[] sourceTimes, long[] destTimes)
  {
    if (sourceData==null)
    {
      println("resample: src is null"); 
      return null;
    }
    if (sourceTimes==null)
    {
      println("resample: srcTimes is null");
      return null;
    }
    if (destTimes==null)
    {
      println("resample: destTime is null");  
      return null;
    }

    if (sourceTimes.length!=sourceData.length)
      println("Array size error in resample. WTF. " + sourceTimes.length, sourceData.length);

    if (sourceTimes.length==destTimes.length) // same length, so nothing to do 
      return sourceData;

    // for each item in destTimes, find the two that bracket it temporally in source times
    int sourceCurrent = 0;  
    double[] ret = new double[destTimes.length]; 
    ret[0] = sourceData[0]; // first item is first item
    for (int i=1; i<destTimes.length; i++)
    {
      while (sourceCurrent<sourceTimes.length-1 && sourceTimes[sourceCurrent]<destTimes[i])
        sourceCurrent++;

      if (sourceCurrent>=sourceTimes.length)
      {
        if (i==destTimes.length-1)
          ret[i] = sourceData[sourceData.length-1]; // just use last item here
        else
        {
          println("Resample. Max range problem on " + i + ", " + sourceCurrent);
          ret[i] = sourceData[sourceData.length-1]; // just use last item here, but it likely means one array is a fair bit longer (in terms of time) than the other.
        }
      } else // the item in destTimes is between sourceCurrent-1 and sourceCurrent
      {
        float ratio = (float)(destTimes[i] - sourceTimes[sourceCurrent-1]) / (float)(sourceTimes[sourceCurrent] - sourceTimes[sourceCurrent-1]); 

        try {
          ret[i] = sourceData[sourceCurrent-1] + ((sourceData[sourceCurrent]-sourceData[sourceCurrent-1]) * ratio);
        }
        catch (Exception e)
        {
          println("Resample. Mapping exception. WTF.");
          println(i, sourceCurrent, ret.length, sourceData.length, sourceTimes.length);
        }
      }
    }

    return ret;
  }
}