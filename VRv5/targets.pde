ArrayList<Target> targets;                 // data about target locations
Target centreMenuTarget;                   // center target

int CENTER_TARGET_NUMBER = TARGET_NUM;     // will be 1 greater than max target index. 

/*
 * Init the targets - setup location, etc. 
 */
void targetsInit()
{
  targets      = new ArrayList<Target>(TARGET_NUM);
  float tSpace = 62.5 + TARGET_SIZE/2;      // (sceneSize - 3xTARGET_SIZE) / 4

  centreMenuTarget = new Target(-1, SCENE_SIZE/2, SCENE_SIZE/2, 0, 1, TARGET_SIZE/2);      // centre target, displaying in menus
  int rand_start = (int)random(360);
  // Top (left to right)
  targets.add(new Target(0, tSpace, tSpace, rand_start+0, 1, TARGET_SIZE));     // top left
  targets.add(new Target(1, SCENE_SIZE/2, tSpace, rand_start+0, -1, TARGET_SIZE));     // top middle
  targets.add(new Target(0, SCENE_SIZE-tSpace, tSpace, rand_start+90, 1, TARGET_SIZE));     // top right

  // Middle (left to right)
  targets.add(new Target(1, tSpace, SCENE_SIZE/2, rand_start+90, -1, TARGET_SIZE));     // middle left
  targets.add(new Target(1, SCENE_SIZE-tSpace, SCENE_SIZE/2, rand_start+180, -1, TARGET_SIZE));     // middle right

  // Bottom (left to right)
  targets.add(new Target(0, tSpace, SCENE_SIZE-tSpace, rand_start+180, 1, TARGET_SIZE));     // bottom left
  targets.add(new Target(1, SCENE_SIZE/2, SCENE_SIZE-tSpace, rand_start+270, -1, TARGET_SIZE));     // bottom middle
  targets.add(new Target(0, SCENE_SIZE-tSpace, SCENE_SIZE-tSpace, rand_start+270, 1, TARGET_SIZE));     // bottom right
}

void targetsReset()
  {
  // Reset head/target data arrays, and each orbit to their original positions
  int orbitResetConstant = (int)random(360);
  for (Target target : targets) target.resetOrbit(orbitResetConstant);
  }


/*
 * Check if the cursor is over a target, and store which (if any)
 */
boolean checkCursorHover(long now) 
  {
  boolean new_target = false;
  int new_target_num = -1;
  
  for (int i = 0; i < TARGET_NUM; i++) 
    {
    if (((Target)targets.get(i)).cursorOver(cursor_pos.x, cursor_pos.y)) {
      new_target = true;
      new_target_num = i;
      
      // log details if we have a change and are in a trial
      if (mode==MODE_TRIAL && new_target && !over_target)
        {
        over_target = true; 
        over_target_num = new_target_num;
        in_count[over_target_num]++;
        in_time[over_target_num][in_count[over_target_num]++] = now;
        return true; // new target acquired. 
        } 
      return false; // not important
      }
    }

  // no target at all
  if (mode==MODE_TRIAL && !new_target && over_target)
    {
    out_count[over_target_num]++;
    out_time[over_target_num][out_count[over_target_num]++] = now;
    }
  over_target_num = -1;
  over_target = false;
  return false;
  }