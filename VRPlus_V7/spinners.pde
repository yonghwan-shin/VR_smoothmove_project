/*
 * Two utility functions
 */
// wraps around a zero point to a range
float wrap(float in, float range)
  {if (in<0.0) return 1.0+in;
  return in;}
  
 // modulus that wraps around 0 - e.g. "7 mod 8 = 7" and "-1 mod 8 = 7"
int negMod(int n, int m)
  {while (n<0) n+=m;
  return n%m;}
  
/*
 * Debug draw mode
 */
boolean drawCenterDebug = false;  // debug - TODO turn off spinning for debug...
boolean drawRegular     = true;   // regular
  
/* 
 * Defaults for targets. Not really important. 
 */
int DEFAULT_TYPE          = 2; 
float DEFAULT_X           = 0;
float DEFAULT_Y           = 0; 
float DEFAULT_SPIN_RADIUS = TARGET_SIZE/2; // 62.5 + TARGET_SIZE/2; // this is the target spacing...  
float DEFAULT_DRAW_RADIUS = TARGET_SIZE/4; 

/*
 * single spinner
 */
class spinner
  {
  private float cX, cY;     // center of this spinner's spin
  private float spinRadius; // radius of the spinner's spin 
  private float aPos;       // angular position of this spinner
  private float sPos;       // starting angular position of this spinner
  private float drawRadius; // draw radius of the spinners "marker"
  private int target_id;    // 0: corner; 1: edge; 2: centre // not used
  private float colorPerc;  // 0 - 1 between neutral and highlight colors
  private boolean adding;   // whethe we just added higlighting
  
  boolean enabled; 
  
  spinner(int target_id, float cX, float cY, float aPos, float spinRadius, float drawRadius)
    {
    this.cX = cX;
    this.cY = cY;
    this.aPos = aPos;
    this.sPos = aPos;
    this.spinRadius = spinRadius;
    this.drawRadius = drawRadius;
    this.target_id = target_id;
    this.colorPerc = 0;
    adding = false;
    enabled = true;
    }
    
  spinner(float aPos)
    {
    this(DEFAULT_TYPE, DEFAULT_X, DEFAULT_Y, aPos, DEFAULT_SPIN_RADIUS, DEFAULT_DRAW_RADIUS); 
    }
    
  float getPos() {return aPos;}
  void setPos(float nPos) {aPos = nPos;}; 
  
  float getStartPos() {return sPos;}
  void setStartPos(float nPos) {sPos = nPos;}; 
  
  PVector getScreenCoords()
    {return new PVector (cX, cY);}
  

  
  void config(int target_id, float cX, float cY, float aPos, float spinRadius, float drawRadius)
    {
    this.aPos = aPos; 
    this.sPos = aPos; 
    config(target_id, cX, cY, spinRadius, drawRadius); 
    }
  
  void config(int target_id, float cX, float cY, float spinRadius, float drawRadius)
    {
    this.cX = cX;
    this.cY = cY;
    this.spinRadius = spinRadius;
    this.drawRadius = drawRadius;
    this.target_id = target_id;
    this.colorPerc = 0; 
    adding = false;
    }
    
  void config(int target_id, float cX, float cY)
    {
    this.cX = cX;
    this.cY = cY;
    this.target_id = target_id;
    this.colorPerc = 0; 
    adding = false;
    }
  
  void blankHighlight()
    {colorPerc = 0;}
    
  void removeHighlight(long duration)
    {
    // we remove whole thing over 200ms (so from 1->0)
    if (adding)
      adding = false; // except when adding
    else
      {
      float perc = 1.0 / (MOMA_FEEDBACK_OFF/(float)duration); 
      colorPerc = max (0.0, colorPerc - perc);
      }
    }
    
  void addHighlight(long duration)
    {
    // we add whole thing over 100ms (so from 0->1)
    float perc = 1.0 / (MOMA_FEEDBACK_ON/(float)duration); 
    colorPerc = min (1.0, colorPerc + perc); 
    adding = true;
    }
    
    
  void enable() {enabled = true;}
  void disable() {enabled = false;}
  boolean isEnabled() {return enabled;}
    
  // Returns true if the cursor is over the target
  public boolean cursorOver(float cursorX, float cursorY)
    {
    return sq(cursorX - cX) + sq(cursorY - cY) < sq(drawRadius*2);
    }
    
  
  float getOrbitX()
    {
    return cX + sin(radians(aPos*360.0))*spinRadius;
    }
    
  float getOrbitY()
    {
    return cY + cos(radians(aPos*360.0))*spinRadius;
    }
    
  void reset(float orbitResetConstant) // this is a % (0-1)
    {
    aPos = sPos + orbitResetConstant;
    blankHighlight();
    }
    
    
    
  public void draw(PGraphics sceneSurf, boolean moma, boolean active, float fusePercent, int offset)
  {    
    // Non-active targets are displayed in grey to red
    color orbit_fill =  color(55); // dark grey moving orbit
    color target_fill = lerpColor(color(155, 155, 155, 155), color(255, 0, 0, 155), colorPerc); // grey to red

    // The trial's active target is displayed in red-ish
    if (active)
    {
      orbit_fill = color (0, 255, 0);      // moving orbit is solid green
      target_fill = lerpColor(color(0, 0, 255, 155), color(255, 0, 0, 155), colorPerc); // blue to red 
    }
    sceneSurf.fill  (target_fill);
    sceneSurf.stroke(target_fill);
    sceneSurf.strokeWeight(3);
    
    sceneSurf.ellipse(cX, cY, spinRadius*2, spinRadius*2);    

    // Draw the orbit (if in a MoMa trial)
    if (moma)
    {
      if (drawRegular && enabled)
        {
        sceneSurf.stroke(orbit_fill);
        sceneSurf.fill(orbit_fill);
        sceneSurf.strokeWeight(1);
        sceneSurf.ellipse(getOrbitX(), getOrbitY(), spinRadius/2, spinRadius/2);
        }
      
      if (drawCenterDebug)
        sceneSurf.ellipse(getOrbitX() - cX + SCENE_SIZE/2, getOrbitY() - cY + SCENE_SIZE/2 + offset, spinRadius/2, spinRadius/2); 
        
    }
    
    
    if (fusePercent>0)
      {
      sceneSurf.noFill();
      sceneSurf.stroke(0);
      sceneSurf.strokeWeight(2);
      sceneSurf.arc(cX, cY, spinRadius*2.4, spinRadius*2.4, PI+HALF_PI, TWO_PI*(fusePercent+0.75));
      }
    }
  }





