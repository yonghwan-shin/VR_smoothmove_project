// look for // VR_SPECIFIC comments to swap back to android/VR

// analyze study 1 for movement speeds prior to selection (mean during the 1000ms windows)
// analyze study 1 for movement speeds after selection (250ms later or duration fixation?)

// 1. stopToSelect
//  1.1. create an invarient measure of angular speed
//  1.2. Continuously process angular speed to determine a stop event - when the speed suddenly drops
//       Treat as another invarient - we only apply selection in MoMa

// 2. phaseShift
//  2.1. Try 1D case - spread out targets with high correlation. 
//  2.2. Needs analysis of what happens with CW and CCW directions - where do the errors occur?
//       Done: no errors between dirs. We can ignore. Should create two sets of spinners rather than targets 

// 3. hoverToActivate
//  3.1. Activate N targets in a radius around the user's cursor. 
//  3.2. How can we do this and still assess the impact of phaseShift?
//       Can do this by adding and removing spinners 


/*
DONE - 16 targets 
250ms + 1000ms (500ms + 1000ms) - TRY!
DONE - Regular dwell (400ms, require stationary). Use a fuse button, 1500ms. 
  - Unity ref impl: https://forum.unity.com/threads/timed-gaze-input-selection-trigger-for-cardboard.373706/

panned & highlighted targets?
two distances as a var?
 
 */
 

// 1. Check the impact of FRAMERATE not working (and being set to 100). From the data file it seems on 
//   1.1. Switch to Mono display - probably not worth it
// 2. Switch to process cursor positions in the correlation - maybe not important... 

// inevitably, we mark the start trial time from the last moment of the previous exot mode. In practice, this is one "calculate" before we start logging data
// in some sense, all data is thus one frame longer than it should be....

// in my latest test, we don't start logging quite when I expect (due to handheld?)

// test other conditions (tap/dwell)

// reimplement stationary dwell

// errors after test:
/*        
raw log file a mess --  check it. Also pretty much useless. Skip?
 */

/*
 * Fixed:
DONE -- quit on end (or better msg?)
DONE -- don't report on-off data from timeout in MoMa
DONE -- count down is not right in long break
DONE -- after long break, go to regular break screen?
DONE -- do we want to show block breaks? No need?
DONE -- start of trial not logged
DONE -- add better summaries to log (for errors?)
DONE - 4. Coorelations take 8ms-12ms to process. This could be a problem for a 100hz update rate. Try to optimize.
        - cut junk for 0-1 ms. Probably not worth further optimization, but basically, they all relate, so we not need calculate all correlations
        - we can determine them from a small set of correlations (e.g. take advantage of polar opposite movements) 
DONE - 5. ANGLE_SPEED is not dyanamic, meaning that it doesn't relfect changes in the framerate. This is not good. 
        - We get around 50-55 calls to calculate each second.
        - used a timeSinceLastUpdate variable to dynamically adjust MoMa target movement. 
DONE - add log of all target correls to all MoMa trials.
DONE - change graphics for MoMa - too hard to see!
DONE - We get a weird print statement like "28 != 24" that I don't know where it comes from... It was an exception from unequal sized samples in the correlator due to wierdness in how they were logged
 */

// VR_SPECIFIC
import processing.vr.*;

int subjectNum                = 1;           // subject number - can be modified in the app (with keyboard buttons)

// input mode - between our three study conditions
final int INPUT_KEY           = 0;
final int INPUT_DWELL         = 1;
final int INPUT_MOMA          = 2;
final String[] MODE_STRINGS   = {"Keyboard", "Dwell", "MoMa"};
int inputMode                 = INPUT_MOMA; 


// Study stages
final int MODE_CHOOSE    = -1;          // where we choose the input source
final int MODE_BREAK     =  0;          // break time between blocks           
final int MODE_TRIAL     =  1;          // trial time
final int MODE_CENTRE    =  2;          // in-between trials (single target in the centre)
final int MODE_FIX       =  3;          // show a fixation spot
final int MODE_RESULT    =  4;          // show the outcome
final int MODE_END       =  5;          // end of study
final int MODE_HALF_BREAK = 6;          // middle of whole session, take a break!

