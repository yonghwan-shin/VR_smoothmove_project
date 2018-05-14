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
      drawText("Input mode: " + MODE_STRINGS[inputMode] + "\nsubject "+subjectNum+
               "\n(1) All(2/3/4) = false" + 
               "\n(2) Dynamic    = " + APPLY_DYNAMIC + 
               "\n(3) Stop       = " + APPLY_STOP + " / " + APPLY_FEEDBACK + 
               "\n(4) Gaze       = " + APPLY_GAZE + 
               "\n\nKeyboard buttons change\nRemote Button selects"); 
      break; 
    case MODE_BREAK :  
      // drawText("Input mode: " + MODE_STRINGS[inputMode] + "\n" + "Block: " + (currentBlock + 1) + " of " + BLOCKS + "\n" + "Press the remote button\nto continue");
      // if you want to have participants click thorugh block breaks, the above line shows a message about it
      break; 
    case MODE_TRIAL : 
      // show guide <- need more upgrade..
      /*
      float tempX = targets.get(trial_order.get(0)).cX;
      float tempY = targets.get(trial_order.get(0)).cY;
      sceneSurf.stroke(255, 0, 0);
      sceneSurf.strokeWeight(5);
      sceneSurf.line(SCENE_SIZE/2, SCENE_SIZE/2, SCENE_SIZE/2*4/5+tempX/5, SCENE_SIZE/2*4/5+tempY/5);
      */
      // Draw targets
      drawTargets(now);
      if (inputMode != INPUT_MOMA) 
        drawCursor(); // no cursor in Moma condition 
      else if (APPLY_CURSOR)
        drawCursor(); // except when speciically requested 
      break; 
    case MODE_FIX :     
      drawFixation();  
      break;   
    case MODE_RESULT :     
      drawResult(correct_selection);  
      break;     
    case MODE_CENTRE :
      drawText("When you are ready to start,\n\nselect the target using the remote", SCENE_SIZE-SCENE_SIZE/4);
      centreMenuTarget.draw(sceneSurf, false, true, -1, 0);
      drawCursor();
      break; 
    case MODE_END : 
      drawText("Input mode completed.\nTake off the headset.\n" + errorCount + "/" + successCount + "/" + (total_trial_time/successCount)); // we handle auto off in calculate. 
      break; 
    case MODE_HALF_BREAK : 
      drawText("Take a break\n" + (int)((HALFBREAK_TIME - (now-modeChangeTime))/1000));
      break;   
    }  
  sceneSurf.endDraw();

  /*
   * Draws the actual scene by rendering the sceneSurf as a texture on a cube
   */
  pushMatrix();
  
    // VR_SPECIFIC
    translate(0, 0, SCENE_DIST);
    // translate(SCENE_SIZE/2, SCENE_SIZE/2, SCENE_DIST);
    // rotateX(radians(180));
    // END VR_SPECIFIC - remove these two lines and uncomment the first line for VR. 
    
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
void drawTargets(long now)
{
  // need to process each list// TODO - handle collison numbers. We need devide between the two groups TODO
  drawTargetList(now, spinsCW, 0, (int)(-TARGET_SIZE*3/2));
  drawTargetList(now, spinsCCW, spinsCW.getSize(), (int)(+TARGET_SIZE*3/2)); 
}


void drawTargetList(long now, spinners s, int targetNumOffset, int offset)
  {
  for (int i = 0; i < s.getSize(); i++)
    {
    float dwellPercent = 0;
    spinner target_tmp = s.spinners.get(i);
    
    // if its dwell and we are over the current target, calc the dwellPercent and send this to draw function
    if (inputMode == INPUT_DWELL && over_target_num == i+targetNumOffset)
      dwellPercent = ((float) (now - over_target_time) / (float)DWELL_THRESHOLD);
      
    target_tmp.draw(sceneSurf, inputMode == INPUT_MOMA, trial_order.get(0) == (i+targetNumOffset), dwellPercent, offset);
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

// draws the cursor. 
void drawCursor()
{
  sceneSurf.fill(55, 155);
  sceneSurf.strokeWeight(3);

  if (over_target) sceneSurf.stroke(0, 255, 0);
  else sceneSurf.stroke(55);

  sceneSurf.ellipse(cursor_pos.x, cursor_pos.y, CURSOR_SIZE, CURSOR_SIZE);
}