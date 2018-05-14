final float TARGET_SIZE  = 40;                   // target diam.
final float tSpace       = 62.5 + TARGET_SIZE/2; // gap from the edge?
final float halfScreen   = 200;                  // screen is 400x400
final float fullScreen   = 400;                  // screen is 400x400
float[] xTargets = {tSpace, halfScreen, fullScreen-tSpace, tSpace, fullScreen-tSpace, tSpace, halfScreen, fullScreen-tSpace};
float[] yTargets = {tSpace, tSpace, tSpace, halfScreen, halfScreen, fullScreen-tSpace, fullScreen-tSpace, fullScreen-tSpace};


// match indexes 
// specifically 2,3 - 6,7 - 10,11 - 14,15 - 18,19 - 22,23 - 26,27 - 30,31 then, out of pattern 33,34 - 36,37
int getIndex(float in)
{
  int mod = 0;
  if (in>=19)
    mod = -2;
  else if (in>=17)
    mod = -2;
  if (in%2==0) 
    return (int)(2+in*2) + mod; 
  else 
  return (int)(2+in*2-1.0) + mod;
}


float getCorrel(float[] one, float[] two)
{
  // prepare to run correlations
  double[] oneD = new double[one.length];
  double[] twoD = new double[two.length];
  for (int i=0; i<one.length; i++) oneD[i] = one[i];
  for (int i=0; i<two.length; i++) twoD[i] = two[i];
  PearsonsCorrelation pCorrelation = new PearsonsCorrelation();
  return (float)pCorrelation.correlation(oneD, twoD);
}


void chooseColor(int i, int t, boolean x)
{
  strokeWeight(5); 
  if (i==t)
  {
    if (x)
      stroke(255, 0, 0);
    else
      stroke(0, 255, 0);
  } else
    stroke (255*i/8);
}

