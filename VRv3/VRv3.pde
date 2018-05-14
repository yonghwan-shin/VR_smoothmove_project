import processing.vr.*;

Arrow indicator;
String SUBJECT = "_test";
int subjectNum = 1;
PrintWriter output_raw = null;
PrintWriter output1 = null;
int success = 0;
long moma_avg=0;
long dwell_avg = 0;
long keyboard_avg = 0;
boolean MOMA_CHECK = false;
boolean DWELL_CHECK = false;
boolean KEYBOARD_CHECK = false;
long MOMA_TIMING, DWELL_TIMING, KEYBOARD_TIMING;
long dwellReady_time;
int orbitResetConstant;

long begin;
boolean dwell_ON = false;
boolean keyboard_ON = false;

// SCENE PARAMETERS
PGraphicsVR pvr;
final int SCENE_SIZE     = 400;        // the VR scene size (where we draw our targets)
final float SCENE_DIST   = 250;        // scene distance from the viewer  -> 500 MAX(camera)
PGraphics sceneSurf;
final int FRAMERATE      = 100;        // Need to set as 60, but daydream chooses the fps... it directly affects the correlator class.(it sees FRAMERATE as 1 second)
final float TARGET_SIZE  = 40;         // target diam.

// INPUT PARAMETERS
final long MOMA_THRESHOLD = 1000;      //start correlation
final long MOMA_ACTIVATION_THRESHOLD = 500;                // in big target, 500ms looks bit short
final long MOMA_END_THRESHOLD = 5000;
final long DWELL_time = 500;
final float DWELL_ACTIVATION_THRESHOLD = TARGET_SIZE/2;    // after starting a trial, the user needs to slightly move the cursor before being able to trigger dwell 
final int DWELL_THRESHOLD = 400;                           // we trigger dwell after 400ms
final int DWELL_END_THRESHOLD = 5000;
boolean dwellReady = false;                                // are we past the DWELL_ACTIVATION_THRESHOLD?
float latestDwellX, latestDwellY;                          // the latest cursor position (to check DWELL_MINIMAL_MOVEMENT)
float latestDwellMove;                                     // when was the last time the cursor moved?
final float DWELL_MINIMAL_MOVEMENT = 10;                   // selections occurs after the user has the cursor within a 10x10 pixel area for DWELL_THRESHOLD
// -
int inputMode; 
final int INPUT_KEY   = 0;
final int INPUT_DWELL = 1;
final int INPUT_MOMA  = 2;
final String[] MODE_STRINGS = {"Keyboard", "Dwell", "MoMa"};

// STUDY PARAMETERS
final int MODE_CHOOSE = -1;                // where we choose the input source
final int MODE_BREAK  =  0;                // break time between blocks           
final int MODE_TRIAL  =  1;                // trial time
final int MODE_CENTRE =  2;                // in-between trials (single target in the centre)
final int MODE_END    =  3;                // end of study
final int MODE_HALF_BREAK = 4;             // middle of whole session, take a break!

long halfBreak_timing;
long halfbreakTime = 1;              //in minute.
long remainBreakTime;

// -
final int BLOCKS = 20;                     // Total trial blocks (ignore the first?) <- set as 20
final int TARGET_NUM = 8;                  // Total target numbers - in every corner : 8 targets
int mode = MODE_CHOOSE;
int currentBlock;
int currentTrial;
IntList trial_order = new IntList();       // order in which targets are selected
//-
boolean correct_selection = false;         // did the user select the correct target in the last trial?
ArrayList<Long>   _timeHead;               // head data
ArrayList<Float>  _xHead;                  
ArrayList<Float>  _yHead;
final boolean MAHONY = false;              // use our own IMU filter or the angles from the VR headtransform
// -
ArrayList<Long>   _timeTargets;            // target data
ArrayList<ArrayList<Float>> _targetXs;     
ArrayList<ArrayList<Float>> _targetYs;
ArrayList<Target> targets;
Target centreMenuTarget;
// - 
Correlator correlator;                     // the correlator
// -
PVector cursor_pos;                        // cursor coordinates on-scene
boolean over_target = false;               // draws the cursor with an highlight to indicate it is over a target
int over_target_num;                       // the target currently being hovered by the cursor

int[] dwell_IN_count = new int [TARGET_NUM];
int[] dwell_OUT_count = new int [TARGET_NUM];
long[][] dwell_IN_time = new long [TARGET_NUM][10];
long[][] dwell_OUT_time = new long [TARGET_NUM][10];
int[] keyboard_IN_count = new int [TARGET_NUM];
int[] keyboard_OUT_count = new int [TARGET_NUM];
long[][] keyboard_IN_time = new long [TARGET_NUM][10];
long[][] keyboard_OUT_time = new long [TARGET_NUM][10];

