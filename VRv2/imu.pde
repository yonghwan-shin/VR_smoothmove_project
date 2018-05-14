// I haven't touched this file

import android.util.Log;
import shapes3d.utils.*; 

// some thread timing/speed vars
int start; 
int last; 
int packetCounter = 0; 
int meanPacketCounter = 0;
float packetRate; 

// the filter and variables
Madgwick madgwick; 
Mahony   mahony; 
float[] euler = new float[3]; 
float[] ypr = new float[3]; 
long lastIMU; 

// data
float[] accVals  = new float[3];
float[] gyroVals = new float[3];
float[] magVals  = new float[3];

imuSensors sensors;
Thread t;
boolean running = false;
boolean logData = false;

// min time between runs of the filter. 
long minimumBreak = 10; 

void stop()
{
  running = false;
  println("Running set to false");
}


public void resume()
{
  running = true;
  println("Running set to true");
}


void imuInit(boolean log)
{
  // setup the sensors
  sensors = new imuSensors();
  logData = log; 

  lastIMU = start = last = millis();  
  madgwick = new Madgwick(1000.0/96.0);  
  mahony   = new Mahony(1000.0/96.0); 

  euler[0] = euler[1] = euler[2] = 0; 
  ypr[0] = ypr[1] = ypr [2] = 0; 


  t = new Thread() { 
    public void run() {
      running = true;
      last = millis();
      while (running) {
        long now = millis(); 
        if ((sensors.accChanged() || sensors.gyroChanged() || sensors.magChanged()) && (now-last>=minimumBreak))
        {
          //println("COUNTER: "+packetCounter);
          accVals  = sensors.getAccVector();
          gyroVals = sensors.getGyroVector();
          magVals  = sensors.getMagVector();

          // run the filter  
          try 
          {
            imuFilter();
          }
          catch (java.lang.NullPointerException e)
          {
            println("Caught an exception in sixDOFFilter");
          }

          // log to PC
          if (logData)
            Log.v("adbActivity", packetCounter   +", "+ 
              euler[0]        +", "+ euler[1] +", "+ euler[2] +","+ 
              ypr[0]          +", "+ ypr[1]   +", "+ ypr[2]);

          /*
        println(packetCounter   +", "+ 
           euler[0]        +", "+ euler[1] +", "+ euler[2] +","+ 
           ypr[0]          +", "+ ypr[1]   +", "+ ypr[2]);
           */

          packetCounter++;
          if (packetCounter>=100)
            packetCounter = 0;

          last = millis(); 
          if (last>start+2000)
          {
            packetRate = (float)meanPacketCounter/2.0;
            start = last;
            meanPacketCounter=0;
          }   
          meanPacketCounter++;
        }
      }
    }
  };
  t.start();
}


// run the filter  
void imuFilter()
{  
  float[] values = new float[9];

  // checked these sensor inversions on samsung G6. Seems ok:
  // - forward/back ok
  // - left/right ok
  // - around ok
  // You may need something different on another phone. 

  // messed up
  values[0] = accVals[0];//-accVals[0];  
  values[1] = accVals[1];
  values[2] = accVals[2];
  values[3] = gyroVals[0]; 
  values[4] = gyroVals[1];//-gyroVals[1];
  values[5] = gyroVals[2];//-gyroVals[2];

  // these seem ok. 
  values[6] = magVals[0]; 
  values[7] = magVals[1];
  values[8] = magVals[2];

  long nowIMU = millis(); 

  /*
  madgwick.AHRSupdate(values[3], values[4], values[5],
   values[0], values[1], values[2],
   values[6], values[7], values[8]
   nowIMU - lastIMU);
   euler = madgwick.getEuler();
   ypr = madgwick.getYawPitchRoll();
   */

  mahony.AHRSupdate(  values[3], values[4], values[5], 
    values[0], values[1], values[2], 
    values[6], values[7], values[8], 
    nowIMU - lastIMU);
  euler = mahony.getEuler();
  ypr = mahony.getYawPitchRoll();

  lastIMU = nowIMU;
}  

