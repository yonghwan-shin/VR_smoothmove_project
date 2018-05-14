import processing.vr.*;

int subjectNum                = 1;           // subject number - can be modified in the app (with keyboard buttons)
PVector cursor_pos;

// Scene sizes/parameters
PGraphicsVR pvr;
PGraphics sceneSurf;
final int   SCENE_SIZE     = 400;          // the VR scene size (where we draw our targets)
final float SCENE_DIST     = 0;            // scene distance from the viewer  -> 500 MAX(camera) originally set as 1.
final float TARGET_SIZE    = 40;           // target diameter.
final float CURSOR_SIZE    = TARGET_SIZE/3;// as it says... 
final int   FRAMERATE      = 100;          // measured as roughly 100 in daydream. Can not control. Slows down with correlations - CAN BE PROBLEM

void setup()
{  
  fullScreen(STEREO);        // try mono for speed?
  initScene();               // start the VR scene
}

void initScene()
{
  cameraUp();
  textureMode(NORMAL);
  sceneSurf = createGraphics(SCENE_SIZE, SCENE_SIZE);
}

void draw()
{  
  background(255);
  pvr = (PGraphicsVR)g;
  drawScene();
}


void calculate()
{
  //if (output_data == null || output_raw == null) return; // dumb check for files - FIXME

  long now = millis();              // records the current time
  cursor_pos = getCurrentCoords();  // updates the current cursor coords
  
  println(cursor_pos);
  //checkCursoHover(now);            // records what target we are no (if any) 
}


PVector getCurrentCoords() 
{
  PVector pt = intersectRayPlane(new PVector(pvr.cameraX, pvr.cameraY, pvr.cameraZ), 
    new PVector(pvr.cameraX + pvr.forwardX, pvr.cameraY - pvr.forwardY, pvr.cameraZ + pvr.forwardZ), 
    new PVector(0, 0, SCENE_DIST), new PVector(0, 0, 1));  
  pt.x += SCENE_SIZE/2; 
  pt.y += SCENE_SIZE/2;
  return pt;
}

void handleKeyEvent(KeyEvent event)
{
  super.handleKeyEvent(event);
}