// study timing thresholds
final long TIMEOUT_TIME    = 5000;      // how long until we timeout
final long FIX_TIME        = 500;       // fix spot display
final long RESULT_TIME     = 750;       // results display duration
final long BREAK_TIME      = 50;        // short break time between blocks - we basically skip over this stage 
final long HALFBREAK_TIME  = 60000;     // one minute in ms - we run a "long break" at the half-way point of the study. 
final long END_TIME        = 10000;     // ten seconds to end


// Study config
final int BLOCKS       = 16;               // Total trial blocks (ignore the first?) <- set as 20
      int TARGET_NUM   = 8;                // Total target numbers - in every corner : 8 targets, equals 8 trials per block - set in setup
boolean APPLY_DYNAMIC  = false;            // whether or not we adapt the targets position based on sensed feedback
boolean APPLY_STOP     = false;            // whether or not we use a stop to trigger selection
boolean APPLY_FEEDBACK = false;            // whether or not we use highlighting of active targets (use with APPLY_STOP for sure)
boolean APPLY_CURSOR   = false;            // whether or not we display (and use) a cursor for correlation
boolean APPLY_GAZE     = true;             // whether or not we dynamically choose targets depending where you are looking
int mode               = MODE_CHOOSE;      // startmode for the study 
int currentBlock       = 0;                // start at block zero
IntList trial_order;                       // order in which targets are selected, when we complete a trial successfully, it is removed from the list


// invarients 
long        modeChangeTime    = 0;         // last time the study mode changed.     
PVector     cursor_pos;                    // cursor coordinates on scene object (can be invalid if not intersected with scene object). 
boolean     over_target       = false;     // are we over a target?
int         over_target_num   = -1;        // the target currently being hovered by the cursor
long        over_target_time  = -1;        // when we moved on to the most recent target (in a trial) - FIXME
long        total_trial_time  = 0;         // running total of the successes 
boolean     correct_selection = false;     // is the current trial correct
int         successCount      = 0;         // how many sucessful trials have been completed - init here with 0
int         errorCount        = 0;         // how many error trials have been performed  - init here with 0

// for data logging off target on/off events
final int MAX_ON_OFFS = 10;
int[] in_count;
int[] out_count;
long[][] in_time;
long[][] out_time;

/*
 * Init data stores for target over counts/times
 */
void initOnOffs(int tNum)  
  {
  in_count    = new int  [tNum];
  out_count   = new int  [tNum];
  in_time  = new long [tNum][MAX_ON_OFFS];
  out_time = new long [tNum][MAX_ON_OFFS];  
    
  for (int i=0; i<tNum; i++) 
    {
    for (int j=0; j <MAX_ON_OFFS; j++) 
      {
      in_time [i][j] = 0;
      out_time[i][j] = 0;
      }
    in_count[i]  = 0;
    out_count[i] = 0;
    }
  }


// Scene sizes/parameters
// VR_SPECIFIC
PGraphicsVR pvr;
// PGraphics pvr; // remove

PGraphics sceneSurf;
final int   SCENE_SIZE     = 400;          // the VR scene size (where we draw our targets)
final float SCENE_DIST     = 0;            // scene distance from the viewer  -> 500 MAX(camera) originally set as 1.
final float TARGET_SIZE    = 40;           // target diameter.
final float CURSOR_SIZE    = TARGET_SIZE/3;// as it says... 

// MOMA stuff

final float FOCUS_THRESHOLD            = 0.75; // The min abs mean correlation score that we will consider for adjusting the spinners. 
      float FORCE_HIGHLIGHT            = 5.0;  // This is the force we apply to the spinners when they are highlighted - 
                                                    // 5.0 works well for 8 targets (4 each way). 
                                                    // Not sure about 16 targets (8 each way) - try 10 as distances between targets are half'd, so double the spring strength?
final float BASIC_DEVISOR              = 20.0; // Basic measure for spring easing (can we quantify?). 2 is basic instant snap to new config. Use for dwell activate? Hot corners?
                                                    // The strength will dictate the ultimate arragement of the targets, the devisor, how quickly this state is reached. 

final float ANGLE_SPEED_TARGET         = 180;       // we should aim for 180 degrees/second
final long  MOMA_STARTUP_FAST          = 250;       // Period after start of trial before starting correlations. In big target, 500ms looks bit short
final long  MOMA_DURATION_FAST         = 750;       // duration to run correlations over
final long  MOMA_STARTUP_SLOW          = 500;       // Period after start of trial before starting correlations. In big target, 500ms looks bit short
final long  MOMA_DURATION_SLOW         = 1000;      // duration to run correlations over
      long  MOMA_STARTUP               = MOMA_STARTUP_SLOW;  // start in fast mode
      long  MOMA_DURATION              = MOMA_DURATION_SLOW; 
