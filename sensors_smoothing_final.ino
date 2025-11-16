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

// EMA storage
float ema1 = -1, ema2 = -1, ema3 = -1, ema4 = -1;

// ---------------- RAW DISTANCE -------------------
float readDistanceRaw(int trigPin, int echoPin){

  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000); 
  if (duration == 0) return -1;

  return duration / 58.0;
}

// ---------- APPROXIMATION FOR SMALL DISTANCES -------------
float approximateCloseDistance(float lastValid) {

  float approx = 2.0 + 0.25 * exp(-0.7 * (lastValid - 3));

  if (approx < 1.7) approx = 1.7;
  return approx;
}

// ----------------- MEDIAN + APPROXIMATION  ----------------
float readDistanceFiltered(int trigPin, int echoPin) {

  const int N = 5;
  float vals[N];

  for (int i = 0; i < N; i++) {
    vals[i] = readDistanceRaw(trigPin, echoPin);

    if (vals[i] <= 0 || vals[i] > 6)
      vals[i] = -1;

    delay(40);
  }

  float lastValid = 3.0;

  for (int i = 0; i < N; i++) {
    if (vals[i] > 0) {
      lastValid = vals[i];
    } else {
      vals[i] = approximateCloseDistance(lastValid);
    }
  }

  // bubble sort
  for (int i = 0; i < N - 1; i++) {
    for (int j = i + 1; j < N; j++) {
      if (vals[j] < vals[i]) {
        float t = vals[i];
        vals[i] = vals[j];
        vals[j] = t;
      }
    }
  }

  return vals[N / 2];
}

// --------------------- EMA ------------------------
float applyEMA(float raw, float &emaValue) {

  float alpha;

  // slow, stable EMA for near distances
  if (raw < 3.0)
      alpha = 0.18;
  else
      alpha = 0.35;

  if (emaValue < 0)
      emaValue = raw;
  else
      emaValue = alpha * raw + (1 - alpha) * emaValue;

  return emaValue;
}

// ---------------- LED LOGIC ------------------------
void setLEDLevel(int ledPin, float distance) {

  if (distance < 0) {
    analogWrite(ledPin, 0);
    return;
  }

  if (distance <= FULL_LEVEL) {
    analogWrite(ledPin, 255);
    delay(150);
    analogWrite(ledPin, 0);
    delay(150);
    return;
  }

  if (distance <= HIGH_LEVEL) {
    analogWrite(ledPin, 150);
    return;
  }

  if (distance <= MID_LEVEL) {
    analogWrite(ledPin, 50);
    return;
  }

  if (distance >= LOW_LEVEL) {
    analogWrite(ledPin, 0);
    return;
  }
}

void setup() {
  Serial.begin(9600);

  pinMode(TRIG1, OUTPUT); pinMode(ECHO1, INPUT); pinMode(LED1, OUTPUT);
  pinMode(TRIG2, OUTPUT); pinMode(ECHO2, INPUT); pinMode(LED2, OUTPUT);
  pinMode(TRIG3, OUTPUT); pinMode(ECHO3, INPUT); pinMode(LED3, OUTPUT);
  pinMode(TRIG4, OUTPUT); pinMode(ECHO4, INPUT); pinMode(LED4, OUTPUT);
}

void loop() {

  float d1 = applyEMA(readDistanceFiltered(TRIG1, ECHO1), ema1);
  delay(80);
  float d2 = applyEMA(readDistanceFiltered(TRIG2, ECHO2), ema2);
  delay(80);
  float d3 = applyEMA(readDistanceFiltered(TRIG3, ECHO3), ema3);
  delay(80);
  float d4 = applyEMA(readDistanceFiltered(TRIG4, ECHO4), ema4);

  setLEDLevel(LED1, d1);
  setLEDLevel(LED2, d2);
  setLEDLevel(LED3, d3);
  setLEDLevel(LED4, d4);

  Serial.print(d1); Serial.print(",");
  Serial.print(d2); Serial.print(",");
  Serial.print(d3); Serial.print(",");
  Serial.println(d4);

  delay(800);
}