void processTrialData(ArrayList<String> trialData)
{
  // read in the last one second of data
  long endTime = Long.parseLong(trialData.get(trialData.size()-2).substring(0, trialData.get(trialData.size()-2).indexOf(',')));
  int oneSecondMark = trialData.size()-3;
  while (oneSecondMark>0 && endTime-Long.parseLong(trialData.get(oneSecondMark).substring(0, trialData.get(oneSecondMark).indexOf(',')))<1000)
    oneSecondMark--; 
  int totalRange = trialData.size()-oneSecondMark-1;  

  // load the thing into a string...
  String[] data = new String[totalRange]; 
  for (int i=0; i<totalRange; i++)
    data[totalRange-1-i] = new String(trialData.get(i+oneSecondMark)); //copy it inverted.

  // print of the angle where the correlation triggered and get the target number 
  int   blockNumber  = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[1]);
  int   trialNumber  = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[2]);
  int   targetNumber = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[3]);
  int   totalTime = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[6]);

  int winner = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[5]);
  
  int timeover;
  boolean checkTimeover = false;
  if (winner >7) {
    //Timeover -> winner == 99
    timeover = winner;
    winner = 1;
    checkTimeover = true;
  }
  float winnerstartX = Float.parseFloat(split(trialData.get(1), ",")[getIndex(winner*2)  ]);
  float winnerstartY = Float.parseFloat(split(trialData.get(1), ",")[getIndex(winner*2+1)]);
  float winnerstartAngle = atan2(winnerstartY-yTargets[winner], winnerstartX-xTargets[winner]);

  float triggerX = Float.parseFloat(split(trialData.get(trialData.size()-2), ",")[getIndex(targetNumber*2)  ]);
  float triggerY = Float.parseFloat(split(trialData.get(trialData.size()-2), ",")[getIndex(targetNumber*2)+1]);
  float triggerAngle = atan2(triggerY-yTargets[targetNumber], triggerX-xTargets[targetNumber]);
  float startX = Float.parseFloat(split(trialData.get(1), ",")[getIndex(targetNumber*2)  ]);
  float startY = Float.parseFloat(split(trialData.get(1), ",")[getIndex(targetNumber*2+1)]);
  float startAngle = atan2(startY-yTargets[targetNumber], startX-xTargets[targetNumber]);

  float CorStartX = Float.parseFloat(split(trialData.get(oneSecondMark), ",")[getIndex(targetNumber*2)  ]);
  float CorStartY = Float.parseFloat(split(trialData.get(oneSecondMark), ",")[getIndex(targetNumber*2)+1]);
  float CorStartAngle = atan2(CorStartY-yTargets[targetNumber], CorStartX-xTargets[targetNumber]);
  // println(targetNumber, triggerX, triggerY, degrees(triggerAngle));


  // fill individual arrays with data
  int numberTargets  = 8; 
  int numDataStreams = numberTargets*2 + 4; // (8 targets + plus 1 cursor + plus 1 head) times 2 
  float[][] dataD = new float[numDataStreams][totalRange];
  for (int i=0; i<totalRange; i++)
  {
    String[] parts = trialData.get(i+oneSecondMark).split(",");
    for (int j=0; j<numDataStreams; j++)
      dataD[j][totalRange-1-i] = Float.parseFloat(trim(parts[getIndex(j)]));
  }

  int minLen     = 10;
  //println(trialData.get(0)); 
  while (dataD[0].length>minLen)
  {
    // process the correlations
    //println(dataD[0].length, trialData.get(0));
    for (int i=0; i<numberTargets; i++)
    {
      float xResult = getCorrel(dataD[  (i*2)], dataD[18]);
      float yResult = getCorrel(dataD[1+(i*2)], dataD[19]);
      //println(xResult, yResult);
      // we want to chart this somehow - on a trial by trial basis? Some aggregate?  
      if (blockNumber==bNum && trialNumber==tNum)
      {
        //println(xResult, yResult);
        if (showAll || (targetNumber==i))
        {
          strokeWeight(1);          // guideline
          stroke(0, 255, 0);
          //line(0, height-40, halfScreen, height-40);
          strokeWeight(1);
          stroke(255, 0, 0);
          //line(0, height-360, halfScreen, height-360);
          stroke(0);
          line(width/2, 0, width/2, height);
          line(0, height/2, width, height/2);

          textSize(11);
          text('x', 10, height-40);
          text('y', 10, 40);

          chooseColor(i, targetNumber, true); 
          point(map(dataD[0].length, minLen, totalRange, 25, width-25), map(xResult, -1, 1, 40, height-40));
          textSize(8);
          text(i, map(dataD[0].length, minLen, totalRange, 25, width-25), map(xResult, -1, 1, 40, height-40)-5);
          chooseColor(i, targetNumber, false);
          rectMode(CENTER);
          rect(map(dataD[0].length, minLen, totalRange, 25, width-25), map(yResult, -1, 1, 40, height-40), 1, 1);
          text(i, map(dataD[0].length, minLen, totalRange, 25, width-25), map(yResult, -1, 1, 40, height-40)-5);
        }
        //println(i, xResult); 
        if (targetNumber==i && dataD[0].length==minLen+1)
        {
          fill(0);
          textSize(15);
          text("trigger angle: " + degrees(triggerAngle), width/2, height-15);
          text("start angle: "+degrees(startAngle), width/2, height-30);
          text("total time: " + totalTime, width/2, height-45);
          text("CorStart angle: " + degrees(CorStartAngle), width/2, height-60);
          if(checkTimeover){
          textSize(30);
          text("TIME OVER", halfScreen, halfScreen);  
          checkTimeover = false;
          }
        }
      }
    }

    // try to shorten by one sample -  this removes the earliest sample because we logged it backwards... 
    for (int i=0; i<numDataStreams; i++)
      dataD[i] = shorten(dataD[i]);
  }

  // draw the path used in the final correlation
  if (blockNumber==bNum && trialNumber==tNum)
  {
    float lastX = -1;
    float lastY = -1;
    float lastXT = -1;
    float lastYT = -1;
    float lastXC = -1;
    float lastYC = -1;
    float lastXT_Center = -1;
    float lastYT_Center = -1; 

    float lastwinnerX = -1;
    float lastwinnerY = -1;
    stroke(0, 0, 255);

    // draw the target location
    fill(128, 128);
    noStroke(); 
    ellipse(xTargets[targetNumber], yTargets[targetNumber], TARGET_SIZE, TARGET_SIZE);
    stroke(0);
    strokeWeight(1);
    line(xTargets[targetNumber]-TARGET_SIZE, yTargets[targetNumber], xTargets[targetNumber]+TARGET_SIZE, yTargets[targetNumber]);
    line(xTargets[targetNumber], yTargets[targetNumber]+TARGET_SIZE, xTargets[targetNumber], yTargets[targetNumber]-TARGET_SIZE);

    int startPoint  = oneSecondMark;
    if (showAllMotion) startPoint = 1;
    int lineSize = 10;
    for (int i=startPoint; i<trialData.size()-1; i++)
    { 
      String[] parts = split(trialData.get(i), ",");
      float x = map(Float.parseFloat(trim(parts[36])), 10, -10, width/5, width -width /5);
      float y = map(Float.parseFloat(trim(parts[37])), -10, 10, height/5, height-height/5);

      // -- orbiting direction seems inverted. changed

      // plot target data - invert x to match the correls
      float xT_Center = map(Float.parseFloat(trim(parts[getIndex(targetNumber*2)  ])), xTargets[targetNumber]-TARGET_SIZE, xTargets[targetNumber]+TARGET_SIZE, width/5, width -width /5);
      float yT_Center = map(Float.parseFloat(trim(parts[getIndex(targetNumber*2+1)])), yTargets[targetNumber]-TARGET_SIZE, yTargets[targetNumber]+TARGET_SIZE, height/5, height-height/5);
      float xT = Float.parseFloat(trim(parts[getIndex(targetNumber*2)  ]));
      float yT = Float.parseFloat(trim(parts[getIndex(targetNumber*2+1)  ]));

      float winnerX = Float.parseFloat(trim(parts[getIndex(winner*2)  ]));
      float winnerY = Float.parseFloat(trim(parts[getIndex(winner*2+1)  ]));

      // plot cursor data
      float xC = map(Float.parseFloat(trim(parts[33])), 0, 400, 0, 400);
      float yC = map(Float.parseFloat(trim(parts[34])), 0, 400, 0, 400);

      if (lineSize<50)
        lineSize++;

      if (lastX!=-1)
      {
        if (winner != targetNumber) {
          if (i == startPoint+1) {
            fill(128, 128);
            noStroke(); 
            ellipse(xTargets[winner], yTargets[winner], TARGET_SIZE, TARGET_SIZE);
            stroke(0);
            strokeWeight(1);
            line(xTargets[winner]-TARGET_SIZE, yTargets[winner], xTargets[winner]+TARGET_SIZE, yTargets[winner]);
            line(xTargets[winner], yTargets[winner]+TARGET_SIZE, xTargets[winner], yTargets[winner]-TARGET_SIZE);
            fill(0);
            textSize(15);
            text("winner angle: " + degrees(winnerstartAngle), width/2, height-75);
          }
          stroke(255, 100, 0);
          strokeWeight(lineSize/10);
          line(lastwinnerX, lastwinnerY, winnerX, winnerY);
        }

        stroke(0, 0, 0);
        strokeWeight(lineSize/5);
        line(lastXT_Center, lastYT_Center, xT_Center, yT_Center);

        stroke(0, 0, 255); 
        line(lastX, lastY, x, y);

        stroke(255, 0, 255); 
        strokeWeight(lineSize/10);
        line(lastXT, lastYT, xT, yT);

        strokeWeight(lineSize/5);
        stroke(0, 255, 255); 
        line(lastXC, lastYC, xC, yC);
      } else
      {
        noFill();
        strokeWeight(3);

        stroke(255, 100, 0);
        ellipse(winnerX, winnerY, 10, 10);
        stroke(0, 0, 0);
        ellipse(xT_Center, yT_Center, 10, 10);
        stroke(0, 0, 255); 
        ellipse(x, y, 10, 10);
        stroke(255, 0, 255);
        ellipse(xT, yT, 5, 5);
        stroke(0, 255, 255);
        ellipse(xC, yC, 10, 10);
      }
      lastX = x;
      lastY = y;
      lastXT= xT;
      lastYT= yT;
      lastXC= xC;
      lastYC= yC;
      lastXT_Center = xT_Center;
      lastYT_Center = yT_Center;
      lastwinnerX = winnerX;
      lastwinnerY = winnerY;
    }
  }

  // if its correct or not...
  if (blockNumber==bNum && trialNumber==tNum)
  {
    fill(255, 0, 0); 
    noStroke(); 
    String s = trialData.get(trialData.size()-1).split(",")[4];
    if (s.equals("true"))
      fill(0, 255, 0);
    ellipse(20, 20, 20, 20);
    //println(s);
  }
  //println(trialData.get(trialData.size()-1).split(",")[4]);
}