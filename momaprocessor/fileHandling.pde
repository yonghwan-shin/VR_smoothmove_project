ArrayList filesToArrayList(String fPath) 
{
  return filesToArrayList(fPath, "");
}  


/*
 * Returns list of files in a dir that start with a specific prefix; doesn't handle bad path gracefully. Beware.
 */
ArrayList filesToArrayList(String fPath, String prefix) 
{
  ArrayList<File> filesList = new ArrayList<File>();
  String folderPath = fPath;
  //println(fPath);
  if (folderPath != null) 
  {
    File file = new File(folderPath); 
    File[] files = file.listFiles();
    for (int i = 0; i < files.length; i++) 
      {
      if (prefix.equals(files[i].getName().substring(0,prefix.length())))
        {filesList.add(files[i]);}
      }
  }
  return(filesList);
}  


/*
 * Returns list of files in a dir that start with a specific prefix; doesn't handle bad path gracefully. Beware.
 */
ArrayList filesToArrayList(String fPath, String prefix, String prefix2) 
{
  ArrayList<File> filesList = new ArrayList<File>();
  String folderPath = fPath;
  if (folderPath != null) 
  {
    File file = new File(folderPath); 
    File[] files = file.listFiles();
    if (files==null)
      {println("No files found."); return null;}
    for (int i = 0; i < files.length; i++)   
      {
      if ((prefix.equals (files[i].getName().substring(0,prefix.length() ))) ||
          (prefix2.equals(files[i].getName().substring(0,prefix2.length()))) )
        {filesList.add(files[i]);}
      }
  }
  return(filesList);
}    


// get all the files from a folder type (Log_all, Log_eye, Log_head)
ArrayList processFiles(boolean useFlat, String pathPrefix, String fileContents, String fileContents2)
  {
  ArrayList<File> flat = new ArrayList<File>();
  ArrayList<File> hier = new ArrayList<File>();
  
  flat = filesToArrayList(sketchPath() + "/" + pathPrefix); 
   
  if (!useFlat)
    {
    // its hierarichal - look for filePrefix in each folder. 
    for (int i=0;i<flat.size();i++)
      {
      File f = flat.get(i);
      if(f.getName().charAt(0)!='.')
        {
        ArrayList<File> folder = filesToArrayList(f.getPath()); 
        for (int j=0;j<folder.size();j++)
          {
          File fS = folder.get(j);
          if(fS.getName().charAt(0)!='.' && fS.getName().indexOf(fileContents)>=0 && fS.getName().indexOf(fileContents2)>=0)
            {
            hier.add(fS);
            //println("Adding to hier list: " + fS.getName() + "\n"); 
            }
          }
        }
      }
    return hier;
    }
  else 
    {
    for (int i=flat.size()-1;i>=0;i--)
      {
      File f = flat.get(i);
      if (f.getName().indexOf(fileContents)==-1)
        flat.remove(i); 
      }
    return flat;
    }
  }
  
  
int getFolderCount(String folderRoot)
  {
  File dir = new File(folderRoot);
  int numberOfSubfolders = 0;
  File listDir[] = dir.listFiles();
  for (int i = 0; i < listDir.length; i++) 
    {
    if (listDir[i].isDirectory())
      numberOfSubfolders++;
    }
  return numberOfSubfolders;
  }