void imuDrawInfo()
{
  stroke(255);

  try 
  {
    String s = "Rate: " + packetRate; 
    text(s, width/2, height/6);

    s = "Eulers: " + euler[0] +", "+ euler[1] +", "+ euler[2]; 
    text("Eulers:", width/4, height/6*2);
    text(euler[0], width/4*3, height/6.0*2.0);
    text(euler[1], width/4*3, height/6.0*2.75);
    text(euler[2], width/4*3, height/6.0*3.5);

    text((int)(accVals[0]*100), width/4, height/6.0*4.5);
    text((int)(accVals[1]*100), width/4*2, height/6.0*4.5);
    text((int)(accVals[2]*100), width/4*3, height/6.0*4.5);

    text((int)(gyroVals[0]*100), width/4, height/6*5);
    text((int)(gyroVals[1]*100), width/4*2, height/6*5);
    text((int)(gyroVals[2]*100), width/4*3, height/6*5);

    text((int)(magVals[0]), width/4, height/6*5.5);
    text((int)(magVals[1]), width/4*2, height/6*5.5);
    text((int)(magVals[2]), width/4*3, height/6*5.5);
  }
  catch (java.lang.NullPointerException e)
  {
    println("Caught an exception in draw");
  }
}

float[] imuGetAngles()
{
  Rot repRot = new Rot(RotOrder.ZXY, -radians(euler[2]), -radians(euler[1]), radians(euler[0]));
  // apply the matrix to axial vector 
  PVector vecY   = repRot.applyTo(new PVector(0, -100, 0)); // unit vector in x - along the long axis of the phone in this case
  // return the patch/yaw angles of this vector
  float[] r = new float[2];
  r[0] = degrees(atan2(vecY.z, vecY.x));
  r[1] = degrees(atan2(vecY.y, dist(0, 0, vecY.x, vecY.z)));
  return r;
}


static class imuFilter
{
  float sampleInterval; 
  float sampleFreq;               // sample frequency in Hz
  float recipSampleFreq;

  float q0, q1, q2, q3 ; // quaternion of sensor frame relative to auxiliary frame

  imuFilter(float _sampleInterval_ms)
  {
    sampleInterval = _sampleInterval_ms;
    sampleFreq = 1000 / sampleInterval;
    recipSampleFreq = 1.0 / sampleFreq;  

    q0 = 1.0;
    q1 = 0.0;
    q2 = 0.0;
    q3 = 0.0;
  }

  float[] getQuaternion()
  {
    float[] q = new float[4];
    q[0] = q0;
    q[1] = q1;
    q[2] = q2;
    q[3] = q3;
    return q;
  };

  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float deltaTime_ms) {
  }
  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az) 
  {
    AHRSupdate(gx, gy, gz, ax, ay, az, recipSampleFreq*1000.0);
  }

  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float mx, float my, float mz, float deltaTime_ms) {
  }
  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float mx, float my, float mz) 
  {
    AHRSupdate(gx, gy, gz, ax, ay, az, mx, my, mz, recipSampleFreq*1000.0);
  }

  /**
   * Returns the Euler angles in radians defined in the Aerospace sequence.
   * See Sebastian O.H. Madwick report "An efficient orientation filter for 
   * inertial and intertial/magnetic sensor arrays" Chapter 2 Quaternion representation
   * 
   * @param angles three floats array which will be populated by the Euler angles in radians
   */
  float[] getEulerRad() 
  {
    float[] q = new float[4]; // quaternion
    float[] angles = new float[3]; // angles
    q = getQuaternion();
    angles[0] = atan2(2 * q[1] * q[2] - 2 * q[0] * q[3], 2 * q[0]*q[0] + 2 * q[1] * q[1] - 1); // psi
    angles[1] = -asin(2 * q[1] * q[3] + 2 * q[0] * q[2]); // theta
    angles[2] = -atan2(2 * q[2] * q[3] - 2 * q[0] * q[1], 2 * q[0] * q[0] + 2 * q[3] * q[3] - 1); // phi
    return angles;
  }


  /**
   * Returns the Euler angles in degrees defined with the Aerospace sequence.
   * See Sebastian O.H. Madwick report "An efficient orientation filter for 
   * inertial and intertial/magnetic sensor arrays" Chapter 2 Quaternion representation
   * 
   * @param angles three floats array which will be populated by the Euler angles in degrees
   */
  float[] getEuler() {
    return arrayRadToDeg(getEulerRad());
  }


  /**
   * Returns the yaw pitch and roll angles, respectively defined as the angles in radians between
   * the Earth North and the IMU X axis (yaw), the Earth ground plane and the IMU X axis (pitch)
   * and the Earth ground plane and the IMU Y axis.
   * 
   * @note This is not an Euler representation: the rotations aren't consecutive rotations but only
   * angles from Earth and the IMU. For Euler representation Yaw, Pitch and Roll see FreeIMU::getEuler
   * 
   * @param ypr three floats array which will be populated by Yaw, Pitch and Roll angles in radians
   */
  static float[] getYawPitchRollRad(float[] q) {
    float[] ypr = new float[3]; // ypr
    float gx, gy, gz; // estimated gravity direction

    gx = 2 * (q[1]*q[3] - q[0]*q[2]);
    gy = 2 * (q[0]*q[1] + q[2]*q[3]);
    gz = q[0]*q[0] - q[1]*q[1] - q[2]*q[2] + q[3]*q[3];

    ypr[0] = atan2(2 * q[1] * q[2] - 2 * q[0] * q[3], 2 * q[0]*q[0] + 2 * q[1] * q[1] - 1);
    ypr[1] = atan(gx / sqrt(gy*gy + gz*gz));
    ypr[2] = atan(gy / sqrt(gx*gx + gz*gz));
    return ypr;
  }
  static float[] getYawPitchRoll(float[] q) {
    return arrayRadToDeg(getYawPitchRollRad(q));
  }
  float[] getYawPitchRollRad() {
    return getYawPitchRollRad(getQuaternion());
  }
  float[] getYawPitchRoll() {
    return getYawPitchRoll(getQuaternion());
  }


  static float[] arrayRadToDeg(float[] arr) {
    for (int i=0; i<arr.length; i++)
      arr[i] *= 180.0/PI;
    return arr;
  }

  /*
 * takes a quaterion and turns it into a rotation matrix.
   * Lifted from many examples on the internet. Seems to work.
   */
  static PMatrix3D QuatToMatrix(float[] q, boolean invert)
  { 
    float wx, wy, wz, xx, yy, yz, xy, xz, zz, x2, y2, z2;
    PMatrix3D p = new PMatrix3D(); 

    // calculate coefficients
    x2 = q[0] + q[0]; 
    y2 = q[1] + q[1]; 
    z2 = q[2] + q[2];
    xx = q[0] * x2; 
    xy = q[0] * y2; 
    xz = q[0] * z2;
    yy = q[1] * y2; 
    yz = q[1] * z2; 
    zz = q[2] * z2;
    wx = q[3] * x2; 
    wy = q[3] * y2; 
    wz = q[3] * z2;

    p.m00 = 1.0 - (yy + zz); 
    p.m10 = xy - wz;
    p.m20 = xz + wy; 
    p.m30 = 0.0;

    p.m01 = xy + wz; 
    p.m11 = 1.0 - (xx + zz);
    p.m21 = yz - wx; 
    p.m31 = 0.0;

    p.m02 = xz - wy; 
    p.m12 = yz + wx;
    p.m22 = 1.0 - (xx + yy); 
    p.m32 = 0.0;

    p.m03 = 0; 
    p.m13 = 0;
    p.m23 = 0; 
    p.m33 = 1; 

    if (invert)
      p.invert();  
    return p;
  }
}






