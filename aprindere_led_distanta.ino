#define ECHOPIN 2
#define TRIGPIN 3

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  Serial.begin(9600);

  pinMode(ECHOPIN, INPUT);
  pinMode(TRIGPIN, OUTPUT);
}

void loop() {
  // Trigger pulse
  digitalWrite(TRIGPIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIGPIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGPIN, LOW);

  // Read echo
  long duration = pulseIn(ECHOPIN, HIGH, 30000);

  if (duration == 0) {
    digitalWrite(LED_BUILTIN, LOW); // fără citire → LED stins
    return;
  }

  float distance = duration / 58.0;

  // LED aprins când distanța < 50 cm, altfel stins
  if (distance < 5) {
    digitalWrite(LED_BUILTIN, HIGH);
  } else {
    digitalWrite(LED_BUILTIN, LOW);
  }

  Serial.println(distance);
  delay(200);
}

