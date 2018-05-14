ArrayList<Long>   _timeHead;               // head data
ArrayList<Float>  _xHead;                  
ArrayList<Float>  _yHead;

ArrayList<Long>   _timeTargets;            // target data
ArrayList<ArrayList<Float>> _targetXs;     
ArrayList<ArrayList<Float>> _targetYs;

/* 
 * Init. the data storage structures for head and target positions
 */
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
}

/*
 * Clear head and target data before each trial
 */
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


/*
 * Add target data to the store
 */
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
    while (_timeTargets.get(1) < now-correlator.correlThreshold && _timeTargets.size() > 1) // look at the second item
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

/*
 * Add head data to the store
 */
void addHeadData(long now, float yaw, float pitch)
{
  _timeHead.add(now); 
  _xHead.add(yaw);
  _yHead.add(pitch);


  // Remove old data if we have more than windowSize samples
  if (_timeHead.size() > correlator.windowSize)    
  {
    while (_timeHead.get(1) < now-correlator.correlThreshold && _timeHead.size() > 1)
    {
      _timeHead.remove(0);
      _xHead.remove(0);
      _yHead.remove(0);
    }
  }
}