/**
 * The Madgwick algorithm.  See: http://www.x-io.co.uk/open-source-imu-and-ahrs-algorithms/
 * @param {number} sampleInterval The sample interval in milliseconds.
 */
class Madgwick extends imuFilter
{
  float beta;   // 2 * proportional gain - lower numbers are smoother, but take longer to get to correct attitude.

  Madgwick(float _sampleInterval_ms)
  {
    super(_sampleInterval_ms);
    beta = 1.0;
  }

  Madgwick()
  {
    this(20.0); // default of 20 ms
  }

  //---------------------------------------------------------------------------------------------------
  // IMU algorithm update
  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float deltaTime_ms) {
    float recipSampleFreqLocal = deltaTime_ms/1000.0;
    float recipNorm;
    float s0, s1, s2, s3;
    float qDot1, qDot2, qDot3, qDot4;
    float V_2q0, V_2q1, V_2q2, V_2q3, V_4q0, V_4q1, V_4q2, V_8q1, V_8q2, q0q0, q1q1, q2q2, q3q3;

    // Rate of change of quaternion from gyroscope
    qDot1 = 0.5 * (-q1 * gx - q2 * gy - q3 * gz);
    qDot2 = 0.5 * (q0 * gx + q2 * gz - q3 * gy);
    qDot3 = 0.5 * (q0 * gy - q1 * gz + q3 * gx);
    qDot4 = 0.5 * (q0 * gz + q1 * gy - q2 * gx);

    // Compute feedback only if accelerometer measurement valid (avoids NaN in accelerometer normalisation)
    if (!((ax == 0.0) && (ay == 0.0) && (az == 0.0))) {

      // Normalise accelerometer measurement
      recipNorm = pow(ax * ax + ay * ay + az * az, -0.5);
      ax *= recipNorm;
      ay *= recipNorm;
      az *= recipNorm;

      // Auxiliary variables to avoid repeated arithmetic
      V_2q0 = 2.0 * q0;
      V_2q1 = 2.0 * q1;
      V_2q2 = 2.0 * q2;
      V_2q3 = 2.0 * q3;
      V_4q0 = 4.0 * q0;
      V_4q1 = 4.0 * q1;
      V_4q2 = 4.0 * q2;
      V_8q1 = 8.0 * q1;
      V_8q2 = 8.0 * q2;
      q0q0 = q0 * q0;
      q1q1 = q1 * q1;
      q2q2 = q2 * q2;
      q3q3 = q3 * q3;

      // Gradient decent algorithm corrective step
      s0 = V_4q0 * q2q2 + V_2q2 * ax + V_4q0 * q1q1 - V_2q1 * ay;
      s1 = V_4q1 * q3q3 - V_2q3 * ax + 4.0 * q0q0 * q1 - V_2q0 * ay - V_4q1 + V_8q1 * q1q1 + V_8q1 * q2q2 + V_4q1 * az;
      s2 = 4.0 * q0q0 * q2 + V_2q0 * ax + V_4q2 * q3q3 - V_2q3 * ay - V_4q2 + V_8q2 * q1q1 + V_8q2 * q2q2 + V_4q2 * az;
      s3 = 4.0 * q1q1 * q3 - V_2q1 * ax + 4.0 * q2q2 * q3 - V_2q2 * ay;
      recipNorm = pow(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3, -0.5); // normalise step magnitude
      s0 *= recipNorm;
      s1 *= recipNorm;
      s2 *= recipNorm;
      s3 *= recipNorm;

      // Apply feedback step
      qDot1 -= beta * s0;
      qDot2 -= beta * s1;
      qDot3 -= beta * s2;
      qDot4 -= beta * s3;
    }

    // Integrate rate of change of quaternion to yield quaternion
    q0 += qDot1 * recipSampleFreqLocal;
    q1 += qDot2 * recipSampleFreqLocal;
    q2 += qDot3 * recipSampleFreqLocal;
    q3 += qDot4 * recipSampleFreqLocal;

    // Normalise quaternion
    recipNorm = pow(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3, -0.5);
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;
  }

  //---------------------------------------------------------------------------------------------------
  // AHRS algorithm update
  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float mx, float my, float mz, float deltaTime_ms) {
    float recipSampleFreqLocal = deltaTime_ms/1000.0;
    float recipNorm;
    float s0, s1, s2, s3;
    float qDot1, qDot2, qDot3, qDot4;
    float hx, hy;
    float V_2q0mx, V_2q0my, V_2q0mz, V_2q1mx, V_2bx, V_2bz, V_4bx, V_4bz, V_2q0, V_2q1, V_2q2, V_2q3, V_2q0q2, V_2q2q3;
    float q0q0, q0q1, q0q2, q0q3, q1q1, q1q2, q1q3, q2q2, q2q3, q3q3;

    // Use IMU algorithm if magnetometer measurement invalid (avoids NaN in magnetometer normalisation)
    if (/*mx === undefined || my === undefined || mz === undefined || */(mx == 0 && my == 0 && mz == 0)) {
      AHRSupdate(gx, gy, gz, ax, ay, az);
      return;
    }

    // Rate of change of quaternion from gyroscope
    qDot1 = 0.5 * (-q1 * gx - q2 * gy - q3 * gz);
    qDot2 = 0.5 * (q0 * gx + q2 * gz - q3 * gy);
    qDot3 = 0.5 * (q0 * gy - q1 * gz + q3 * gx);
    qDot4 = 0.5 * (q0 * gz + q1 * gy - q2 * gx);

    // Compute feedback only if accelerometer measurement valid (avoids NaN in accelerometer normalisation)
    if (!((ax == 0.0) && (ay == 0.0) && (az == 0.0))) {

      // Normalise accelerometer measurement
      recipNorm = pow(ax * ax + ay * ay + az * az, -0.5);
      ax *= recipNorm;
      ay *= recipNorm;
      az *= recipNorm;

      // Normalise magnetometer measurement
      recipNorm = pow(mx * mx + my * my + mz * mz, -0.5);
      mx *= recipNorm;
      my *= recipNorm;
      mz *= recipNorm;

      // Auxiliary variables to avoid repeated arithmetic
      V_2q0mx = 2.0 * q0 * mx;
      V_2q0my = 2.0 * q0 * my;
      V_2q0mz = 2.0 * q0 * mz;
      V_2q1mx = 2.0 * q1 * mx;
      V_2q0 = 2.0 * q0;
      V_2q1 = 2.0 * q1;
      V_2q2 = 2.0 * q2;
      V_2q3 = 2.0 * q3;
      V_2q0q2 = 2.0 * q0 * q2;
      V_2q2q3 = 2.0 * q2 * q3;
      q0q0 = q0 * q0;
      q0q1 = q0 * q1;
      q0q2 = q0 * q2;
      q0q3 = q0 * q3;
      q1q1 = q1 * q1;
      q1q2 = q1 * q2;
      q1q3 = q1 * q3;
      q2q2 = q2 * q2;
      q2q3 = q2 * q3;
      q3q3 = q3 * q3;

      // Reference direction of Earth's magnetic field
      hx = mx * q0q0 - V_2q0my * q3 + V_2q0mz * q2 + mx * q1q1 + V_2q1 * my * q2 + V_2q1 * mz * q3 - mx * q2q2 - mx * q3q3;
      hy = V_2q0mx * q3 + my * q0q0 - V_2q0mz * q1 + V_2q1mx * q2 - my * q1q1 + my * q2q2 + V_2q2 * mz * q3 - my * q3q3;
      V_2bx = sqrt(hx * hx + hy * hy);
      V_2bz = -V_2q0mx * q2 + V_2q0my * q1 + mz * q0q0 + V_2q1mx * q3 - mz * q1q1 + V_2q2 * my * q3 - mz * q2q2 + mz * q3q3;
      V_4bx = 2.0 * V_2bx;
      V_4bz = 2.0 * V_2bz;

      // Gradient decent algorithm corrective step
      s0 = -V_2q2 * (2.0 * q1q3 - V_2q0q2 - ax) + V_2q1 * (2.0 * q0q1 + V_2q2q3 - ay) - V_2bz * q2 * (V_2bx * (0.5 - q2q2 - q3q3) + V_2bz * (q1q3 - q0q2) - mx) + (-V_2bx * q3 + V_2bz * q1) * (V_2bx * (q1q2 - q0q3) + V_2bz * (q0q1 + q2q3) - my) + V_2bx * q2 * (V_2bx * (q0q2 + q1q3) + V_2bz * (0.5 - q1q1 - q2q2) - mz);
      s1 = V_2q3 * (2.0 * q1q3 - V_2q0q2 - ax) + V_2q0 * (2.0 * q0q1 + V_2q2q3 - ay) - 4.0 * q1 * (1 - 2.0 * q1q1 - 2.0 * q2q2 - az) + V_2bz * q3 * (V_2bx * (0.5 - q2q2 - q3q3) + V_2bz * (q1q3 - q0q2) - mx) + (V_2bx * q2 + V_2bz * q0) * (V_2bx * (q1q2 - q0q3) + V_2bz * (q0q1 + q2q3) - my) + (V_2bx * q3 - V_4bz * q1) * (V_2bx * (q0q2 + q1q3) + V_2bz * (0.5 - q1q1 - q2q2) - mz);
      s2 = -V_2q0 * (2.0 * q1q3 - V_2q0q2 - ax) + V_2q3 * (2.0 * q0q1 + V_2q2q3 - ay) - 4.0 * q2 * (1 - 2.0 * q1q1 - 2.0 * q2q2 - az) + (-V_4bx * q2 - V_2bz * q0) * (V_2bx * (0.5 - q2q2 - q3q3) + V_2bz * (q1q3 - q0q2) - mx) + (V_2bx * q1 + V_2bz * q3) * (V_2bx * (q1q2 - q0q3) + V_2bz * (q0q1 + q2q3) - my) + (V_2bx * q0 - V_4bz * q2) * (V_2bx * (q0q2 + q1q3) + V_2bz * (0.5 - q1q1 - q2q2) - mz);
      s3 = V_2q1 * (2.0 * q1q3 - V_2q0q2 - ax) + V_2q2 * (2.0 * q0q1 + V_2q2q3 - ay) + (-V_4bx * q3 + V_2bz * q1) * (V_2bx * (0.5 - q2q2 - q3q3) + V_2bz * (q1q3 - q0q2) - mx) + (-V_2bx * q0 + V_2bz * q2) * (V_2bx * (q1q2 - q0q3) + V_2bz * (q0q1 + q2q3) - my) + V_2bx * q1 * (V_2bx * (q0q2 + q1q3) + V_2bz * (0.5 - q1q1 - q2q2) - mz);
      recipNorm = pow(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3, -0.5); // normalise step magnitude
      s0 *= recipNorm;
      s1 *= recipNorm;
      s2 *= recipNorm;
      s3 *= recipNorm;

      // Apply feedback step
      qDot1 -= beta * s0;
      qDot2 -= beta * s1;
      qDot3 -= beta * s2;
      qDot4 -= beta * s3;
    }

    // Integrate rate of change of quaternion to yield quaternion
    q0 += qDot1 * recipSampleFreqLocal;
    q1 += qDot2 * recipSampleFreqLocal;
    q2 += qDot3 * recipSampleFreqLocal;
    q3 += qDot4 * recipSampleFreqLocal;

    // Normalise quaternion
    recipNorm = pow(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3, -0.5);
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;
  }
}






