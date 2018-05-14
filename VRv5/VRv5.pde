// 1. Check the impact of FRAMERATE not working (and being set to 100). From the data file it seems on 
//   1.1. Switch to Mono display
// 2. Switch to process cursor positions in the correlation - maybe not important... 
// 3. check what the actual framerates are: ~ 100
// 4. Coorelations take 8ms-12ms to process. This could be a problem for a 100hz update rate. Try to optimize. 
// 5. ANGLE_SPEED is not dyanamic, meaning that it doesn't relfect changes in the framerate. This is not good. 

// errors after test:
/*
start of trial not logged
quit on end (or better msg?)
raw log file a mess
add better summaries to log (for errors?)
count down is not right in long break
  after long break, go to regular break screen?
do we want to show block breaks? No need?
don't report on-off data from timeout in MoMa
 */



import processing.vr.*;


int subjectNum     = 1;

boolean     correct_selection = false;
int         success           = 0;

long        moma_avg       = 0;
long        dwell_avg      = 0;
long        keyboard_avg   = 0;

long modeChangeTime        = 0;






// SCENE PARAMETERS
PGraphicsVR pvr;
final int SCENE_SIZE     = 400;        // the VR scene size (where we draw our targets)
final float SCENE_DIST   = 0;        // scene distance from the viewer  -> 500 MAX(camera) originally set as 1.
final float TARGET_SIZE  = 40;         // target diameter.

PGraphics sceneSurf;
final int FRAMERATE      = 100;        // Need to set as 60, but daydream chooses the fps... it directly affects the correlator class.
// (it sees FRAMERATE as 1 second)

final long TIMEOUT_TIME                = 5000;      // how long until we timeout
final long FIX_TIME                    = 500;       // fix spot display
final long RESULT_TIME                 = 750;       // results display duration
final long HALFBREAK_TIME              =  1 * 60 * 1000; // one minute in ms.

// MOMA INPUT PARAMETERS
final long MOMA_THRESHOLD              = 1000;      // start correlation
final long MOMA_ACTIVATION_THRESHOLD   = 500;       // Period after start of trial before starting correlations. In big target, 500ms looks bit short

// DWELL INPUT PARAMETERS
long dwellStartTime;                                // var where we log target over times. 
final int   DWELL_THRESHOLD            = 400;       // we trigger dwell after 400ms

// Set the input mode
int inputMode; 
final int INPUT_KEY   = 0;
final int INPUT_DWELL = 1;
final int INPUT_MOMA  = 2;
final String[] MODE_STRINGS = {"Keyboard", "Dwell", "MoMa"};

// STUDY STAGES
final int MODE_CHOOSE = -1;                // where we choose the input source
final int MODE_BREAK  =  0;                // break time between blocks           
final int MODE_TRIAL  =  1;                // trial time
final int MODE_CENTRE =  2;                // in-between trials (single target in the centre)
final int MODE_FIX    =  3;                // show a fixation spot
final int MODE_RESULT =  4;                // show the outcome
final int MODE_END    =  5;                // end of study
final int MODE_HALF_BREAK = 6;             // middle of whole session, take a break!


// study config
final int BLOCKS = 20;                     // Total trial blocks (ignore the first?) <- set as 20
final int TARGET_NUM = 8;                  // Total target numbers - in every corner : 8 targets
int mode = MODE_CHOOSE;                    // startmode for the study

// startup values for the block and trial and a list of the trial ids, which we can randomize. 
int currentBlock = 0;                      // start with zero blocks
IntList trial_order;                       // order in which targets are selected, when we complete a trial successfully, it is removed from the list

// - 
Correlator correlator;                     // the correlator
// -
PVector cursor_pos;                        // cursor coordinates on-scene

long     overTargetTime;                   // when we moved on to the most recent target (in a trial) 
boolean  over_target = false;              // are we over a target?
int      over_target_num;                  // the target currently being hovered by the cursor

int[] in_count    = new int  [TARGET_NUM];
int[] out_count   = new int  [TARGET_NUM];
long[][] in_time  = new long [TARGET_NUM][10];
long[][] out_time = new long [TARGET_NUM][10];


final float CURSOR_SIZE = TARGET_SIZE/3;


/*
 * Main setup function
 */
void setup()
{  
  fullScreen(STEREO);        // try mono for speed?
  initScene();               // start the VR scene

  initTrialOrder();          // randomize trial order

  dataStoreInit();            // prepare data structures

  targetsInit();              // init the targets

  correlator = new Correlator(TARGET_NUM, FRAMERATE, 0.8, FRAMERATE); // this could be a MAJOR problem. FRAMERATE is not accurate!

  /*
   * Init data stores for target over counts/times
   */
  for (int i=0; i<TARGET_NUM; i++) {
    for (int j=0; j <10; j++) {
      in_time[i][j] = 0;
      out_time[i][j]= 0;
    }
    in_count[i] = 0;
    out_count[i]= 0;
  }
}


/*
 * Start the VR scene
 */
void initScene()
{
  cameraUp();
  textureMode(NORMAL);
  sceneSurf = createGraphics(SCENE_SIZE, SCENE_SIZE);
}


