
// this calculates what targets to show/hide depending where you are looking
boolean[] showHideTargets(boolean printMe)
  {
  boolean[] enabled = new boolean[TARGET_NUM]; // which targets are on and which are off!
  for (int i=0;i<TARGET_NUM;i++)
    enabled[i] = true; // all on by default
    
  // choose which targets are active - only implemented for 8 targets
  if (APPLY_GAZE && TARGET_NUM==8)
    {
    float[] dists = new float[spinsCW.getSize()]; 
    // println(cursor_pos.x, cursor_pos.y, spinsCW.getSpinner(0).getScreenCoords().x, spinsCW.getSpinner(0).getScreenCoords().y);
      
    for (int i = 0; i < spinsCW.getSize(); i++) 
      {
      PVector c = spinsCW.getSpinner(i).getScreenCoords();
      dists[i] = dist(c.x, c.y, cursor_pos.x, cursor_pos.y);
      }
     
    //printArray(dists);  
      
    float max=-1;
    int maxIndexCW = -1;
    for  (int i = 0; i < spinsCW.getSize(); i++) 
      {
      if (dists[i]>max)
        {
        max = dists[i];
        maxIndexCW = i; 
        }
      }
      
      
    dists[maxIndexCW]=-1;
    max=-1;
    int maxIndexCW2 = -1;  
    for  (int i = 0; i < spinsCW.getSize(); i++) 
      {
      if (dists[i]>max)
        {
        max = dists[i];
        maxIndexCW2 = i; 
        }
      }
      
    for (int i = 0; i < spinsCW.getSize(); i++) 
      {
      if (i==maxIndexCW || i==maxIndexCW2)
        spinsCW.getSpinner(i).disable(); 
      else 
        spinsCW.getSpinner(i).enable(); 
        
      enabled[i] = spinsCW.getSpinner(i).isEnabled();
      }
      
      
    for (int i = 0; i < spinsCCW.getSize(); i++) 
      {
      PVector c = spinsCCW.getSpinner(i).getScreenCoords();
      dists[i] = dist(c.x, c.y, cursor_pos.x, cursor_pos.y);
      }
      
    max=-1;
    int maxIndexCCW = -1;
    for  (int i = 0; i < spinsCCW.getSize(); i++) 
      {
      if (dists[i]>max)
        {
        max = dists[i];
        maxIndexCCW = i; 
        }
      }
      
      
    dists[maxIndexCCW]=-1;
    max=-1;
    int maxIndexCCW2 = -1;  
    for  (int i = 0; i < spinsCCW.getSize(); i++) 
      {
      if (dists[i]>max)
        {
        max = dists[i];
        maxIndexCCW2 = i; 
        }
      }

    for  (int i = 0; i < spinsCCW.getSize(); i++) 
      {
      if (i==maxIndexCCW || i==maxIndexCCW2)
        spinsCCW.getSpinner(i).disable(); 
      else 
        spinsCCW.getSpinner(i).enable(); 
        
      enabled[i + spinsCW.getSize()] = spinsCCW.getSpinner(i).isEnabled();
      }
    }
  else
    {
    for  (int i = 0; i < spinsCW.getSize(); i++) 
      spinsCW.getSpinner(i).enable(); 
    for  (int i = 0; i < spinsCCW.getSize(); i++) 
      spinsCCW.getSpinner(i).enable(); 
    }
  
  if (printMe)
    {
    String s = "Enabled: ";
    for (int i=0;i<enabled.length;i++)
      s+=enabled[i] + " ";
    println(s);
    }
  return enabled; 
  }
  
  
void adjustTargets()
  {
  if (APPLY_GAZE && TARGET_NUM==8) // if the targets are just 8 and we are using gaze to turn them on and off
    {
    // set the opposing targets to matching positions.  
    printTargetsStarts("Pre"); 
    spinsCW. getSpinner(3).setStartPos(spinsCW. getSpinner(0).getStartPos());  
    spinsCW. getSpinner(1).setStartPos(spinsCW. getSpinner(2).getStartPos());  
    spinsCCW.getSpinner(3).setStartPos(spinsCCW.getSpinner(0).getStartPos());  
    spinsCCW.getSpinner(1).setStartPos(spinsCCW.getSpinner(2).getStartPos());   
    targetsReset(); 
    println("Adjusting targets to an overlapping configuration"); 
    printTargetsStarts("Post"); 
    }
  }
  
  
void printTargetsStarts(String header)
  {
  String s = header + ": ";
  for (int i=0;i<spinsCW.getSize();i++)
    s += spinsCW.getSpinner(i).getStartPos() + " ";
  s+=", ";  
  for (int i=0;i<spinsCCW.getSize();i++)
    s += spinsCCW.getSpinner(i).getStartPos() + " ";
  println(s);
  }