/**
 * The Mahony algorithm.  See: http://www.x-io.co.uk/open-source-imu-and-ahrs-algorithms/
 * @param {number} sampleInterval The sample interval in milliseconds.
 */
class Mahony extends imuFilter
{
  //---------------------------------------------------------------------------------------------------
  // Definitions
  float kp;
  float ki;
  float twoKpDef;                 // 2 * proportional gain
  float twoKiDef;                 // 2 * integral gain
  float twoKp;                    // 2 * proportional gain (Kp)
  float twoKi;                    // 2 * integral gain (Ki)

  // integral error terms scaled by Ki
  float integralFBx;
  float integralFBy;
  float integralFBz;                

  Mahony(float _sampleInterval_ms)
  {
    super(_sampleInterval_ms); 
    kp = 1.0;
    ki = 0.0;
    twoKpDef = 2.0 * kp;                 // 2 * proportional gain
    twoKiDef = 2.0 * ki;                 // 2 * integral gain
    twoKp = twoKpDef;                    // 2 * proportional gain (Kp)
    twoKi = twoKiDef;                    // 2 * integral gain (Ki)

    integralFBx = 0.0;
    integralFBy = 0.0;
    integralFBz = 0.0;
  }

  Mahony()
  {
    this(20.0); // default of 20 ms
  }