/*
 * Draw function - first setup and draw any basic elements 
 */
void draw()
{  
  background(255);
  pvr = (PGraphicsVR)g;
  drawScene();
}



/*
 * Get current head cursor coords on the canvas
 */
PVector getCurrentCoords() 
{
  PVector pt = intersectRayPlane(new PVector(pvr.cameraX, pvr.cameraY, pvr.cameraZ), 
    new PVector(pvr.cameraX + pvr.forwardX, pvr.cameraY - pvr.forwardY, pvr.cameraZ + pvr.forwardZ), 
    new PVector(0, 0, SCENE_DIST), new PVector(0, 0, 1));  
  pt.x += SCENE_SIZE/2; 
  pt.y += SCENE_SIZE/2;
  return pt;
}








/*
 * Update simulation - check position and target overlaps/selections
 * Called once, just before draw. 
 */
void calculate()
{
  if (output_data == null || output_raw == null) return; 

  // update time and cursor position. 
  long now = millis();                          // records the current time
  cursor_pos = getCurrentCoords();              // updates the current cursor coords
  boolean onNewTarget = checkCursorHover(now);  // records what target we are no (if any) 

  //println(frameRate); 

  // plus cursor pos + cursor target? 
  output_raw.print(now+",");

  switch (mode)
  {
  case MODE_CHOOSE : // nothing to do - processed on click
    break; 
  case MODE_BREAK :  // nothing to do - processed on click
    break; 
  case MODE_TRIAL : 
    if (modeExceeds(now, TIMEOUT_TIME))
    {
      printOnOffData(now);
      updateMode(MODE_RESULT, now); 
      break;
    }

    if (inputMode == INPUT_MOMA) {
      if (calculateMoMa(now) >= 0) 
        updateMode(MODE_RESULT, now);
    } else if (inputMode == INPUT_DWELL) { 
      if (calculateDwell(now, onNewTarget) >= 0)
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
      nextTrial(now);  // mode is updated in next trial
    break;     

  case MODE_CENTRE :   // nothing to do - processed on click
    break; 
  case MODE_END :     
    // EXPIRES after time
    break; 
  case MODE_HALF_BREAK : 
    if (modeExceeds(now, HALFBREAK_TIME)) 
      updateMode(MODE_CENTRE, now); //mode= MODE_CENTRE; 
    break;
  }

  output_raw.print("\n"); // terminate the line
}




/*
 * process key events
 */
void handleKeyEvent(KeyEvent event)
{
  // get the basics of the key event
  long now = millis(); 
  int _keyCode = event.getKeyCode();
  if (event.getAction() != KeyEvent.RELEASE)
    return;
  boolean enter = false;
  if (_keyCode == android.view.KeyEvent.KEYCODE_SPACE || _keyCode == android.view.KeyEvent.KEYCODE_ENTER) 
    enter = true; 

  switch (mode)
  {
    // process UI/study choices  
  case MODE_CHOOSE : 
    if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_RIGHT)
    {
      inputMode++; 
      if (inputMode >= MODE_STRINGS.length) inputMode = 0;
    } else if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_LEFT)    
    {
      inputMode--; 
      if (inputMode < 0) inputMode = MODE_STRINGS.length-1;
    } else if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_DOWN)
      subjectNum--;
    else if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_UP)
      subjectNum++;
    else if (enter)
    {
      setupFileNames(MODE_STRINGS[inputMode], subjectNum); // here's where we set files names with ones for the new condition
      updateMode(MODE_BREAK, now); //mode= MODE_BREAK;
    }
    break; 


  case MODE_BREAK :  
    if (enter) updateMode(MODE_CENTRE, now); //mode= MODE_CENTRE;
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
    if (centreMenuTarget.cursorOver(cursor_pos.x, cursor_pos.y))
    {
      correct_selection = false;   // default is a failed trial; we adjust if correct
      updateMode(MODE_FIX, now); //mode= MODE_TRIAL;
    }
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
  targetsReset();              // move the targets to default (random) states
  output_data.print("\n ###START,"+currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+"\n"); // current trial is always the zero trial
  output_raw. print("\n ###START,"+currentBlock+","+getCurrentTrial()+","+trial_order.get(0)+"\n"); 

  if (getCurrentTrial() == TARGET_NUM-1 && correct_selection) // last trial in the block and correct...
  { 
    if (currentBlock == BLOCKS-1)   // last trial in study! 
    {  
      updateMode(MODE_END, now); //mode= MODE_END;
      writeStudyEnd();
    } else 
    {
      currentBlock ++;
      initTrialOrder();
      if (currentBlock == (BLOCKS-BLOCKS%2)/2) 
        updateMode(MODE_HALF_BREAK, now); //mode= MODE_HALF_BREAK;
      else 
      updateMode(MODE_BREAK, now);      //mode= MODE_BREAK;
    }
  } else
  {
    if (correct_selection) trial_order.remove(0); // remove trial zero if we are done
    else trial_order.shuffle();                   // otherwise just mix it all up again
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