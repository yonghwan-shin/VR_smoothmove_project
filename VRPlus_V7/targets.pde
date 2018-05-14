spinners spinsCW ;                        // CW set of spinners
spinners spinsCCW;                        // CCW set of spinners
spinner centreMenuTarget;                 // center target

/*
 * Init the targets - setup location, etc. 
 */
void targetsInit(int tNum)
{
  TARGET_NUM = tNum;
  
  // centre target, displayed between trials
  centreMenuTarget = new spinner(-1, SCENE_SIZE/2, SCENE_SIZE/2, 0, TARGET_SIZE/4, TARGET_SIZE/4);      
  
  spinsCW = new spinners(TARGET_NUM/2);
  spinsCCW = new spinners(TARGET_NUM/2);
  spinsCCW.setCCW();
  
  // turn off the target movements with these commands to see the initial positions clearly. 
  //spinsCW.toggleSpinning();
  //spinsCCW.toggleSpinning();
  if (tNum==16)
    makeSixteenTargets();
  else
    makeEightTargets();
  
  // move to random locations. 
  targetsReset(); 
}



void makeSixteenTargets() // this is a 4x4 grid
  {
  float tSpace = 62.5 + (float)TARGET_SIZE / 2.0;      // tSpace is the gap from the edge
  float iSpace = (SCENE_SIZE - (tSpace*2)) / 3.0;    // iSpace is the inter-target space. 

  // void config(int target_id, float cX, float cY, float spinRadius, float drawRadius)
  spinsCW.spinners.get(0).config (0, tSpace + iSpace*0.0,   tSpace + iSpace*0.0);                         // top left
  spinsCW.spinners.get(1).config (0, tSpace + iSpace*2.0,   tSpace + iSpace*0.0);              // top right
  spinsCW.spinners.get(2).config (0, tSpace + iSpace*0.0,   tSpace + iSpace*1.0);              // bottom left
  spinsCW.spinners.get(3).config (0, tSpace + iSpace*2.0,   tSpace + iSpace*1.0);   // bottom right
  spinsCW.spinners.get(4).config (0, tSpace + iSpace*0.0,   tSpace + iSpace*2.0);                         // top left
  spinsCW.spinners.get(5).config (0, tSpace + iSpace*2.0,   tSpace + iSpace*2.0);              // top right
  spinsCW.spinners.get(6).config (0, tSpace + iSpace*0.0,   tSpace + iSpace*3.0);              // bottom left
  spinsCW.spinners.get(7).config (0, tSpace + iSpace*2.0,   tSpace + iSpace*3.0); 
 
  spinsCCW.spinners.get(0).config(1, tSpace + iSpace*1.0,   tSpace + iSpace*0.0);                   // top middle
  spinsCCW.spinners.get(1).config(1, tSpace + iSpace*3.0,   tSpace + iSpace*0.0);                   // middle left
  spinsCCW.spinners.get(2).config(1, tSpace + iSpace*1.0,   tSpace + iSpace*1.0);        // middle right
  spinsCCW.spinners.get(3).config(1, tSpace + iSpace*3.0,   tSpace + iSpace*1.0);        // bottom middle
  spinsCCW.spinners.get(4).config(1, tSpace + iSpace*1.0,   tSpace + iSpace*2.0);                   // top middle
  spinsCCW.spinners.get(5).config(1, tSpace + iSpace*3.0,   tSpace + iSpace*2.0);        // middle left
  spinsCCW.spinners.get(6).config(1, tSpace + iSpace*1.0,   tSpace + iSpace*3.0);        // middle right
  spinsCCW.spinners.get(7).config(1, tSpace + iSpace*3.0,   tSpace + iSpace*3.0);
  }


void makeEightTargets() // this is a 3x3 grid with the center omitted
  {
  float tSpace = 62.5 + TARGET_SIZE/2;      // (sceneSize - 3xTARGET_SIZE) / 4
  
  // void config(int target_id, float cX, float cY, float spinRadius, float drawRadius)
  spinsCW.spinners.get(0).config (0, tSpace, tSpace);                         // top left
  spinsCW.spinners.get(1).config (0, SCENE_SIZE-tSpace, tSpace);              // top right
  spinsCW.spinners.get(2).config (0, tSpace, SCENE_SIZE-tSpace);              // bottom left
  spinsCW.spinners.get(3).config (0, SCENE_SIZE-tSpace, SCENE_SIZE-tSpace);   // bottom right
 
  spinsCCW.spinners.get(0).config(1, SCENE_SIZE/2, tSpace);                   // top middle
  spinsCCW.spinners.get(1).config(1, tSpace, SCENE_SIZE/2);                   // middle left
  spinsCCW.spinners.get(2).config(1, SCENE_SIZE-tSpace, SCENE_SIZE/2);        // middle right
  spinsCCW.spinners.get(3).config(1, SCENE_SIZE/2, SCENE_SIZE-tSpace);        // bottom middle
  }


void targetsReset()
  {
  // Reset head/target data arrays, and each orbit to their original positions with a random term applied. 
  int orbitResetConstant = (int)random(360);
  spinsCCW.resetOrbits(orbitResetConstant);
  spinsCW.resetOrbits (orbitResetConstant);
  }


/*
 * Check if the cursor is over a target, and store which (if any)
 * Got to check both CW and CCW lists!
 */
boolean checkCursorHover(long now, PVector cursor) 
  {
  // check both lists (only if we don't hover one in the first list)  
  boolean on_target = checkCursorHover(now, spinsCW, 0, cursor);
  if (!on_target)
    on_target = checkCursorHover(now, spinsCCW, spinsCW.getSize(), cursor);
    
  // if not on a target, count the offs.   
  if (!on_target)
    {
    // no target at all
    if (mode==MODE_TRIAL && !on_target && over_target)
      {
      out_count[over_target_num]++;
      if (out_count[over_target_num]<MAX_ON_OFFS)
        out_time[over_target_num][out_count[over_target_num]] = now;
      else
        println("More than "+MAX_ON_OFFS+" over target events; failing to log out events."); 
      }
    // should be in above if?
    over_target_num = -1;
    over_target = false;
    over_target_time = -1; // we are not over a target at all - so no time.
    return false;
    }
    
  return on_target; 
  }
  
  
boolean checkCursorHover(long now, spinners spins, int targetNumOffset, PVector cursor_pos)
  {
  for (int i = 0; i < spins.spinners.size(); i++) 
    {
    if ((spins.spinners.get(i)).cursorOver(cursor_pos.x, cursor_pos.y)) 
      {      
      // log details if we have a change and are in a trial
      if (mode==MODE_TRIAL && !over_target)
        {
        over_target = true; 
        over_target_time = now; 
        over_target_num = i + targetNumOffset;
        
        in_count[over_target_num]++;
        if (in_count[over_target_num]<MAX_ON_OFFS)
          in_time[over_target_num][in_count[over_target_num]] = now;
        else
          println("More than "+MAX_ON_OFFS+" over target events; failing to log in events.");
        } 
      return true;  // over a target (new or existing)
      }
    }
    
  return false;     // not over a target 
  }