int current_Dwell_target = TARGET_NUM + 10;
int current_Keyboard_target = TARGET_NUM + 10;
final float CURSOR_SIZE = TARGET_SIZE/3;
// for framerate
long temp;
int temp2;

void setup()
{  
  fullScreen(STEREO);  
  initScene();                // start the VR scene
  //frameRate(FRAMERATE);    // <- does not work in VR
  for (int i = 0; i < TARGET_NUM; i++) trial_order.append(i);
  dataStoreInit();            // prepare data structures
  imuInit(false);             // start the IMU   
  correlator = new Correlator(TARGET_NUM, FRAMERATE, 0.8, FRAMERATE);
  trial_order.shuffle();
  halfbreakTime = halfbreakTime * 60 * 1000;
  for (int i=0; i<TARGET_NUM; i++) {
    for (int j=0; j <10; j++) {
      keyboard_IN_time[i][j] = 0;
    }
    keyboard_IN_count[i] = 0;
  }
}

// Called once per frame, right before draw()
// (instead of once per eye)
void calculate()
{
  if (output1 ==null) {                    //Make datafile
    output1 = createWriter("//sdcard/Download/garbage.csv");
  }
  if ( output_raw == null) {
    output_raw = createWriter("//sdcard/Download/garbageraw.csv");
  }

  long now = millis();
  if (temp +1000 <now) {    // check the frame rate
    println("Frame Rate : " + (frameCount-temp2));
    temp2 = frameCount;
    temp = now;
  }

  output_raw.print(now+",");

  if (MOMA_CHECK == false) {
    MOMA_TIMING = now;
    MOMA_CHECK = true;
  }
  if (DWELL_CHECK == false) {
    DWELL_TIMING = now;
    DWELL_CHECK = true;
  }
  if (KEYBOARD_CHECK == false) {
    KEYBOARD_TIMING = now;
    KEYBOARD_CHECK = true;
  }
  // break at mid-time
  if (mode == MODE_HALF_BREAK) {
    if (halfBreak_timing + halfbreakTime< now) {
      mode = MODE_CENTRE;
    } else {
      remainBreakTime = (halfbreakTime+halfBreak_timing - now)/1000;
    }
  }

  if (mode == MODE_TRIAL) {
    if (inputMode == INPUT_MOMA) {
      for (Target target : targets) target.moveOrbit();      // save all target coords
      float[] xs  = new float[TARGET_NUM];
      float[] ys  = new float[TARGET_NUM];
      for (int i = 0; i < TARGET_NUM; i++) {
        Target target_tmp = targets.get(i);
        xs[i] = target_tmp.getOrbitX();
        ys[i] = target_tmp.getOrbitY();
        //~~~~~~~~~~~~~~~~~~~
        output1.print(now+",");
        output1.print("*Target ");
        output1.print(i + "," + xs[i] + "," + ys[i] + ",");
        output_raw.print("*Target ");
        output_raw.print(i + "," + xs[i] + "," + ys[i] + ",");
        //~~~~~~~~~~~~~~~~~~~
      }
      if (now - MOMA_TIMING > MOMA_ACTIVATION_THRESHOLD) 
      {
        addTargetData(now, xs, ys);          // process target data
      }
      cursor_pos = getCurrentCoords();
      //~~~~~~~~~~~~~~~~~~~
      output1.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
      output_raw.print("*CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + ",");
      //~~~~~~~~~~~~~~~~~~~
      processIMuData(now, MOMA_TIMING + MOMA_ACTIVATION_THRESHOLD, pvr);            // process head data
    } else {
      // Get the latest cursor coordinates
      output1.print(now+",");
      cursor_pos = getCurrentCoords();
      checkCursorHover();
      if (inputMode == INPUT_KEY) {
        //~~~~~~~~~~~~~~~~~~~
        output1.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + "\n");
        output_raw.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y);
        //~~~~~~~~~~~~~~~~~~~
        if (over_target == true) {
          if (keyboard_ON == false) {
            current_Keyboard_target = over_target_num;
            keyboard_IN_time[over_target_num][keyboard_IN_count[over_target_num]++] = now;
            keyboard_ON = true;
          }
        } else if (over_target == false) {
          if (keyboard_ON == true) {
            println("keyboard - on OUT!!!");
            keyboard_OUT_time[current_Keyboard_target][keyboard_OUT_count[current_Keyboard_target]++] = now;
          }
          keyboard_ON = false;
        }
      }
      if (inputMode == INPUT_DWELL) {
        //~~~~~~~~~~~~~~~~~~~
        output1.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y + "\n");
        output_raw.print("CURSOR XY ,"+cursor_pos.x + "," + cursor_pos.y);
        //~~~~~~~~~~~~~~~~~~~
        // Check if the cursor has moved away from the centre
        if (dwellReady) {
          // And if DWELL_THRESHOLD has passed
          if (now >= latestDwellMove + DWELL_THRESHOLD) {
            if (now >= dwellReady_time + DWELL_END_THRESHOLD) {            
              //~~~~~~~~~~~~~~~~~~~
              output1.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n"); 
              output1.print("\n###DWELL_IN_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("\n");
              output_raw.print("\n###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n"); 
              output_raw.print("\n###DWELL_IN_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              //~~~~~~~~~~~~~~~~~~~
              for (int i =0; i<TARGET_NUM; i++) {
                dwell_IN_count[i] = 0;
                //~~~~~~~~~~~~~~~~~~~
                output1.print(dwell_IN_count[i]+ ",");
                output_raw.print(dwell_IN_count[i]+ ",");
                //~~~~~~~~~~~~~~~~~~~
              }
              //~~~~~~~~~~~~~~~~~~~
              output1.print("\n");
              output_raw.print("\n");
              output1.print("###DWELL_IN_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output1.print("\n###DWELL_IN_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("\n###DWELL_IN_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("\n###DWELL_IN_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              //~~~~~~~~~~~~~~~~~~~
              for (int i=0; i<TARGET_NUM; i++) {
                for (int j=0; j <10; j++) {
                  output1.print(dwell_IN_time[i][j]+ ",");
                  dwell_IN_time[i][j] = 0;
                }
                output1.print("\n");
                output_raw.print("\n");
              }
              //~~~~~~~~~~~~~~~~~~~
              output1.print("###DWELL_IN_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("###DWELL_IN_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              //~~~~~~~~~~~~~~~~~~~
              output1.print("\n");
              output_raw.print("\n");
              output1.print("\n###DWELL_OUT_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("\n");
              output_raw.print("\n###DWELL_OUT_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              //~~~~~~~~~~~~~~~~~~~

              for (int i =0; i<TARGET_NUM; i++) {
                output1.print(dwell_OUT_count[i]+ ",");
                output_raw.print(dwell_OUT_count[i]+ ",");
                dwell_OUT_count[i] = 0;
              }

              //~~~~~~~~~~~~~~~~~~~
              output1.print("\n");
              output_raw.print("\n");
              output1.print("###DWELL_OUT_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output1.print("\n###DWELL_OUT_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("\n###DWELL_OUT_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("\n###DWELL_OUT_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              //~~~~~~~~~~~~~~~~~~~

              for (int i=0; i<TARGET_NUM; i++) {
                for (int j=0; j <10; j++) {
                  output1.print(dwell_OUT_time[i][j]+ ",");
                  output_raw.print(dwell_OUT_time[i][j]+ ",");
                  dwell_OUT_time[i][j] = 0;
                }
                output1.print("\n");
                output_raw.print("\n");
              }
              //~~~~~~~~~~~~~~~~~~~
              output1.print("###DWELL_OUT_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              output_raw.print("###DWELL_OUT_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
              //~~~~~~~~~~~~~~~~~~~

              selectionTrigger();
              dwell_avg = dwell_avg +now - DWELL_TIMING;
              current_Dwell_target = TARGET_NUM + 10;
              dwell_ON = false;
              //timeover error
            } else {
              if (over_target == true) {
                if (dwell_ON ==false) {
                  current_Dwell_target = over_target_num;
                  //dwell_IN_count[over_target_num]++;
                  dwell_IN_time[over_target_num][dwell_IN_count[over_target_num]++] = now; 
                  println("Dwell in "+ over_target_num);
                  begin = millis();
                  dwell_ON = true;
                }
              } else if (over_target == false) {
                if (dwell_ON == true) {
                  println("DWELL OUT!!!");
                  dwell_OUT_time[current_Dwell_target][dwell_OUT_count[current_Dwell_target]++] = now;
                }
                dwell_ON = false;
                updateDwell(now);
              }

              if (dwell_ON == true && now > begin+DWELL_time) {
                println("DWELL DONE,target " + over_target_num + " selected");

                //~~~~~~~~~~~~~~~~~~~
                output1.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+ (over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output1.print("\n###DWELL_IN_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("\n");
                output_raw.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("\n###DWELL_IN_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                //~~~~~~~~~~~~~~~~~~~

                for (int i =0; i<TARGET_NUM; i++) {
                  output1.print(dwell_IN_count[i]+ ",");
                  output_raw.print(dwell_IN_count[i]+ ",");
                  dwell_IN_count[i] = 0;
                }

                //~~~~~~~~~~~~~~~~~~~
                output1.print("\n");
                output_raw.print("\n");
                output1.print("###DWELL_IN_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output1.print("\n###DWELL_IN_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("###DWELL_IN_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("\n###DWELL_IN_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                //~~~~~~~~~~~~~~~~~~~

                for (int i=0; i<TARGET_NUM; i++) {
                  for (int j=0; j <10; j++) {
                    output1.print(dwell_IN_time[i][j]+ ",");
                    output_raw.print(dwell_IN_time[i][j]+ ",");
                    dwell_IN_time[i][j] = 0;
                  }
                  output1.print("\n");
                  output_raw.print("\n");
                }
                //~~~~~~~~~~~~~~~~~~~
                output1.print("###DWELL_IN_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+ (over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("###DWELL_IN_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING));
                output1.print("\n");
                output_raw.print("\n");
                output1.print("\n###DWELL_OUT_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("\n###DWELL_OUT_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                //~~~~~~~~~~~~~~~~~~~

                for (int i =0; i<TARGET_NUM; i++) {
                  output1.print(dwell_OUT_count[i]+ ",");
                  output_raw.print(dwell_OUT_count[i]+ ",");
                  dwell_OUT_count[i] = 0;
                }
                //~~~~~~~~~~~~~~~~~~~
                output1.print("\n");
                output1.print("###DWELL_OUT_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output1.print("\n###DWELL_OUT_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("\n###DWELL_OUT_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("\n###DWELL_OUT_TIMES_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                //~~~~~~~~~~~~~~~~~~~

                for (int i=0; i<TARGET_NUM; i++) {
                  for (int j=0; j <10; j++) {
                    output1.print(dwell_OUT_time[i][j]+ ",");
                    output_raw.print(dwell_OUT_time[i][j]+ ",");
                    dwell_OUT_time[i][j] = 0;
                  }
                  output1.print("\n");
                  output_raw.print("\n");
                }
                output1.print("###DWELL_OUT_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");
                output_raw.print("###DWELL_OUT_TIMES_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+(now-DWELL_TIMING)+"\n");

                dwell_avg = dwell_avg + now - DWELL_TIMING;
                selectionTrigger();
                current_Dwell_target = TARGET_NUM + 10;
                dwell_ON = false;
              }
            }
            // Finally, check that the cursor remained fairly static during selection
          }
        } else {
          dwellReady = true;
          updateDwell(now);
          dwellReady_time = millis();
        }
      }
    }
  } else if (mode == MODE_CENTRE) 
  {
    // Get the latest cursor coordinates
    cursor_pos = getCurrentCoords();
    over_target = centreMenuTarget.cursorOver(cursor_pos.x, cursor_pos.y);
  }
  output_raw.print("\n");
}

void draw()
{  
  background(255);
  pvr = (PGraphicsVR)g;
  drawScene();
}

// Start the VR scene
void initScene()
{
  cameraUp();
  textureMode(NORMAL);
  sceneSurf = createGraphics(SCENE_SIZE, SCENE_SIZE);
}

// Stores a possible first attempt at dwell
void updateDwell(long now)
{
  latestDwellX = cursor_pos.x;
  latestDwellY = cursor_pos.y;
  latestDwellMove = now;
}

// Check if the cursor is over a target, and stores which (if any)
void checkCursorHover() {
  for (int i = 0; i < TARGET_NUM; i++) {
    if (((Target)targets.get(i)).cursorOver(cursor_pos.x, cursor_pos.y)) {
      over_target = true;
      over_target_num = i;
      return;
    }
  }
  over_target = false;
  over_target_num = -1;
}

// Draws everything the user sees
void drawScene()
{
  // Draws text, targets and/or cursor on the surface of the scene
  sceneSurf.beginDraw();
  sceneSurf.background(255);

  if (mode == MODE_TRIAL)
  { 
    // show guide <- need more upgrade..
    float tempX = targets.get(trial_order.get(currentTrial)).cX;
    float tempY = targets.get(trial_order.get(currentTrial)).cY;
    sceneSurf.stroke(255, 0, 0);
    sceneSurf.strokeWeight(5);
    sceneSurf.line(SCENE_SIZE/2, SCENE_SIZE/2, SCENE_SIZE/2*4/5+tempX/5, SCENE_SIZE/2*4/5+tempY/5);
    float x, y, a, b, c, d, theta;
    theta = atan((tempY-SCENE_SIZE/2)/(tempX-SCENE_SIZE/2));
    if ((tempX-SCENE_SIZE/2) < 0) {
      theta = -(PI - theta);
    }
    
    x = tempX - 10*cos(theta);
    y = tempY - 10*sin(theta);
    a = x - 5*sin(theta);
    b = y + 5*cos(theta);

    c = x + 5*sin(theta);
    d = y - 5*cos(theta);
    triangle(SCENE_SIZE/2*4/5+tempX/5,SCENE_SIZE/2*4/5+tempY/5, a, b, c, d);float x, y, a, b, c, d, theta;
    theta = atan((tempY-SCENE_SIZE/2)/(tempX-SCENE_SIZE/2));
    if ((tempX-SCENE_SIZE/2) < 0) {
      theta = -(PI - theta);
    }
    
    x = tempX - 10*cos(theta);
    y = tempY - 10*sin(theta);
    a = x - 5*sin(theta);
    b = y + 5*cos(theta);

    c = x + 5*sin(theta);
    d = y - 5*cos(theta);
    triangle(SCENE_SIZE/2*4/5+tempX/5,SCENE_SIZE/2*4/5+tempY/5, a, b, c, d);
    // Draw targets
    drawTargets();
    if (inputMode != INPUT_MOMA) drawCursor(); // no cursor in Moma condition
    //drawCursor();
  } else
  {
    String msg = refreshTextMenu();        // defines what's written as a text menu
    sceneSurf.fill(0); 
    sceneSurf.textSize(20); 
    sceneSurf.textAlign(CENTER, CENTER);
    sceneSurf.textLeading(20);

    if (mode == MODE_CENTRE)
    {
      sceneSurf.text(msg, SCENE_SIZE/2, SCENE_SIZE-SCENE_SIZE/4);
      centreMenuTarget.draw(false, true);
      drawCursor();
    } else sceneSurf.text(msg, SCENE_SIZE/2, SCENE_SIZE/2);
  }
  sceneSurf.endDraw();

  // Change the border during the MODE_CENTRE pause screen
  // to indicate a correct/incorrect selection in the previous trial  <- not in last trial in each block! need to change.

  if (currentTrial != 0 && mode == MODE_CENTRE)
  {
    if (correct_selection) stroke(0, 255, 0);
    else stroke(255, 0, 0);
  } else
  {
    // In all other cases display a grey border
    noFill();
    stroke(128);
  }
  // Draws the actual scene
  pushMatrix();   
  translate(0, 0, SCENE_DIST);
  int s = SCENE_SIZE/2; 
  strokeWeight(8);
  beginShape(QUADS); 
  texture(sceneSurf);
  vertex(-s, s, 0, 0, 0); 
  vertex(s, s, 0, 1, 0); 
  vertex(s, -s, 0, 1, 1); 
  vertex(-s, -s, 0, 0, 1);
  endShape();
  popMatrix();
}

// Draw on-screen targets, following two constraints:
// (1) is this a MoMa trial (show moving dot)?
// (2) is this the target to be select (in red)?
void drawTargets()
{
  for (int i = 0; i < TARGET_NUM; i++)
  {
    Target target_tmp = targets.get(i);
    target_tmp.draw(inputMode == INPUT_MOMA, trial_order.get(currentTrial) == i);
  }
}


void drawCursor()
{
  sceneSurf.fill(55, 155);
  sceneSurf.strokeWeight(3);

  if (over_target) sceneSurf.stroke(0, 255, 0);
  else sceneSurf.stroke(55);

  sceneSurf.ellipse(cursor_pos.x, cursor_pos.y, CURSOR_SIZE, CURSOR_SIZE);
}


// Return the current coords from the pointing device
PVector getCurrentCoords() 
{
  PVector pt = intersectRayPlane(new PVector(pvr.cameraX, pvr.cameraY, pvr.cameraZ), 
    new PVector(pvr.cameraX + pvr.forwardX, pvr.cameraY - pvr.forwardY, pvr.cameraZ + pvr.forwardZ), 
    new PVector(0, 0, SCENE_DIST), new PVector(0, 0, 1));  
  pt.x += SCENE_SIZE/2; 
  pt.y += SCENE_SIZE/2;
  return pt;
}


// Get the point of ray-plane intersection (P)
public PVector intersectRayPlane(PVector rayOrigin, PVector rayPointOnPath, PVector planePoint, PVector planeNormal) 
{
  PVector P2SubPs = PVector.sub(rayPointOnPath, rayOrigin);
  PVector P3SubPs = PVector.sub(planePoint, rayOrigin);
  float u = planeNormal.dot(P3SubPs) / planeNormal.dot(P2SubPs);
  PVector P = PVector.add(rayOrigin, PVector.mult(P2SubPs, u));
  return P;
}


// Correlates head and target data
//void processIMuData(long now, PGraphicsVR pvr)
void processIMuData(long now, long start, PGraphicsVR pvr)
{
  //  float[] ypFilter     = imuGetAngles();                            // head angles from the Mahony filter 
  float[] headRotation = new float[4];
  pvr.headTransform.getQuaternion(headRotation, 0);
  float[] yprVR        = imuFilter.getYawPitchRoll(headRotation);   // angles from the headtransform in the library

  // Add head data to the store
  /* if (MAHONY) addHeadData(now, ypFilter[0], ypFilter[1]);  
   else*/

  if (yprVR[0] >0)
  {
    yprVR[0] = 180-yprVR[0];
  } else if (yprVR[0] <0)
  {
    yprVR[0] = -yprVR[0]-180;
  }
  addHeadData(now, yprVR[1], yprVR[0]);

  output1.print("*HEAD"+","+yprVR[1]+","+yprVR[0]+",\n");
  output_raw.print("*HEAD"+","+yprVR[1]+","+yprVR[0]);

  // Run the correlations
  int winner = -1;

  if (now - start > MOMA_THRESHOLD)
    winner = correlator.batchMatch_resample(_timeHead, _xHead, _yHead, _timeTargets, _targetXs, _targetYs); 
  if ((winner >= 0 && winner <= TARGET_NUM && now-start > MOMA_THRESHOLD) || (now - start > MOMA_END_THRESHOLD))
  {
    // no match error
    if (now-start > MOMA_END_THRESHOLD) {
      winner = 99;
    }
    //correlator.printDuration();
    //correlator.printCorrels();
    //println("Winner: " + winner);
    //println("TARGET IS : " + trial_order.get(currentTrial));
    //println(" MOMA CAL TIME : " + abs(MOMA_TIMING - now));
    moma_avg = moma_avg + -(MOMA_TIMING - now);
    over_target_num = winner;

    //~~~~~~~~~~~~~~~~~~~
    output1.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+winner+","+(now-MOMA_TIMING)+"\n");
    output_raw.print("\n");
    output_raw.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+winner+","+(now-MOMA_TIMING)+"\n");
    output1.print("\n ###MOMA_CORRELATION_RESULT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+winner+","+(now-MOMA_TIMING)+ "\n");
    output_raw.print("\n ###MOMA_CORRELATION_RESULT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+winner+","+(now-MOMA_TIMING)+ "\n");
    //~~~~~~~~~~~~~~~~~~~

    for (int i=0; i<correlator.corResults.length; i++)
    {  
      //output1.print("\n");
      for (int j=0; j<correlator.corResults[i].length; j++) {
        output1.print( i + ", " +  j + " ," +correlator.corResults[i][j] + "  \n");
        output_raw.print( i + ", " +  j + " ," +correlator.corResults[i][j] + "  \n");
      }
    }
    output1.print("###MOMA_CORRELATION_RESULT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+winner+","+(now-MOMA_TIMING)+"\n");
    output_raw.print("###MOMA_CORRELATION_RESULT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+winner+","+(now-MOMA_TIMING)+"\n");
    selectionTrigger();
    //MOMA_CHECK = false;
  }
}


// Add head data to the store
void addHeadData(long now, float yaw, float pitch)
{
  _timeHead.add(now); 
  _xHead.add(yaw);
  _yHead.add(pitch);


  // Remove old data if we have more than windowSize samples
  if (_timeHead.size() > correlator.windowSize)    
  {
    while (_timeHead.get(1) < now-correlator.sampleDuration && _timeHead.size() > 1)
    {
      _timeHead.remove(0);
      _xHead.remove(0);
      _yHead.remove(0);
    }
  }
}


// Init. the data storage structures for head and target positions
void dataStoreInit()
{
  _timeHead    = new ArrayList<Long> ();
  _xHead       = new ArrayList<Float>();
  _yHead       = new ArrayList<Float>();

  _timeTargets = new ArrayList<Long>();
  _targetXs    = new ArrayList<ArrayList<Float>>(TARGET_NUM);
  _targetYs    = new ArrayList<ArrayList<Float>>(TARGET_NUM);

  for (int i = 0; i < TARGET_NUM; i++)
  {
    ArrayList<Float> xs = new ArrayList<Float>(); 
    _targetXs.add(xs); 
    ArrayList<Float> ys = new ArrayList<Float>();
    _targetYs.add(ys);
  }

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


// Updates the text to be displayed in the menu: where we select the input modality; 
// when we finish a block; and when we complete the study
String refreshTextMenu()
{
  String msg = "";
  // right-left to select mode , up-down for subject number
  if (mode == MODE_CHOOSE) msg = "Input mode: " + MODE_STRINGS[inputMode] + "\nsubject "+subjectNum+"\n\nKeyboard buttons change\nRemote Button selects";
  else if (mode == MODE_BREAK)
  {
    String input_string = "Input mode: " + MODE_STRINGS[inputMode];
    String block_string = "Block: " + (currentBlock + 1) + " of " + BLOCKS;
    String start_string = "Press the remote button\nto continue";  

    msg = input_string + "\n" + block_string + "\n\n" + start_string;
  } else if (mode == MODE_HALF_BREAK) {
    msg = " TAKE A BREAK \n" + (int)remainBreakTime;
  } else if (mode == MODE_END) {
    msg = "Mode completed";
    //Finalise datafile
  } else if (mode == MODE_CENTRE) msg = "Where you're ready to start,\n\nselect the target using the keyboard";

  return msg;
}


// Add target data to the store
void addTargetData(long now, float[] xs, float[] ys)
{
  _timeTargets.add(now); 

  for (int i = 0; i < xs.length; i++)  
  {
    ((ArrayList<Float>)(_targetXs.get(i))).add(xs[i]);
    ((ArrayList<Float>)(_targetYs.get(i))).add(ys[i]);
  }

  // Remove old data
  if (_timeTargets.size() > correlator.windowSize) // if we have more than windowSize samples
  {  
    while (_timeTargets.get(1) < now-correlator.sampleDuration && _timeTargets.size() > 1) // look at the second item
    {
      _timeTargets.remove(0);

      for (int i = 0; i < xs.length; i++)  
      {
        ((ArrayList<Float>)(_targetXs.get(i))).remove(0);
        ((ArrayList<Float>)(_targetYs.get(i))).remove(0);
      }
    }
  }
}


// Handle keyboard inputs
void handleKeyEvent(KeyEvent event)
{
  int _keyCode = event.getKeyCode();
  if (event.getAction() == KeyEvent.RELEASE)
  {
    // What happens when the volume keys are pressed
    if (mode == MODE_CHOOSE)
    { 
      if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_RIGHT)   //KEYCODE_DPAD_DOWN,RIGHT,UP,DOWN  --  KEYCODE_SPACE  -- KEYCODE_VOLUME_UP,DOWN
      {
        inputMode++; 
        if (inputMode >= MODE_STRINGS.length) inputMode = 0;
      } else if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_LEFT)    
      {
        inputMode--; 
        if (inputMode < 0) inputMode = MODE_STRINGS.length-1;
      } else if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_DOWN) {
        subjectNum--;
      } else if (_keyCode == android.view.KeyEvent.KEYCODE_DPAD_UP) {
        subjectNum++;
      }
    }

    // What happens when the space bar is pressed
    if (_keyCode == android.view.KeyEvent.KEYCODE_SPACE || _keyCode == android.view.KeyEvent.KEYCODE_ENTER)      //  KEYCODE_SPACE
    {
      if (mode == MODE_TRIAL && inputMode == INPUT_KEY) 
        selectionTrigger();

      else if (mode == MODE_CENTRE && centreMenuTarget.cursorOver(cursor_pos.x, cursor_pos.y)) 
      {
        selectionTrigger();
        MOMA_CHECK = false;
        DWELL_CHECK = false;
        KEYBOARD_CHECK = false;
      } else if (mode == MODE_CHOOSE)
      {
        mode = MODE_BREAK;
        output_raw = new PrintWriter( createWriter("//sdcard/Download/RawData"+MODE_STRINGS[inputMode]+"_VRv3"+SUBJECT+subjectNum+".csv"));
        output1 = new PrintWriter( createWriter("//sdcard/Download/Data"+MODE_STRINGS[inputMode]+"_VRv3"+SUBJECT+subjectNum+".csv"));

        println("NEW FILE CREATED");
      } else if (mode == MODE_BREAK)
      {
        cursor_pos = getCurrentCoords();
        mode = MODE_CENTRE;
      }
    }
  }
  super.handleKeyEvent(event);
}


// The participant just selected a target
void selectionTrigger()
{
  if (mode == MODE_CENTRE)
  {
    // Prepare the trial
    if (inputMode == INPUT_MOMA)
    {
      // Reset head/target data arrays, and each orbit to their original positions
      orbitResetConstant = (int)random(360);
      for (Target target : targets) target.resetOrbit();
      //();
    } else if (inputMode == INPUT_DWELL) dwellReady = false;

    mode = MODE_TRIAL;

    output1.print("\n ###START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+"\n");
    output_raw.print("\n ###START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+"\n");
  } else if (mode == MODE_TRIAL)
  {
    // Log selection
    // Is this the last block/mode trial?
    correct_selection = false;
    //CHANGE
    if (over_target_num == (int)trial_order.get(currentTrial)) 
    {
      correct_selection = true;
      success++;
    }
    if (inputMode == INPUT_KEY) {
      long temp_time = millis()- KEYBOARD_TIMING;
      keyboard_avg = keyboard_avg +temp_time;
      output1.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("###END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");

      //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~```

      output1.print("\n###KEY_IN_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_IN_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      for (int i =0; i<TARGET_NUM; i++) {
        output1.print(keyboard_IN_count[i]+ ",");
        output_raw.print(keyboard_IN_count[i]+ ",");
        keyboard_IN_count[i] = 0;
      }
      output1.print("\n###KEY_IN_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_IN_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");

      output1.print("\n###KEY_IN_TIME_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_IN_TIME_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      for (int i=0; i<TARGET_NUM; i++) {
        for (int j=0; j <10; j++) {
          output1.print(keyboard_IN_time[i][j]+ ",");
          output_raw.print(keyboard_IN_time[i][j]+ ",");
          keyboard_IN_time[i][j] = 0;
        }
        if (i<TARGET_NUM-1) {
          output1.print("\n");
          output_raw.print("\n");
        }
      }
      output1.print("\n###KEY_IN_TIME_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_IN_TIME_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");

      //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~```
      output1.print("\n");
      output_raw.print("\n");
      output1.print("\n###KEY_OUT_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_OUT_COUNT_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      for (int i =0; i<TARGET_NUM; i++) {
        output1.print(keyboard_OUT_count[i]+ ",");
        output_raw.print(keyboard_OUT_count[i]+ ",");
        keyboard_OUT_count[i] = 0;
      }
      output1.print("\n###KEY_OUT_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_OUT_COUNT_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");

      output1.print("\n###KEY_OUT_TIME_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_OUT_TIME_START,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      for (int i=0; i<TARGET_NUM; i++) {
        for (int j=0; j <10; j++) {
          output1.print(keyboard_OUT_time[i][j]+ ",");
          output_raw.print(keyboard_OUT_time[i][j]+ ",");
          keyboard_OUT_time[i][j] = 0;
        }
        if (i<TARGET_NUM-1) {
          output1.print("\n");
          output_raw.print("\n");
        }
      }
      output1.print("\n###KEY_OUT_TIME_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      output_raw.print("\n###KEY_OUT_TIME_END,"+currentBlock+","+currentTrial+","+trial_order.get(currentTrial)+ ","+(over_target_num == trial_order.get(currentTrial))+","+temp_time+"\n");
      current_Keyboard_target = TARGET_NUM + 10;
      keyboard_ON = false;

      //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    }

    if (currentTrial == TARGET_NUM-1)
    {
      // Finish block (or study, if in the last block)
      if (currentBlock == BLOCKS-1) 
      {
        mode = MODE_END;

        output1.print("\n ###SUMMARY_START \n");
        output_raw.print("\n ###SUMMARY_START \n");
        println("EXPERIMENT OVER");
        println("RATE : " + success+ " / " + ((BLOCKS)*(TARGET_NUM)));
        //println(" AVG time : " + moma_avg/(BLOCKS*TARGET_NUM));
        output1.print("Success Rate : ," + success + " / " + ((BLOCKS)*(TARGET_NUM))+"\n");
        if (inputMode == INPUT_MOMA) {
          output1.print("Average time : ,"+ moma_avg/(BLOCKS*TARGET_NUM)+"\n");
        } else if (inputMode == INPUT_DWELL) {
          output1.print("Average time : ,"+ dwell_avg/(BLOCKS*TARGET_NUM)+"\n");
        } else if (inputMode == INPUT_KEY) {
          output1.print("Average time : ,"+ keyboard_avg/(BLOCKS*TARGET_NUM)+"\n");
        }
        output_raw.print("Success Rate : ," + success + " / " + ((BLOCKS)*(TARGET_NUM))+"\n");
        if (inputMode == INPUT_MOMA) {
          output_raw.print("Average time : ,"+ moma_avg/(BLOCKS*TARGET_NUM)+"\n");
        } else if (inputMode == INPUT_DWELL) {
          output_raw.print("Average time : ,"+ dwell_avg/(BLOCKS*TARGET_NUM)+"\n");
        } else if (inputMode == INPUT_KEY) {
          output_raw.print("Average time : ,"+ keyboard_avg/(BLOCKS*TARGET_NUM)+"\n");
        }
        output1.print("###SUMMARY_END \n");
        output_raw.print("###SUMMARY_END \n");
        output1.flush();
        output_raw.flush();
        println("All data saved");
        if (output1 !=null)
        {
          output1.close();
          println("save file");
        }
        if (output_raw !=null)
        {
          output_raw.close();
          //println("save file");
        }
      } else 
      {
        currentTrial = 0;
        currentBlock++;
        trial_order.shuffle(); // follow order in first trial
        if (currentBlock == (BLOCKS-BLOCKS%2)/2) {
          mode = MODE_HALF_BREAK;
          halfBreak_timing = millis();
        } else {
          mode = MODE_BREAK;
        }

        print("TRIAL " + (TARGET_NUM) + " END...");
        println(" AND BLOCK "+ (currentBlock) + " END, TAKE A BREAK");
      }
    } else
    {
      // Move on to a new trial
      currentTrial++;
      mode = MODE_CENTRE;
      println("TRIAL " + (currentTrial-1) + " END");
    }
  }
}

// Clear head and target data before each trial
void clearCorrelData()
{
  _timeHead.clear(); 
  _xHead.clear(); 
  _yHead.clear(); 
  _timeTargets.clear(); 

  for (int i = 0; i < TARGET_NUM; i++)
  {
    ((ArrayList<Float>)(_targetXs.get(i))).clear();
    ((ArrayList<Float>)(_targetYs.get(i))).clear();
  }
}