import processing.vr.*;


// SCENE PARAMETERS
PGraphicsVR pvr;
int sceneSize            = 400;        // the VR scene size (where we draw our targets)
int sceneDist            = 1;          // scene distance from the viewer
PGraphics sceneSurf;
final int FRAMERATE      = 60;
final float TARGET_SIZE  = 50;         // target diam.

// INPUT PARAMETERS
final float DWELL_ACTIVATION_THRESHOLD = sceneSize * 0.25;
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
final int MODE_END    =  2;                // end of study
// -
final int BLOCKS = 5;                      // trial blocks (ignore the first?)
final int TARGET_NUM = 8;
int mode = MODE_CHOOSE;
int currentBlock;
int currentTrial;
IntList trial_order = new IntList();       // order in which targets are selected


// I/O
ArrayList<Long>   _timeHead;               // head data
ArrayList<Float>  _xHead;                  
ArrayList<Float>  _yHead;
final boolean MAHONY = false;              // use our own IMU filter or the angles from the VR headtransform
// -
ArrayList<Long>   _timeTargets;            // target data
ArrayList<ArrayList<Float>> _targetXs;     
ArrayList<ArrayList<Float>> _targetYs;
ArrayList<Target> targets;
// - 
Correlator correlator;                     // the correlator
// -
PVector cursor_pos;                        // cursor coordinates on-scene
boolean over_target = false;               // draws the cursor with an highlight to indicate it is over a target
final float CURSOR_SIZE = sceneSize/30;    

void setup()
{
  fullScreen(STEREO);  
  initScene();                // start the VR scene
  
  for (int i = 0; i < TARGET_NUM; i++) trial_order.append(i);
  dataStoreInit();            // prepare data structures
  imuInit(false);             // start the IMU   
  correlator = new Correlator(TARGET_NUM, FRAMERATE, 0.8, FRAMERATE);
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
  sceneSurf = createGraphics(sceneSize, sceneSize);
}


// Called once per frame, right before draw()
// (instead of once per eye)
void calculate()
{
  long now = millis();
  
  if (mode == MODE_TRIAL)
  {
    if (inputMode == INPUT_MOMA)
    {
      // Process target data)     
      for (Target target : targets) target.moveOrbit();
      
      float[] xs  = new float[TARGET_NUM];
      float[] ys  = new float[TARGET_NUM];
      
      for (int i = 0; i < TARGET_NUM; i++)
      {
        Target target_tmp = targets.get(i);
        xs[i] = target_tmp.getOrbitX();
        ys[i] = target_tmp.getOrbitY();
      }
      
      addTargetData(now, xs, ys);          // process target data
      processIMuData(now, pvr);            // process head data
    }
    else
    {
      // Get the latest cursor coordinates
      cursor_pos = getCurrentCoords();
      over_target = cursorHover();
    }
  }
}


// Returns true if the cursor is over a target
boolean cursorHover()
{
  for (Target target : targets)
    if (target.cursorOver(cursor_pos.x, cursor_pos.y)) return true;

  return false;
}