/*
 * Spinners class
 */
class spinners  
  {
  ArrayList<spinner> spinners = null; // the spinners
  boolean animate;                    // whether they are rotating
  float spinnerDir;                   // the direction the spinners are going
  
  /* 
   * Constructor: pass in the number of spinners. 
   */
  spinners(int n)
    { 
    if (n<3) n = 3; // this is the minimum
    animate = true; 
    spinnerDir = 1.0; 
    
    spinners = new ArrayList<spinner>();   
    for (int i=0;i<n;i++)
      {
      spinner s = new spinner(wrap((float)i/(float)n, 1.0)); // evenly spaced.
      spinners.add(s); 
      }
    }

  // basic functions
  void addSpinner() {spinners.add(new spinner(spinners.get(spinners.size()-1).getPos()+0.001));}  // add a spinner
  void removeSpinner(){if (spinners.size()>3) spinners.remove(spinners.size()-1);}                // remove a spinner
  int getSize() {return spinners.size();}                                                         // count the spinners
  spinner getSpinner(int i) {return spinners.get(i);}                                             // get a spinner
  void toggleSpinning() {animate=!animate;}                                                       // toggle the animation
  void setCCW() {spinnerDir = -1;}                                                                // set to CCW
  void setCW()  {spinnerDir =  1;}                                                                // set to CW
  
  void configSpinner(int i, int target_id, float cX, float cY, float aPos, float spinRadius, float drawRadius)
    {
    spinner s = spinners.get(i); 
    s.config(target_id, cX, cY, aPos, spinRadius, drawRadius); 
    }

  /* 
   * Update the "spring" simulation
   * Takes a set of values expressing the "power" of each target. We will need to experiment to figure out what works well 
   * We want to ignore not matching (inverse correls). Be careful with abs() here. Check this case out.
   */
  void updateSpinners(boolean useWeights, float[] weights, long duration)
    {
    if (weights.length != spinners.size()) return; 
    
    // here we just spin simply
    if (!useWeights)
      {
      if (animate)
        {
        for (int i=0;i<spinners.size();i++)
          {
          float spinnerSpeed = (ANGLE_SPEED_TARGET/1000.0) * duration; // speed per ms by duration in ms. 
          spinners.get(i).setPos(spinners.get(i).getPos() + map(spinnerSpeed*spinnerDir, 0, 360, 0, 1)); // expressed in 0-1 spinners scale?
          spinners.get(i).removeHighlight(duration); // remove from all
          }
        }
      return; 
      }
      
   // below we use the weights to equally separate the spinners
    
    /*
     * calculate the forces exerted on each spinner from the two adjacent ones
     */ 
    int last = spinners.size()-1;
    float[] forceToApply = new float[spinners.size()];
    for (int i=1;i<spinners.size()-1;i++)
      forceToApply[i]    = calcForce(spinners.get(i-1).getPos(),    spinners.get(i).getPos(),    spinners.get(i+1).getPos(), weights[i-1],    weights[i+1]);  // middle targets - THIS IS IN THE LOOP!
      forceToApply[0]    = calcForce(spinners.get(last).getPos(),   spinners.get(0).getPos(),    spinners.get(1).getPos(),   weights[last],   weights[1]); // first target   - NOT IN THE LOOP
      forceToApply[last] = calcForce(spinners.get(last-1).getPos(), spinners.get(last).getPos(), spinners.get(0).getPos(),   weights[last-1], weights[0]); // last target    - NOT IN THE LOOP
      
    /*
     * Find the two spinners with the "greatest and second greatest focus" (largest correl vals)
     * Also apply a scaling factor to the force calc (basically an "easing" divider). 
     */
    float maxFocus    =  0;
    int maxFocusIndex = -1;
    for (int i=0;i<spinners.size();i++)
      {
      forceToApply[i] = forceToApply[i]/BASIC_DEVISOR; // easing 
      
      if (abs(weights[i]) > maxFocus)                  // finding "greatest focus" target
        {
        maxFocus = abs(weights[i]); 
        maxFocusIndex = i; 
        }
      }
    
    float secondFocus    =  0;
    int secondFocusIndex = -1;
    if (maxFocusIndex>=0)
      {
      weights[maxFocusIndex] = 0; // tmp change 
      for (int i=0;i<spinners.size();i++)
        {
        if (abs(weights[i]) > secondFocus)                  // finding "second greatest focus" target
          {
          secondFocus = abs(weights[i]); 
          secondFocusIndex = i; 
          }
        }
      weights[maxFocusIndex] = maxFocus; // reset the original max
      }
      
    /* 
     * If "greatest focus" is over a given threshold, adjust all spinner speeds to get this on-focus spinner steady.
     * This means the focused on spinner should always keep a stable velocity as other targets move to adjust to its strength. 
     * In the case we are doing this with two spinners, the effects generally (but not always) cancel out. Not sure its worth it. 
     */
    float overallAdj    = 0; 
    if (maxFocus > FOCUS_THRESHOLD)
      {
      if (maxFocusIndex>=0 && secondFocusIndex>=0)
        {
        overallAdj = (forceToApply[maxFocusIndex] + forceToApply[secondFocusIndex])/2.0; // this probably cancels out in many cases......
        //println("Focus", forceToApply[maxFocusIndex], forceToApply[secondFocusIndex]); 
        }
      else if (maxFocusIndex>=0)
        overallAdj = forceToApply[maxFocusIndex]; // when just one target, stablize that one. 
      }
      
    /*
     * Update the spinner positions
     */
    for (int i=0;i<spinners.size();i++)
      {
      if (animate)
        {
        float spinnerSpeed = (ANGLE_SPEED_TARGET/1000.0) * duration; // speed per ms by duration in ms. 
        // println("moving", spinnerSpeed, "degrees in", duration, "ms");
        spinners.get(i).setPos(spinners.get(i).getPos() + map(spinnerSpeed*spinnerDir, 0, 360, 0, 1)); // expressed in 0-1 spinners scale?
        }
      spinners.get(i).setPos(spinners.get(i).getPos() + forceToApply[i] - overallAdj);  
      spinners.get(i).removeHighlight(duration); // remove from all
      }
    }
    
    
  /*
   * Calc the forces to apply to a spinner. Basically the ratio of the distance*strength between it and the two ajacent targets
   */
  float calcForce(float one, float two, float three, float weightCCW, float weightCW)
    {
    // get the relative distances between the spinners
    float CCW = one-two; 
    if (CCW>0)
      CCW = -1.0+one-two;  
    float CW = three-two;
    if (CW<0)
      CW = 1.0-two+three;
    
    // if the weights from the targets are non-zero, apply them
    if (weightCCW>0)
      CCW/=weightCCW; 
    if (weightCW >0)
      CW /=weightCW;
      
    return CCW+CW;
    }
    
    
  // return the index of the selected spinner, or -1 if none.
  public int cursorOver(float cursorX, float cursorY)
    {
    for (int i=0;i<spinners.size();i++)
      if (spinners.get(i).cursorOver(cursorX, cursorY))
        return i; 
    return -1;
    }  
    
  public void draw(PGraphics sceneSurf, boolean moma, int active, float fusePercent, int offset)
    {
    for (int i=0;i<spinners.size();i++)
      spinners.get(i).draw(sceneSurf, moma, active==i, fusePercent, offset); 
    }
  
  public void resetOrbits(int orbitResetConstant)
    {
    // turn into 0-1
    float percent = (float)orbitResetConstant / 360.0; 
    for (int i=0;i<spinners.size();i++)
      spinners.get(i).reset(percent);
    }
 
  }