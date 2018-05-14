public class Target
{
  private float cX, cY, oX, oY;               // target (fixed) and orbit (moving) positions
  private final float ANGLE_SPEED = 180 / (100/2);      // angle per second  (framerate / two eyes)
  private float starting_angle, angle;        // initial phase position and current orbit angle
  private int direction;                      // 1 (clockwise) or -1 (counterclockwise)
  private float radius;
  private int target_id;                      // 0: corner; 1: edge; 2: centre
  
  
  public Target(int target_id, float cX, float cY, float starting_angle, int direction, float size)
  {
    this.cX = cX;
    this.cY = cY;
    this.starting_angle = starting_angle;
    angle = starting_angle;
    this.direction = direction;
    radius = size / 2;
    this.target_id = target_id;
  }
  
  
  // 0: corner; 1: edge; 2: centre
  public int getTargetID()
  {
    return target_id;
  }
  
  
  // Have the moving target take a step
  public void moveTarget()
  {
    angle += direction * ANGLE_SPEED;
  }
  
  
  // Move the orbit to its original position
  // at the start of the trial
  public void resetOrbit()
  {
    angle = starting_angle + orbitResetConstant;
  } 
  
  
  // Draw on-screen targets, following two constraints:
  // (1) is this a MoMa trial (show moving dot)?
  // (2) is this the target to be selected (in red)?
  public void draw(boolean moma, boolean active)
  {    
    // Non-active targets are displayed in grey
    color orbit_fill = color(55);
    color target_fill = color(155);
    
    // The trial's active target is displayed in red-ish
    if (active)
    {
      orbit_fill = color(255, 0, 0, 155);
      target_fill = orbit_fill;
    }
    sceneSurf.fill(target_fill);
    sceneSurf.stroke(orbit_fill);
    sceneSurf.strokeWeight(3);
    
    sceneSurf.ellipse(cX, cY, radius*2, radius*2);    
    
    // Draw the orbit (if in a MoMa trial)
    if (moma)
    {
      sceneSurf.noStroke();
      sceneSurf.fill(orbit_fill);
      sceneSurf.ellipse(oX, oY, radius/2, radius/2);   
    }
  }
  
  
  // Return the current orbit position (x)
  float getOrbitX()
  {
    return oX;
  }
  
  
  // Return the current orbit position (y)
  float getOrbitY()
  {
    return oY;  
  }
  
  
  // Move the orbit by ANGLE_SPEED
  public void moveOrbit()
  {
    angle += direction * ANGLE_SPEED;
    
    oX = cX + sin(radians(angle)) * radius;
    oY = cY + cos(radians(angle)) * radius;
  }
  
  
  // Returns true if the cursor is over the target
  public boolean cursorOver(float cursorX, float cursorY)
  {
    return sq(cursorX - cX) + sq(cursorY - cY) < sq(radius);
  }
}