final long  MOMA_STARTUP_DYN           = 750;       // time to start correlations springs 
final long  MOMA_STARTUP_DYN_GAP       = 250;       // time to updates of correlations springs 
final long  MOMA_STARTUP_FEEDBACK      = 750;       // time to start feedback display - at the moment never
final float MOMA_CORREL_TRIGGER        = 0.8;       // the trigger value for correlations

final float MOMA_FEEDBACK_ON           = 250;       // the amount of time we fade the feedback in
final float MOMA_FEEDBACK_OFF          = 500;       // the amount of time we fade the feedback out
final float MOMA_STOP_TO_SELECT        = 250;       // the amount of time we consider when looking for stop to select targets - we take the mode of target numbers from
                                                    //     this time before we trigger a stop event. Larger number will create a longer backwards window


Correlator  correlator;                             // the correlator class



// Dwell input parameters
final int   DWELL_THRESHOLD            = 1000;       // we trigger dwell after being over target for this amount of time


// KEYCODES - so we can switch between a PC version and an android version easily. 
// VR_SPECIFIC
// Swap between PC and android codes...

final int KEY_LEFT  = android.view.KeyEvent.KEYCODE_DPAD_LEFT;
final int KEY_RIGHT = android.view.KeyEvent.KEYCODE_DPAD_RIGHT;
final int KEY_DOWN  = android.view.KeyEvent.KEYCODE_DPAD_DOWN;
final int KEY_UP    = android.view.KeyEvent.KEYCODE_DPAD_UP;
final int KEY_SPACE = android.view.KeyEvent.KEYCODE_SPACE;
final int KEY_ENTER = android.view.KeyEvent.KEYCODE_ENTER;
final int KEY_F     = android.view.KeyEvent.KEYCODE_F;
final int KEY_S     = android.view.KeyEvent.KEYCODE_S;
final int KEY_N     = android.view.KeyEvent.KEYCODE_N;
final int KEY_D     = android.view.KeyEvent.KEYCODE_D;
final int KEY_H     = android.view.KeyEvent.KEYCODE_H;

// study modes
final int KEY_1     = android.view.KeyEvent.KEYCODE_1;
final int KEY_2     = android.view.KeyEvent.KEYCODE_2;
final int KEY_3     = android.view.KeyEvent.KEYCODE_3;
final int KEY_4     = android.view.KeyEvent.KEYCODE_4;

/*
final char KEY_LEFT  = 'Z';
final char KEY_RIGHT = 'X';
final int KEY_UP    = 'Q';
final int KEY_DOWN  = 'A';
final int KEY_SPACE = ' ';
final int KEY_ENTER = ' ';
final int KEY_F     = 'F';
final int KEY_S     = 'S';
final int KEY_N     = 'N';
final int KEY_D     = 'D';
final int KEY_H     = 'H';
*/

boolean useCenterDwell = false; // toggle if dwell on center passes to a new trial - the is immediate. TODO SET FALSE FOR REAL STUDY


/*
 * Main setup function
 */
void setup()
{  
  // VR_SPECIFIC
  fullScreen(STEREO);        // try mono for speed?
  //size(400, 400, P3D); 
  
  initScene();               // start the VR scene
  
  println("Updating MoMa targets at " + ANGLE_SPEED_TARGET + " per second"); 
}

/*
 * all the basic init
 */
void initializeStudy()
  {
  targetsInit(TARGET_NUM);   // init the targets
  if (APPLY_GAZE && TARGET_NUM==8) // if the targets are just 8 and we are using gaze to turn them on and off
    adjustTargets(); 
  
  initTrialOrder();          // randomize trial order
  
  dataStoreInit(TARGET_NUM);            // prepare data structures

  correlator = new Correlator(TARGET_NUM, MOMA_DURATION, MOMA_CORREL_TRIGGER); // send it targets, sample duration and correl threshold
  }


/*
 * Start the VR scene
 */
