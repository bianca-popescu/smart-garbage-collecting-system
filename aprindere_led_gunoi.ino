#include <Servo.h>

Servo myservo1;
Servo myservo2;
Servo myservo3;
Servo myservo4;

int pos = 0;

// sensor 1
#define TRIG1 3
#define ECHO1 2
#define LED1  13 
#define SERVO1 22

// sensor 2
#define TRIG2 5
#define ECHO2 4
#define LED2  12  
#define SERVO2 51

// sensor 3
#define TRIG3 7
#define ECHO3 6
#define LED3  11 
#define SERVO3 33 

// sensor 4
#define TRIG4 9
#define ECHO4 8
#define LED4  10
#define SERVO4 50

float LOW_LEVEL  = 5.0;
float MID_LEVEL  = 4.0;
float HIGH_LEVEL = 3.5;
float FULL_LEVEL = 3.0;


float readDistance(int trigPin, int echoPin){

  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000); 
  if (duration == 0) return -1;

  return duration / 58.0;
}


// ======================= SERVO SWEEP UNIVERSAL ==========================
void servoSweep(Servo &s) {
  for (pos = 0; pos <= 180; pos++) {
    s.write(pos);
    delay(15);
  }
  for (pos = 180; pos >= 0; pos--) {
    s.write(pos);
    delay(15);
  }
}
// =======================================================================


// ======================= LED + SERVO CONTROL ===========================
void setLEDLevel(int ledPin, float distance, Servo &s) {

  if (distance < 0) {
    analogWrite(ledPin, 0);
    return;
  }

  if (distance < FULL_LEVEL) {
    analogWrite(ledPin, 255);
    delay(150);
    analogWrite(ledPin, 0);
    delay(150);
    servoSweep(s);
    return;
  }

  if (distance >= HIGH_LEVEL && distance < MID_LEVEL) {
    analogWrite(ledPin, 150);
    return;
  }

  if (distance >= MID_LEVEL && distance < LOW_LEVEL) {
    analogWrite(ledPin, 50);
    return;
  }

  if (distance >= LOW_LEVEL) {
    analogWrite(ledPin, 0);
    return;
  }
}
// =======================================================================


void setup(){

  Serial.begin(9600);

  pinMode(TRIG1, OUTPUT); pinMode(ECHO1, INPUT); pinMode(LED1, OUTPUT);
  pinMode(TRIG2, OUTPUT); pinMode(ECHO2, INPUT); pinMode(LED2, OUTPUT);
  pinMode(TRIG3, OUTPUT); pinMode(ECHO3, INPUT); pinMode(LED3, OUTPUT);
  pinMode(TRIG4, OUTPUT); pinMode(ECHO4, INPUT); pinMode(LED4, OUTPUT);

  myservo1.attach(SERVO1);
  myservo2.attach(SERVO2);
  myservo3.attach(SERVO3);
  myservo4.attach(SERVO4);
}


void loop(){

  float d1 = readDistance(TRIG1, ECHO1);
  float d2 = readDistance(TRIG2, ECHO2);
  float d3 = readDistance(TRIG3, ECHO3);
  float d4 = readDistance(TRIG4, ECHO4);

  setLEDLevel(LED1, d1, myservo1);
  setLEDLevel(LED2, d2, myservo2);
  setLEDLevel(LED3, d3, myservo3);
  setLEDLevel(LED4, d4, myservo4);

  Serial.print(d1); Serial.print(",");
  Serial.print(d2); Serial.print(",");
  Serial.print(d3); Serial.print(",");
  Serial.println(d4);

  delay(500);
}
