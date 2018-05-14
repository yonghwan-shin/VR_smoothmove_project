String file = "response_data_Dwell_VRv2_PILOT_2.csv";

String[] lines;

final String TAG_START = "###START"; 
final String TAG_END = "###END"; 

boolean showAll = false;
boolean showAllMotion = true;
int bNum = 0;
int tNum = 0;


void processFile()
  {
  lines = loadStrings(file); 
  
  // get get the first trial for now.
  int lineNum = 0; 
  
  while (lineNum<lines.length)
    {
    int startLine = -1; 
    int   endLine = -1; 
     
    while (lineNum<lines.length)
      {
      if (trim(lines[lineNum]).length()>=TAG_START.length() && (trim(lines[lineNum]).substring(0, TAG_START.length()).equals(TAG_START)))
        break;
      lineNum++;
      }
    if (lineNum>=lines.length) break;
    startLine = lineNum; 
    
    while (lineNum<lines.length)
      {
      if (trim(lines[lineNum]).length()>=TAG_END.length() && (trim(lines[lineNum]).substring(0, TAG_END.length()).equals(TAG_END)))
        break;
      lineNum++;
      }
    if (lineNum>=lines.length) break;
    endLine = lineNum; 
    
    if (endLine!=-1 && startLine!=-1)
      {
      ArrayList<String> trialData = new ArrayList<String>();
      for (int i=startLine;i<=endLine;i++)
        trialData.add(lines[i]); 
      processTrialData(trialData); 
      }
   }
  }

void setup()
  {
  size(400,400); 
  background(255); 
  textAlign(CENTER, CENTER); 
  textSize(24); 
  fill(0);
  text("trial: "+tNum+", block: "+bNum, width/2, 20);
  processFile(); 
  }
  
void draw()
  {
  }
  
void keyPressed()
  {
  if (key==' ')
    showAll=!showAll;
  else if (key=='a')
    showAllMotion=!showAllMotion;
  else if (key==CODED)
    {
    if (keyCode==RIGHT)
      {
      tNum++;
      if (tNum>7) tNum = 0;
      }
    else if (keyCode==LEFT)
      {
      tNum--;
      if (tNum<0) tNum = 7;
      }
    else if (keyCode==UP)
      {
      bNum++;
      if (bNum>19) bNum = 0;
      }
    else if (keyCode==DOWN)
      {
      bNum--;
      if (bNum<0) bNum = 19;
      }
    }
      
  background(255);
  fill(0);
  text("trial: "+tNum+", block: "+bNum, width/2, 20);
  processFile();
  }