void initScene()
{
  // VR_SPECIFIC - uncomment for VR
  cameraUp();
 
  textureMode(NORMAL);
  sceneSurf = createGraphics(SCENE_SIZE, SCENE_SIZE);
}


/*
 * Draw function - first setup and draw any basic elements 
 */
void draw()
{  
  // VR_SPECIFIC - remove the below two lines!
  // calculate();
  // cursor_pos = new PVector (mouseX, mouseY); 
  
  background(255);
  
  // VR_SPECIFIC
  pvr = (PGraphicsVR)g;
  //pvr=(PGraphics) g;
  
  drawScene();
}



/*
 * Get current head cursor coords on the canvas
 */
PVector getCurrentCoords() 
{
  // VR_SPECIFIC - need these three, uncomment mouse line for PC
  PVector pt = intersectRayPlane(new PVector(pvr.cameraX, pvr.cameraY, pvr.cameraZ), 
    new PVector(pvr.cameraX + pvr.forwardX, pvr.cameraY - pvr.forwardY, pvr.cameraZ + pvr.forwardZ), 
    new PVector(0, 0, SCENE_DIST), new PVector(0, 0, 1));
  pt.x += SCENE_SIZE/2; 
  pt.y += SCENE_SIZE/2;
  
  //PVector pt = new PVector(mouseX, mouseY); 
  
  return pt;
}








/*
 * Update simulation - check position and target overlaps/selections
 * Called once, just before draw. 
 * Actually calculate is called ~ 30/seconds and draw is called much faster
 * Over whole update of the targets is seriously balls by this. 
 */
long lastSecond    = 0; 
int secondCount    = 0;
long lastCalculate = 0; 
void calculate()
{
  /*
   * Hack to count how frequently we update calculate. 
   */
  long thisSecond = millis()/1000; 
  if (thisSecond!=lastSecond)
    {
    // println("In second " + lastSecond + " we ran calculate " + secondCount + " times."); 
    lastSecond = thisSecond;
    secondCount = 0;
    }
  else 
    secondCount++;
  //
  
  if (output_data == null || output_raw == null) return; // dumb check for files - FIXME

  long now = millis();              // records the current time
  cursor_pos = getCurrentCoords();  // updates the current cursor coords
  
  // VR_SPECIFIC
  checkCursorHover(now, cursor_pos);// records what target we are no (if any) 
  // checkCursorHover(now, new PVector (mouseX, mouseY)); // use this version for PC
  
  // println(frameRate);            // this is not a good measure of when we run calculate....  

  // plus cursor pos + cursor target? 
  output_raw.print(now+",");

  switch (mode)
  {
  case MODE_CHOOSE : // nothing to do - processed on click
    break; 
  case MODE_BREAK :  
    if (modeExceeds(now, BREAK_TIME))
      updateMode(MODE_CENTRE, now); // remove this line if you want to show a message on the regular breaks - this just flashes past the stage entirely.  
    break; 
  case MODE_TRIAL : 
    if (modeExceeds(now, TIMEOUT_TIME))
    {
      if (inputMode != INPUT_MOMA) // we don't print on/off data in MOMA
        printOnOffData(now);
      updateMode(MODE_RESULT, now); 
      break;
    }

    if (inputMode == INPUT_MOMA) {
      if (calculateMoMa(now, now-lastCalculate) >= 0) 
        updateMode(MODE_RESULT, now);
    } else if (inputMode == INPUT_DWELL) { 
      if (calculateDwell(now) >= 0)
        updateMode(MODE_RESULT, now);
    } else if (inputMode == INPUT_KEY)
      calculateKey(now); // updateMode is processed in keydown event
    break; 
  case MODE_FIX :     
    if (modeExceeds(now, FIX_TIME))
      updateMode(MODE_TRIAL, now); 
    break;    

  case MODE_RESULT :     
    if (modeExceeds(now, RESULT_TIME))
      {
      clearCorrelData(); // blank the correl data
      nextTrial(now);    // mode is updated in next trial
      }
    break;     

  case MODE_CENTRE :   // nothing to do - processed on click
    if (useCenterDwell) 
      activateCenter(now);
    break; 
  case MODE_END :     
    if (modeExceeds(now, END_TIME))
      System.exit(-1);  
    break; 
  case MODE_HALF_BREAK : 
    if (modeExceeds(now, HALFBREAK_TIME)) 
      updateMode(MODE_CENTRE, now); //mode= MODE_CENTRE; 
    break;
  }

  output_raw.print("\n"); // terminate the line
  lastCalculate = now; 
}




