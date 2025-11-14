// GUNOI 1
#define LED1  13
#define ECHO1 2
#define TRIG1 3

// GUNOI 2
#define LED2  12
#define ECHO2 4
#define TRIG2 5

// GUNOI 3
#define LED3  11
#define ECHO3 6
#define TRIG3 7

// GUNOI 4
#define LED4  10
#define ECHO4 8
#define TRIG4 9 

void setup() {
  pinMode(LED1, OUTPUT);  
  pinMode(ECHO1, INPUT); 
  pinMode(TRIG1, OUTPUT);  

  pinMode(LED2, OUTPUT);  
  pinMode(ECHO2, INPUT);
  pinMode(TRIG2, OUTPUT); 
  
  pinMode(LED3, OUTPUT);  
  pinMode(ECHO3, INPUT);
  pinMode(TRIG3, OUTPUT); 
  
  pinMode(LED4, OUTPUT);  
  pinMode(ECHO4, INPUT);
  pinMode(TRIG4, OUTPUT); 


  Serial.begin(9600);
}

void led(int TRIGPIN,int ECHOPIN,int LED){ // Trigger pulse
  digitalWrite(TRIGPIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIGPIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGPIN, LOW);

  // Read echo
  long duration = pulseIn(ECHOPIN, HIGH, 30000);

  if (duration == 0) {
    digitalWrite(LED, LOW); // fără citire → LED stins
    return;
  }

  float distance = duration / 58.0;

  // LED aprins când distanța < 50 cm, altfel stins
  if (distance < 5) {
    digitalWrite(LED, HIGH);
  } else {
    digitalWrite(LED, LOW);
  }

  Serial.println(distance);
  delay(200);
}


void loop() {
  led(TRIG1, ECHO1, LED1);
  led(TRIG2, ECHO2, LED2);
  led(TRIG3, ECHO3, LED3);
  led(TRIG4, ECHO4, LED4);
}

