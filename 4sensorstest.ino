//sensor 1 - red LED
#define TRIG1 3
#define ECHO1 2
#define LED1  13 

// sensor 2 - green LED
#define TRIG2 5
#define ECHO2 4
#define LED2  12  

// sensor 3 - blue LED
#define TRIG3 7
#define ECHO3 6
#define LED3  11  

// sensor 4 - yellow LED
#define TRIG4 9
#define ECHO4 8
#define LED4  10

float LOW_LEVEL  = 8.0;
float MID_LEVEL  = 7.0;
float HIGH_LEVEL = 6.0;
float FULL_LEVEL = 5.0;

float readDistance(int trigPin, int echoPin){

  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000); 

  if (duration == 0) return -1;   // invalid reading

  float distance = duration / 58.0;
  
  return distance;
}


void setLEDLevel(int ledPin, float distance) {

  if (distance < 0) {
    analogWrite(ledPin, 0);
    return;
  }

  // FULL (5 cm or less)
  if (distance <= FULL_LEVEL) {
    analogWrite(ledPin, 255);
    delay(150);
    analogWrite(ledPin, 0);
    delay(150);
    return;
  }

  // HIGH (6 cm - 5 cm)
  if (distance <= HIGH_LEVEL) {
    analogWrite(ledPin, 150);
    return;
  }

  // MIDDLE (7 cm - 6 cm)
  if (distance <= MID_LEVEL) {
    analogWrite(ledPin, 50);
    return;
  }

  // LOW (>= 8 cm)
  if (distance >= LOW_LEVEL) {
    analogWrite(ledPin, 0);
    return;
  }
}

void setup(){

  Serial.begin(9600);

  pinMode(TRIG1, OUTPUT); pinMode(ECHO1, INPUT); pinMode(LED1, OUTPUT);
  pinMode(TRIG2, OUTPUT); pinMode(ECHO2, INPUT); pinMode(LED2, OUTPUT);
  pinMode(TRIG3, OUTPUT); pinMode(ECHO3, INPUT); pinMode(LED3, OUTPUT);
  pinMode(TRIG4, OUTPUT); pinMode(ECHO4, INPUT); pinMode(LED4, OUTPUT);

}

void loop(){

  float d1 = readDistance(TRIG1, ECHO1);
  delay(100);
  float d2 = readDistance(TRIG2, ECHO2);
  delay(100);
  float d3 = readDistance(TRIG3, ECHO3);
  delay(100);
  float d4 = readDistance(TRIG4, ECHO4);

  setLEDLevel(LED1, d1);
  setLEDLevel(LED2, d2);
  setLEDLevel(LED3, d3);
  setLEDLevel(LED4, d4);

 
  Serial.print(d1); 
  Serial.print(",");

  Serial.print(d2); 
  Serial.print(",");

  Serial.print(d3); 
  Serial.print(",");

  Serial.println(d4);

  delay(2500);

}