/*
 * process key events
 */
 
int cond = 0; 
void handleKeyEvent(KeyEvent event)
{
  
    
  // get the basics of the key event
  long now = millis(); 
  int _keyCode = event.getKeyCode();  
  if (event.getAction() != KeyEvent.RELEASE)
    return;
  boolean enter = false;
  boolean right = false;
  
  //// VR_SPECIFIC - delete these lines for PC
  //if (_keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN) enter = true;
  
  //// hack on mode shift
  //if (_keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP)   
  //  {
  //  cond++;
  //  if (cond>=4)
  //    cond = 0;
    
  //  if (cond == 0) _keyCode = KEY_1;
  //  if (cond == 1) _keyCode = KEY_2;
  //  if (cond == 2) _keyCode = KEY_3;
  //  if (cond == 3) _keyCode = KEY_4;
  //  }
      
  
  if (_keyCode == KEY_SPACE || _keyCode == KEY_ENTER)
    enter = true; 

  // println("Key: " + _keyCode + ", " + (char)_keyCode + ", " + KEY_1 + ", " + android.view.KeyEvent.KEYCODE_1);
  
  switch (mode)
  {
  // process UI/study choices  
  case MODE_CHOOSE : 
    if (_keyCode == KEY_RIGHT || right)
    {
      inputMode++; 
      if (inputMode >= MODE_STRINGS.length) inputMode = 0;
    } else if (_keyCode == KEY_LEFT)    
    {
      inputMode--; 
      if (inputMode < 0) inputMode = MODE_STRINGS.length-1;
    } else if (_keyCode == KEY_DOWN)
      {if (subjectNum>0) subjectNum--;}
    else if (_keyCode == KEY_UP)
      subjectNum++;
    else if (enter)
    {
      initializeStudy(); // do all the init 
      setupFileNames(MODE_STRINGS[inputMode], subjectNum); // here's where we set files names with ones for the new condition
      updateMode(MODE_BREAK, now); //mode= MODE_BREAK;
    }
    
    else if (_keyCode == KEY_1)
      {
      APPLY_DYNAMIC  = false;            // whether or not we adapt the targets position based on sensed feedback
      APPLY_STOP     = false;            // whether or not we use a stop to trigger selection
      APPLY_FEEDBACK = false;            // whether or not we use highlighting of active targets (use with APPLY_STOP for sure)
      APPLY_CURSOR   = false;            // whether or not we display (and use) a cursor for correlation
      APPLY_GAZE     = false;            // whether or not we toggle targets based on head position
      MOMA_STARTUP   = MOMA_STARTUP_SLOW;
      }
    else if (_keyCode == KEY_2)
      {
      APPLY_DYNAMIC  = true;             // whether or not we adapt the targets position based on sensed feedback
      APPLY_STOP     = false;            // whether or not we use a stop to trigger selection
      APPLY_FEEDBACK = false;            // whether or not we use highlighting of active targets (use with APPLY_STOP for sure)
      APPLY_CURSOR   = false;            // whether or not we display (and use) a cursor for correlation
      APPLY_GAZE     = false;            // whether or not we toggle targets based on head position
      MOMA_STARTUP   = MOMA_STARTUP_SLOW;
      }
    else if (_keyCode == KEY_3)
      {
      APPLY_DYNAMIC  = false;            // whether or not we adapt the targets position based on sensed feedback
      APPLY_STOP     = true;             // whether or not we use a stop to trigger selection
      APPLY_FEEDBACK = true;             // whether or not we use highlighting of active targets (use with APPLY_STOP for sure)
      APPLY_CURSOR   = false;            // whether or not we display (and use) a cursor for correlation
      APPLY_GAZE     = false;            // whether or not we toggle targets based on head position
      MOMA_STARTUP   = 0;
      }
    else if (_keyCode == KEY_4)
      {
      APPLY_DYNAMIC  = false;            // whether or not we adapt the targets position based on sensed feedback
      APPLY_STOP     = false;            // whether or not we use a stop to trigger selection
      APPLY_FEEDBACK = false;            // whether or not we use highlighting of active targets (use with APPLY_STOP for sure)
      APPLY_CURSOR   = false;            // whether or not we display (and use) a cursor for correlation
      APPLY_GAZE     = true;            // whether or not we toggle targets based on head position
      MOMA_STARTUP   = MOMA_STARTUP_SLOW;
      }
    /*
    else if (_keyCode == KEY_F)
      {
      MOMA_STARTUP               = MOMA_STARTUP_FAST;  
      MOMA_DURATION              = MOMA_DURATION_FAST; 
      }
    else if (_keyCode == KEY_S)
      {
      MOMA_STARTUP               = MOMA_STARTUP_SLOW;  
      MOMA_DURATION              = MOMA_DURATION_SLOW; 
      }
    else if (_keyCode == KEY_N)
      {
      if (TARGET_NUM==8)
        TARGET_NUM = 16; 
      else 
        TARGET_NUM=8;
      }
    else if (_keyCode == KEY_D)
      {
      APPLY_DYNAMIC = !APPLY_DYNAMIC; 
      }
    else if (_keyCode == KEY_H)
      {
      if (FORCE_HIGHLIGHT==5)
        FORCE_HIGHLIGHT = 10; 
      else 
        FORCE_HIGHLIGHT = 5;
      }*/
    break; 


  case MODE_BREAK :  
    //if (enter) updateMode(MODE_CENTRE, now);               // if you want to have participants click through block breaks, include this line.  
    break; 


  case MODE_TRIAL : 
    if (inputMode == INPUT_KEY)
    {
      keySelection(); 
      updateMode(MODE_RESULT, now);
    }
    break;

  case MODE_FIX :     // just timing
  case MODE_RESULT :     // just timing
    break;  

  case MODE_CENTRE :
    activateCenter(now);
    break;


  case MODE_END :     
    break; 
  case MODE_HALF_BREAK : 
    break;
  }

  super.handleKeyEvent(event);
}


