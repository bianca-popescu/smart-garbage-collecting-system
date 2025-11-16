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

float LOW_LEVEL  = 5.0;
float MID_LEVEL  = 4.0;
float HIGH_LEVEL = 3.0;
float FULL_LEVEL = 2.5;

float readDistanceRaw(int trigPin, int echoPin){

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

// smoothing function - median filtering
// uses about 5 readings in order to obtain a better serial output

float approximateCloseDistance(float lastValid) {
  // Smooth exponential approach as distance shrinks
  float approx = 2.0 + 0.3 * exp(-0.7 * (lastValid - 2.0));

  // Clamp to sensor minimum (HC-SR04 cannot detect < 1.7 cm)
  if (approx < 1.7) approx = 1.7;
  
  return approx;
}

float readDistanceSmooth(int trigPin, int echoPin){

  const int N = 4; // number of reading used
  float vals[N];

  for(int i = 0; i < N; i++){
    vals[i] = readDistanceRaw(trigPin, echoPin);

    // condition to reject extreme outlines
    if(vals[i] <= 0 || vals[i] > 6) vals[i] = -1;
    
    delay(40); // small delay between readings
  }


  float lastValid = 2.5; // start with a neutral mid value

  for (int i = 0; i < N; i++) {
    if (vals[i] > 0) {
      lastValid = vals[i];
    } else {
      // Instead of forcing to "2", approximate realistically
      vals[i] = approximateCloseDistance(lastValid);
    }
  }

  // sort array - bubble sort
  for (int i = 0; i < N - 1; i++) {
    for (int j = i + 1; j < N; j++) {
      if (vals[j] < vals[i]) {
        float temp = vals[i];
        vals[i] = vals[j];
        vals[j] = temp;
      }
    }
  }

  // median value = middle value 
  float median = vals[N/2];

  return median;
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

  // HIGH (4 cm - 3 cm)
  if (distance <= HIGH_LEVEL) {
    analogWrite(ledPin, 150);
    return;
  }

  // MIDDLE (5 cm - 4 cm)
  if (distance <= MID_LEVEL) {
    analogWrite(ledPin, 50);
    return;
  }

  // LOW (>= 5 cm)
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

  float d1 = readDistanceSmooth(TRIG1, ECHO1);
  delay(100);
  float d2 = readDistanceSmooth(TRIG2, ECHO2);
  delay(100);
  float d3 = readDistanceSmooth(TRIG3, ECHO3);
  delay(100);
  float d4 = readDistanceSmooth(TRIG4, ECHO4);

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

  delay(1000); // shorter delay for data filtering

}