// Draws everything the user sees
void drawScene()
{
  // Draws text, targets and/or cursor on the surface of the scene
  sceneSurf.beginDraw();
    sceneSurf.background(255);
    
    if (mode == MODE_TRIAL)
    {
      // Draw targets
      drawTargets();
      
      if (inputMode != INPUT_MOMA)
      {
        // Draw the cursor (in the keyboard and dwell conditions)
        sceneSurf.fill(55, 155);
        sceneSurf.strokeWeight(3);
        
        if (over_target) sceneSurf.stroke(0, 255, 0);
        else sceneSurf.stroke(55);
        
        println("crashing here? 1");
        sceneSurf.ellipse(cursor_pos.x, cursor_pos.y, CURSOR_SIZE, CURSOR_SIZE);
        println("crashing here? 2");
      }
    }
    else
    {
      String msg = refreshTextMenu();        // defines what's written as a text menu
      sceneSurf.fill(0); 
      sceneSurf.textSize(20); 
      sceneSurf.textAlign(CENTER, CENTER);
      sceneSurf.textLeading(20);
      sceneSurf.text(msg, sceneSize/2, sceneSize/2);  
    }
  sceneSurf.endDraw();
  
  noFill(); strokeWeight(8); stroke(128);
  
  // Draws the actual scene
  pushMatrix();   
    translate(0, 0, sceneDist);
    int s = sceneSize/2; 
    stroke(55);  
    beginShape(QUADS); 
      texture(sceneSurf);
      vertex(-s, s, 0, 0, 0); vertex(s, s, 0, 1, 0); vertex(s, -s, 0, 1, 1); vertex(-s, -s, 0, 0, 1);
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


// Return the current coords from the pointing device
PVector getCurrentCoords() 
{
  PVector pt = intersectRayPlane(new PVector(pvr.cameraX, pvr.cameraY, pvr.cameraZ), 
                                 new PVector(pvr.cameraX + pvr.forwardX, pvr.cameraY - pvr.forwardY, pvr.cameraZ + pvr.forwardZ), 
                                 new PVector(0, 0, sceneDist), new PVector(0, 0, 1));  
  pt.x += sceneSize/2; 
  pt.y += sceneSize/2;
  return pt;
}


// Get the point of ray-plane intersection (P)
public PVector intersectRayPlane(PVector rayOrigin, PVector rayPointOnPath, PVector planePoint, PVector planeNormal) 
{
  PVector P2SubPs = PVector.sub(rayPointOnPath,rayOrigin);
  PVector P3SubPs = PVector.sub(planePoint,rayOrigin);
  float u = planeNormal.dot(P3SubPs) / planeNormal.dot(P2SubPs);
  PVector P = PVector.add(rayOrigin, PVector.mult(P2SubPs,u));
  return P;
}


// Correlates head and target data
void processIMuData(long now, PGraphicsVR pvr)
{
  float[] ypFilter     = imuGetAngles();                            // head angles from the Mahony filter 
  float[] headRotation = new float[4];
  pvr.headTransform.getQuaternion(headRotation, 0);
  float[] yprVR        = imuFilter.getYawPitchRoll(headRotation);   // angles from the headtransform in the library
  
  // Add head data to the store
  if (MAHONY) addHeadData(now, ypFilter[0], ypFilter[1]);  
  else addHeadData(now, yprVR[1], yprVR[0]);
  
  // Run the correlations
  int winner = correlator.batchMatch_resample(_timeHead, _xHead, _yHead, _timeTargets, _targetXs, _targetYs); 
  println("Winner: " + winner);
  
  if (winner >= 0 && winner <= TARGET_NUM)
  {
    selectionTrigger();
    // Log selection
  }
}


// Add head date to the store
void addHeadData(long now, float yaw, float pitch)
{
  _timeHead.add(now); 
  _xHead.add(yaw);
  _yHead.add(pitch);

  // Remove old data if we have more than windowSize samples
  if (_timeHead.size()>correlator.windowSize)    
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
  
  // Corners
  targets.add(new Target(0, tSpace,           tSpace,           0,   1, TARGET_SIZE));   // bottom left
  targets.add(new Target(0, tSpace,           sceneSize-tSpace, 90,  1, TARGET_SIZE));   // top left
  targets.add(new Target(0, sceneSize-tSpace, sceneSize-tSpace, 180, 1, TARGET_SIZE));   // top right
  targets.add(new Target(0, sceneSize-tSpace, tSpace,           270, 1, TARGET_SIZE));   // bottom right
  
  // Edges
  targets.add(new Target(1, sceneSize/2,      sceneSize-tSpace, 0,   -1, TARGET_SIZE));  // top
  targets.add(new Target(1, sceneSize/2,      tSpace,           90,  -1, TARGET_SIZE));  // bottom
  targets.add(new Target(1, tSpace,           sceneSize/2,      180, -1, TARGET_SIZE));  // left
  targets.add(new Target(1, sceneSize-tSpace, sceneSize/2,      270, -1, TARGET_SIZE));  // right
}


// Updates the text to be displayed in the menu: where we select the input modality; 
// when we finish a block; and when we complete the study
String refreshTextMenu()
{
  String msg = "";
  
  if (mode == MODE_CHOOSE) msg = "Input mode: " + MODE_STRINGS[inputMode] + "\n\nVol. buttons change\nSpace bar selects";
  else if (mode == MODE_BREAK)
  {
    String input_string = "Input mode: " + MODE_STRINGS[inputMode];
    String block_string = "Block: " + (currentBlock + 1) + " of " + BLOCKS;
    String start_string = "Press the space bar\nto start";  
    
    msg = input_string + "\n" + block_string + "\n\n" + start_string;
  }
  else if (mode == MODE_END) msg = "Mode completed";
  
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
    // Input selection menu
    if (mode == MODE_CHOOSE)
    { 
      if (_keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN)
      {
        inputMode++; 
        if (inputMode >= MODE_STRINGS.length) inputMode = 0;  
      }
      else if (_keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP)
      {
        inputMode--; 
        if (inputMode < 0) inputMode = MODE_STRINGS.length-1;  
      }
      else if (_keyCode == android.view.KeyEvent.KEYCODE_SPACE)
      {
        mode = MODE_BREAK;
      }
    }
    // Trial during keyboard input modality
    else if (mode == MODE_TRIAL && inputMode == INPUT_KEY && _keyCode == android.view.KeyEvent.KEYCODE_SPACE)
    {
      if (over_target) selectionTrigger();  
    }
    // Starting a new block
    else if (mode == MODE_BREAK && _keyCode == android.view.KeyEvent.KEYCODE_SPACE)
    {
      // Prepare new block
      trial_order.shuffle();
      mode = MODE_TRIAL;
    }
  }
  super.handleKeyEvent(event);
}


// The participant just selected a target
void selectionTrigger()
{
  if (inputMode == INPUT_MOMA)
  {
    for (Target target : targets) target.resetOrbit();
    clearCorrelData();
  }
  
  if (currentTrial == TARGET_NUM-1)
  {
    // Finish block (or study, if in the last block)
    if (currentBlock == BLOCKS-1) mode = MODE_END;
    else 
    {
      currentTrial = 0;
      currentBlock++;
      mode = MODE_BREAK;
    }
  }
  else
  {
    // Move on to a new target
    currentTrial++;
    // Log selection
  }
}


// Clear head and target data before each trial
void clearCorrelData()
{
  _timeHead.clear();    _xHead.clear();     _yHead.clear(); 
  _timeTargets.clear(); _targetXs.clear();  _targetYs.clear();  
}