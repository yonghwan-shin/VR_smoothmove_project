/**
 * Processing class for drawing arrow 
 * by Eom Taeho 
 * 
 * http://saegil-lab.kr
 * http://saegil.tistory.com
 */

class Arrow{
  float x1, y1, x2, y2;

  Arrow(float x1_, float y1_, float x2_, float y2_){
    x1 = x1_;
    y1 = y1_;
    x2 = x2_;
    y2 = y2_;
  }

  void display(){
    stroke(0);
    strokeWeight(5);
    line(x1, y1, x2, y2);

    float x, y, a, b, c, d, theta;

    theta = atan((y2-y1)/(x2-x1));
    if ((x2 - x1) < 0) {
      theta = -(PI - theta);
    }
    x = x2 - 10*cos(theta);
    y = y2 - 10*sin(theta);

    a = x - 5*sin(theta);
    b = y + 5*cos(theta);

    c = x + 5*sin(theta);
    d = y - 5*cos(theta);

    fill(0);

    triangle(x2, y2, a, b, c, d);
  }

  void setP1(float x1_, float y1_){
    x1 = x1_;
    y1 = y1_;
  }

  void setP2(float x2_, float y2_){
    x2 = x2_;
    y2 = y2_;
  }
 }