// Draws everything the user sees
void drawScene()
{
  // Draws text, targets and/or cursor on the surface of the scene
  sceneSurf.beginDraw();
  sceneSurf.background(255);
  // once is enough for these settings? 
  sceneSurf.fill(0); 
  sceneSurf.textSize(20); 
  sceneSurf.textAlign(CENTER, CENTER);
  sceneSurf.textLeading(20);
  
  long now = millis(); 

  sceneSurf.endDraw();

  /*
   * Draws the actual scene by rendering the sceneSurf as a texture on a cube
   */
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





// draw fixation - this is a black "+" symbol
void drawFixation()
{
  sceneSurf.strokeWeight(3);
  sceneSurf.stroke(0); 
  int c = SCENE_SIZE/2; 
  int m = SCENE_SIZE/20;
  sceneSurf.line(c-m, c, c+m, c);
  sceneSurf.line(c, c-m, c, c+m);
}

void drawText(String str) {drawText(str, SCENE_SIZE/2);}
void drawText(String str, int h) {sceneSurf.text(str, SCENE_SIZE/2, h);}

// draws the cursor. 
void drawCursor()
{
  sceneSurf.fill(55, 155);
  sceneSurf.strokeWeight(3);

  //if (over_target) sceneSurf.stroke(0, 255, 0);
  //else sceneSurf.stroke(55);

  sceneSurf.ellipse(cursor_pos.x, cursor_pos.y, CURSOR_SIZE, CURSOR_SIZE);
}
