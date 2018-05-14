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

  switch (mode)
    {
    case MODE_CHOOSE : 
      drawText("Input mode: " + MODE_STRINGS[inputMode] + "\nsubject "+subjectNum+"\n\nKeyboard buttons change\nRemote Button selects"); 
      break; 
    case MODE_BREAK :  
      drawText("Input mode: " + MODE_STRINGS[inputMode] + "\n" + "Block: " + (currentBlock + 1) + " of " + BLOCKS + "\n" + "Press the remote button\nto continue");  
      break; 
    case MODE_TRIAL : 
      // show guide <- need more upgrade..
      float tempX = targets.get(trial_order.get(0)).cX;
      float tempY = targets.get(trial_order.get(0)).cY;
      sceneSurf.stroke(255, 0, 0);
      sceneSurf.strokeWeight(5);
      sceneSurf.line(SCENE_SIZE/2, SCENE_SIZE/2, SCENE_SIZE/2*4/5+tempX/5, SCENE_SIZE/2*4/5+tempY/5);
      // Draw targets
      drawTargets();
      if (inputMode != INPUT_MOMA) 
        drawCursor(); // no cursor in Moma condition
      break; 
    case MODE_FIX :     
      drawFixation();  
      break;   
    case MODE_RESULT :     
      drawResult(correct_selection);  
      break;     
    case MODE_CENTRE :
      drawText("When you are ready to start,\n\nselect the target using the remote", SCENE_SIZE-SCENE_SIZE/4);
      centreMenuTarget.draw(false, true);
      drawCursor();
      break; 
    case MODE_END : 
      drawText("Input mode completed");
      break; 
    case MODE_HALF_BREAK : 
      drawText("Take a break\n" + (int)((HALFBREAK_TIME - (now-modeChangeTime))/60));
      break;   
    }  
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




// Draw on-screen targets, following two constraints:
// (1) is this a MoMa trial (show moving dot)?
// (2) is this the target to be select (in red)?
void drawTargets()
{
  for (int i = 0; i < TARGET_NUM; i++)
  {
    Target target_tmp = targets.get(i);
    target_tmp.draw(inputMode == INPUT_MOMA, trial_order.get(0) == i);
  }
}



// draw an X or a tick depending on outcome - TODO
void drawResult(boolean success)
{
  sceneSurf.strokeWeight(3);
  int c = SCENE_SIZE/2; 
  int m = SCENE_SIZE/10;
  
  if (success)
    {
    sceneSurf.stroke(0, 255, 0);
    int m4 = m/4;
    sceneSurf.line(c-m4*3, c,      c-m4, c+m4*2); // 1/8, 1/2 -> 3/8, 3/4
    sceneSurf.line(c+m4*3, c-m4*2, c-m4, c+m4*2); // 7/8, 1/4 -> 3/8, 3/4
    }
  else
    {
    sceneSurf.stroke(255, 0, 0);
    int m3_4 = m/4*3;
    sceneSurf.line(c-m3_4, c-m3_4, c+m3_4, c+m3_4);
    sceneSurf.line(c-m3_4, c+m3_4, c+m3_4, c-m3_4);
    }
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

void drawCursor()
{
  sceneSurf.fill(55, 155);
  sceneSurf.strokeWeight(3);

  if (over_target) sceneSurf.stroke(0, 255, 0);
  else sceneSurf.stroke(55);

  sceneSurf.ellipse(cursor_pos.x, cursor_pos.y, CURSOR_SIZE, CURSOR_SIZE);
}