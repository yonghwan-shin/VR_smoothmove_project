final float TARGET_SIZE  = 40;                   // target diam.
final float tSpace       = 62.5 + TARGET_SIZE/2; // gap from the edge?
final float halfScreen   = 200;                  // screen is 400x400
final float fullScreen   = 400;                  // screen is 400x400

float[] xTargets = {tSpace, halfScreen, fullScreen-tSpace, tSpace, fullScreen-tSpace, tSpace, halfScreen, fullScreen-tSpace};
float[] yTargets = {tSpace, tSpace, tSpace, halfScreen, halfScreen, fullScreen-tSpace, fullScreen-tSpace, fullScreen-tSpace};
// match indexes 

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
  long endTime = Long.parseLong(trialData.get(trialData.size()-2).substring(0, trialData.get(trialData.size()-2).indexOf(',')));
  int   blockNumber  = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[1]);
  int   trialNumber  = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[2]);
  int   targetNumber = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[3]);
  int   totalTime = Integer.parseInt(split(trialData.get(trialData.size()-1), ",")[5]);
  //println(endTime);
  float realdata[][] = new float[2][trialData.size()];

  for (int i = 1; i<trialData.size()-1; i++) {
    String[] parts = trialData.get(i).split(",");
    realdata[0][i] = Float.parseFloat(trim(parts[2]));
    realdata[1][i] = Float.parseFloat(trim(parts[3]));
  }


  //int minLen = 10;
  //while(realdata[0].length>minLen){
  //  for(int i=0; i<8;i++){
  //   if(blockNumber == bNum && trialNumber == tNum){
  //     if(showAll || (targetNumber == i)){

  //     }
  //   }
  //  }
  //}

  if (blockNumber == bNum && trialNumber == tNum) {
    for (int i =1; i<trialData.size()-1; i++) {

      String[] parts = split(trialData.get(i), ",");
      float X = Float.parseFloat(trim(parts[2]));
      float Y = Float.parseFloat(trim(parts[3]));

      // target guide
      noFill();
      strokeWeight(1);
      for (int j = 0; j<8; j++) {
        if (j==targetNumber) {
          stroke(255, 0, 0);
        } else {
          stroke(0);
        }
        ellipse(xTargets[j], yTargets[j], TARGET_SIZE, TARGET_SIZE);
      }

      // cursor pathway
      strokeWeight(3);
      float center_X = map(X, xTargets[targetNumber]-TARGET_SIZE/2, xTargets[targetNumber]+TARGET_SIZE/2, halfScreen-TARGET_SIZE*2, halfScreen+TARGET_SIZE*2);
      float center_Y = map(Y, yTargets[targetNumber]-TARGET_SIZE/2, yTargets[targetNumber]+TARGET_SIZE/2, halfScreen-TARGET_SIZE*2, halfScreen+TARGET_SIZE*2);
      if (dist(xTargets[targetNumber], yTargets[targetNumber], X, Y)<=TARGET_SIZE/2) {
        if (showAll) {
          stroke(255,0,0);
          point(center_X, center_Y);
          stroke(0);
          ellipse(halfScreen,halfScreen,TARGET_SIZE*4,TARGET_SIZE*4);
        }
        stroke(0, 0, 255);
      } else {
        stroke(0);
      }
      point(X, Y);


      //  ADD  endtime & firt in time

      textSize(15);
      text("total time: "+ totalTime, width/2, height-45);
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