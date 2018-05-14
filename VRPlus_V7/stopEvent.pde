// here determine if the cursor is moving or not.
float MOVE_THRESHOLD     = 6.0;     // mean + 3SD is 5.917 for first 250ms of a trial in study 1. 
float MOVE_INIT_VALUE    = -10000;  // not possible value for startup
int   MOVE_NUMBER_STOPS  = 3;       // three consectuative stills to trigger a stop

PVector movePosLast = new PVector(MOVE_INIT_VALUE, MOVE_INIT_VALUE);                
                                    // the last recorded position           
long    moveTimeLast;               // the last recorded time
int     moveCount;                  // the number of samples in a row, we've 
boolean moveReachedMax = false;     // whether we hit MOVE_NUMBER_STOPS moving samples

ArrayList<Integer> highlights = new ArrayList<Integer>(); 
ArrayList<Long> highlightTimes = new ArrayList<Long>(); 

boolean isCursorMoving(long now, PVector p)
  {
  float deltaTime = 1000.0 / (float)(now-moveTimeLast);   
  boolean r    = false;
  if (movePosLast.x!=-MOVE_INIT_VALUE && (dist(movePosLast.x, movePosLast.y, p.x, p.y) * deltaTime) > MOVE_THRESHOLD)
    {
    //println(dist(movePosLast.x, movePosLast.y, p.x, p.y), deltaTime, moveCount);
    r = true;
    }
  movePosLast  = p; 
  moveTimeLast = now; 
  return r; 
  }

// here determine is we have a stop event
// we look to see if the velocity is below the threshold
// we might also take into account the number of times it is below the threshold (e.g. not decide immediately)
int stopEvent(long now, PVector p, int highlight)
  {  
  // if we are moving, increase moveCount up to a max  
  if (isCursorMoving(now, p)) 
    moveCount = min(moveCount+1, MOVE_NUMBER_STOPS); 
  // else decrease until it is -1
  else if (moveCount>-1)
    moveCount = max(-1, moveCount-1);
    
  if (highlight>=0)
    {
    // add the current target to the temporal list of selected items - basically a list of all the selected items over the course of a trial. 
    highlightTimes.add(now); 
    highlights.add(highlight); 
    }
    
  // check we hit MOVE_NUMBER_STOPS movement trials  
  if (moveCount>=MOVE_NUMBER_STOPS)
    moveReachedMax = true;
    
  // if no movement, and previously there was MOVE_NUMBER_STOPS in a row (actually twice that)
  if (moveCount==0 && moveReachedMax)
    {
    moveReachedMax = false;
    // determine which of the most recent stops we care about
    // take the mode from the last MOMA_STOP_TO_SELECTms
    int[] counts = new int[TARGET_NUM];
    for (int j=0;j<TARGET_NUM;j++)
      counts[j] = 0;
      
    int i=highlightTimes.size()-1;
    while (i>=0 && highlightTimes.get(i)>now-MOMA_STOP_TO_SELECT)
      {
      counts[highlights.get(i)]++;
      i--;
      }
      
    int indexMax = -1;
    int valueMax = 0;
    for (int j=0;j<TARGET_NUM;j++)
      {
      if (counts[j]>valueMax) // if equal, use first one - this is earliest item in the list, so its best choice....
        {
        valueMax = counts[j];
        indexMax = j;
        }
      }
    
    highlights = new ArrayList<Integer>(); 
    highlightTimes = new ArrayList<Long>(); 
    println("Return mode of " + indexMax, now); 
    if (indexMax == -1)
      {
      print(now + " ");
      print(highlightTimes.size() + " ");
      if (highlightTimes.size()>0) print(highlightTimes.get(highlightTimes.size()-1) + " ");
      print(highlights.size() + " ");
      if (highlights.size()>0) print(highlights.get(highlights.size()-1) + " ");
      println("."); 
      }
    return indexMax;
    }
  return -1; 
  }