  //---------------------------------------------------------------------------------------------------
  // IMU algorithm update
  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float deltaTime_ms) {
    float recipSampleFreqLocal = deltaTime_ms/1000.0;
    float recipNorm;
    float halfvx, halfvy, halfvz;
    float halfex, halfey, halfez;
    float qa, qb, qc;

    // Compute feedback only if accelerometer measurement valid (afunctions NaN in accelerometer normalisation)
    if (ax != 0 && ay != 0 && az != 0) {
      // Normalise accelerometer measurement
      recipNorm = pow(ax * ax + ay * ay + az * az, -0.5);
      ax *= recipNorm;
      ay *= recipNorm;
      az *= recipNorm;

      // Estimated direction of gravity and vector perpendicular to magnetic flux
      halfvx = q1 * q3 - q0 * q2;
      halfvy = q0 * q1 + q2 * q3;
      halfvz = q0 * q0 - 0.5 + q3 * q3;

      // Error is sum of cross product between estimated and measured direction of gravity
      halfex = (ay * halfvz - az * halfvy);
      halfey = (az * halfvx - ax * halfvz);
      halfez = (ax * halfvy - ay * halfvx);

      // Compute and apply integral feedback if enabled
      if (twoKi > 0.0) {
        integralFBx += twoKi * halfex * recipSampleFreqLocal; // integral error scaled by Ki
        integralFBy += twoKi * halfey * recipSampleFreqLocal;
        integralFBz += twoKi * halfez * recipSampleFreqLocal;
        gx += integralFBx; // apply integral feedback
        gy += integralFBy;
        gz += integralFBz;
      } else {
        integralFBx = 0.0; // prevent integral windup
        integralFBy = 0.0;
        integralFBz = 0.0;
      }
      // Apply proportional feedback
      gx += twoKp * halfex;
      gy += twoKp * halfey;
      gz += twoKp * halfez;
    }

    // Integrate rate of change of quaternion
    gx *= (0.5 * recipSampleFreqLocal);         // pre-multiply common factors
    gy *= (0.5 * recipSampleFreqLocal);
    gz *= (0.5 * recipSampleFreqLocal);
    qa = q0;
    qb = q1;
    qc = q2;
    q0 += (-qb * gx - qc * gy - q3 * gz);
    q1 += (qa * gx + qc * gz - q3 * gy);
    q2 += (qa * gy - qb * gz + q3 * gx);
    q3 += (qa * gz + qb * gy - qc * gx);

    // Normalise quaternion
    recipNorm = pow(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3, -0.5);
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;
  }


  //---------------------------------------------------------------------------------------------------
  // AHRS algorithm update
  void AHRSupdate(float gx, float gy, float gz, float ax, float ay, float az, float mx, float my, float mz, float deltaTime_ms) {
    float recipSampleFreqLocal = deltaTime_ms/1000.0;
    float recipNorm;
    float q0q0, q0q1, q0q2, q0q3, q1q1, q1q2, q1q3, q2q2, q2q3, q3q3;
    float hx, hy, bx, bz;
    float halfvx, halfvy, halfvz, halfwx, halfwy, halfwz;
    float halfex, halfey, halfez;
    float qa, qb, qc;

    // Use IMU algorithm if magnetometer measurement invalid (avoids NaN in magnetometer normalisation)
    if (/*mx === undefined || my === undefined || mz === undefined || */(mx == 0 && my == 0 && mz == 0)) {
      AHRSupdate(gx, gy, gz, ax, ay, az);
      return;
    }

    // Compute feedback only if accelerometer measurement valid (afunctions NaN in accelerometer normalisation)
    if (ax != 0 && ay != 0 && az != 0) {

      // Normalise accelerometer measurement
      recipNorm = pow(ax * ax + ay * ay + az * az, -0.5);
      ax *= recipNorm;
      ay *= recipNorm;
      az *= recipNorm;

      // Normalise magnetometer measurement
      recipNorm = pow(mx * mx + my * my + mz * mz, -0.5);
      mx *= recipNorm;
      my *= recipNorm;
      mz *= recipNorm;

      // Auxiliary variables to afunction repeated arithmetic
      q0q0 = q0 * q0;
      q0q1 = q0 * q1;
      q0q2 = q0 * q2;
      q0q3 = q0 * q3;
      q1q1 = q1 * q1;
      q1q2 = q1 * q2;
      q1q3 = q1 * q3;
      q2q2 = q2 * q2;
      q2q3 = q2 * q3;
      q3q3 = q3 * q3;

      // Reference direction of Earth's magnetic field
      hx = 2.0 * (mx * (0.5 - q2q2 - q3q3) + my * (q1q2 - q0q3) + mz * (q1q3 + q0q2));
      hy = 2.0 * (mx * (q1q2 + q0q3) + my * (0.5 - q1q1 - q3q3) + mz * (q2q3 - q0q1));
      bx = sqrt(hx * hx + hy * hy);
      bz = 2.0 * (mx * (q1q3 - q0q2) + my * (q2q3 + q0q1) + mz * (0.5 - q1q1 - q2q2));

      // Estimated direction of gravity and magnetic field
      halfvx = q1q3 - q0q2;
      halfvy = q0q1 + q2q3;
      halfvz = q0q0 - 0.5 + q3q3;
      halfwx = bx * (0.5 - q2q2 - q3q3) + bz * (q1q3 - q0q2);
      halfwy = bx * (q1q2 - q0q3) + bz * (q0q1 + q2q3);
      halfwz = bx * (q0q2 + q1q3) + bz * (0.5 - q1q1 - q2q2);

      // Error is sum of cross product between estimated direction and measured direction of field vectors
      halfex = (ay * halfvz - az * halfvy) + (my * halfwz - mz * halfwy);
      halfey = (az * halfvx - ax * halfvz) + (mz * halfwx - mx * halfwz);
      halfez = (ax * halfvy - ay * halfvx) + (mx * halfwy - my * halfwx);

      // Compute and apply integral feedback if enabled
      if (twoKi > 0.0) {
        integralFBx += twoKi * halfex * recipSampleFreqLocal;  // integral error scaled by Ki
        integralFBy += twoKi * halfey * recipSampleFreqLocal;
        integralFBz += twoKi * halfez * recipSampleFreqLocal;
        gx += integralFBx;  // apply integral feedback
        gy += integralFBy;
        gz += integralFBz;
      } else {
        integralFBx = 0.0;  // prevent integral windup
        integralFBy = 0.0;
        integralFBz = 0.0;
      }

      // Apply proportional feedback
      gx += twoKp * halfex;
      gy += twoKp * halfey;
      gz += twoKp * halfez;
    }

    // Integrate rate of change of quaternion
    gx *= (0.5 * recipSampleFreqLocal);    // pre-multiply common factors
    gy *= (0.5 * recipSampleFreqLocal);
    gz *= (0.5 * recipSampleFreqLocal);
    qa = q0;
    qb = q1;
    qc = q2;
    q0 += (-qb * gx - qc * gy - q3 * gz);
    q1 += (qa * gx + qc * gz - q3 * gy);
    q2 += (qa * gy - qb * gz + q3 * gx);
    q3 += (qa * gz + qb * gy - qc * gx);

    // Normalise quaternion
    recipNorm = pow(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3, -0.5);
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;
  }
}