/*
 * change modes -TODO - update all sections to use this function. 
 */
void updateMode(int newMode) {
  updateMode(newMode, millis());
}

void updateMode(int newMode, long now)
{
  modeChangeTime = now; 
  mode = newMode;
}

boolean modeExceeds(long now, long duration)
{
  return (now-modeChangeTime)>duration;
}


/*
 * Process a new trial event
 */
void nextTrial(long now)
{
  // save current data to disk 
  output_data.flush();
  output_raw. flush();
  
  targetsReset();              // move the targets to default (random) states 

  if (getCurrentTrial() == TARGET_NUM-1 && correct_selection) // last trial in the block and correct...
    { 
    if (currentBlock == BLOCKS-1)   // last trial in study! 
      {  
      updateMode(MODE_END, now); //mode= MODE_END;
      writeStudyEnd();
      return; 
      }
    else 
      {
      currentBlock ++;
      initTrialOrder();
      if (currentBlock == (BLOCKS-BLOCKS%2)/2) 
        updateMode(MODE_HALF_BREAK, now); //mode= MODE_HALF_BREAK;
      else 
        updateMode(MODE_BREAK, now);      //mode= MODE_BREAK;
      }
    }
  else
    {
    if (correct_selection) 
      trial_order.remove(0); // remove trial zero if we are done
    else 
      trial_order.shuffle(); // otherwise just mix it all up again
    updateMode(MODE_CENTRE, now); //mode= MODE_CENTRE;
    }  
}


// inits the trial order with random arragement. 
void initTrialOrder()
{
  /*
   * Set up trials/block - we just have one/target in a random order.  
   */
  trial_order = new IntList();
  for (int i = 0; i < TARGET_NUM; i++) 
    trial_order.append(i);
  trial_order.shuffle();
}

// returns an id for the trial number within the block  
int getCurrentTrial() {
  return TARGET_NUM - trial_order.size();
}


void activateCenter(long now)
  {
  if (centreMenuTarget.cursorOver(cursor_pos.x, cursor_pos.y))
    {
      correct_selection = false;   // default is a failed trial; we adjust if correct
      
      initOnOffs(TARGET_NUM);                // wipe the on/off data stores 
      
      // print off the start details for the trial. 
      output_data.print("\n ###START,"+currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+"\n"); // current trial is always the zero trial
      output_raw. print("\n ###START,"+currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+"\n");
      
      updateMode(MODE_FIX, now); //mode= MODE_TRIAL;
    }
  }
  
  
  
  