import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorManager;
import android.hardware.SensorEventListener;


class imuSensors
{
  imuSensors()
  {
    acc_values_check  = new float[3];
    gyro_values_check = new float[3];
    mag_values_check  = new float[3];

    // Build our SensorManager:
    // processing can fail to fid getActivity when checking source and underline in red here. Just try to compile anyway - should work 
    mSensorManager = (SensorManager)surface.getActivity().getSystemService(Context.SENSOR_SERVICE);

    // Build a SensorEventListener for each type of sensor:
    accEventListener  = new MySensorEventListener();
    gyroEventListener = new MySensorEventListener();
    magEventListener = new MySensorEventListener();

    // Get each of our Sensors:
    acc_sensor = mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
    gyro_sensor = mSensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
    mag_sensor = mSensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);

    // Register the SensorEventListeners with their Sensor, and their SensorManager:
    mSensorManager.registerListener(accEventListener, acc_sensor, SensorManager.SENSOR_DELAY_UI);//SENSOR_DELAY_GAME); //SENSOR_DELAY_FASTEST
    mSensorManager.registerListener(gyroEventListener, gyro_sensor, SensorManager.SENSOR_DELAY_UI);//SENSOR_DELAY_GAME); //SENSOR_DELAY_FASTEST
    mSensorManager.registerListener(magEventListener, mag_sensor, SensorManager.SENSOR_DELAY_UI);//SENSOR_DELAY_GAME); //SENSOR_DELAY_FASTEST
  } 


  class MySensorEventListener implements SensorEventListener 
  {
    void onSensorChanged(SensorEvent event) 
    {
      int eventType = event.sensor.getType();
      if (eventType == Sensor.TYPE_ACCELEROMETER) 
      {
        boolean diff = false;
        if (acc_values_check[0] != event.values[0])
          diff = true;
        else if (acc_values_check[1] != event.values[1])
          diff = true;
        else if (acc_values_check[2] != event.values[2])
          diff = true;
        //else
        //  println("No acc Diff", acc_values_check[0], acc_values_check[1], acc_values_check[2],
        //                         event.values[0], event.values[1], event.values[2]);

        if (diff)
        {
          acc_values_check[0] = event.values[0];
          acc_values_check[1] = event.values[1];
          acc_values_check[2] = event.values[2];

          acc_values = event.values;// this is m/s squared - we need G units  
          for (int i=0; i<acc_values.length; i++)
            acc_values[i] = acc_values[i] / 9.81;   // 9.81 == GRAVITY
          acc_changed=true;
        }
      } else if (eventType == Sensor.TYPE_GYROSCOPE) 
      {
        boolean diff = false;
        if (gyro_values_check[0] != event.values[0])
          diff = true;
        else if (gyro_values_check[1] != event.values[1])
          diff = true;
        else if (gyro_values_check[2] != event.values[2])
          diff = true;
        //else
        //  println("No gyro Diff");

        if (diff)
        {
          gyro_values_check[0] = event.values[0];
          gyro_values_check[1] = event.values[1];
          gyro_values_check[2] = event.values[2];

          gyro_values = event.values; // this is rad/second - req'd for new lib
          gyro_changed=true;
        }
      } else if (eventType == Sensor.TYPE_MAGNETIC_FIELD) 
      {
        boolean diff = false;
        if (mag_values_check[0] != event.values[0])
          diff = true;
        else if (mag_values_check[1] != event.values[1])
          diff = true;
        else if (mag_values_check[2] != event.values[2])
          diff = true;
        //else
        //  println("No mag Diff");

        if (diff)
        {
          mag_values_check[0] = event.values[0];
          mag_values_check[1] = event.values[1];
          mag_values_check[2] = event.values[2];

          mag_values = event.values;  // unitless
          mag_changed=true;
        }
      }
    }

    void onAccuracyChanged(Sensor sensor, int accuracy) {
    }
  }


  float[] getAccVector() {  
    acc_changed=false;  
    return acc_values;
  }
  float[] getGyroVector() { 
    gyro_changed=false; 
    return gyro_values;
  }
  float[] getMagVector() {  
    mag_changed=false;  
    return mag_values;
  }

  boolean accChanged() { 
    return acc_changed;
  }
  boolean gyroChanged() { 
    return gyro_changed;
  }
  boolean magChanged() { 
    return mag_changed;
  }

  // PRIVATE MEMBERS
  private SensorManager mSensorManager;
  private MySensorEventListener accEventListener;
  private MySensorEventListener gyroEventListener;
  private MySensorEventListener magEventListener;

  private Sensor acc_sensor;
  private Sensor gyro_sensor;
  private Sensor mag_sensor;

  private float[] acc_values;
  private float[] gyro_values;
  private float[] mag_values;

  private float[] acc_values_check;
  private float[] gyro_values_check;
  private float[] mag_values_check;

  boolean acc_changed;
  boolean gyro_changed;
  boolean mag_changed;
}