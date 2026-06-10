#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h> 
#include <WiFiClientSecure.h> 
#include <BLEDevice.h>      
#include <BLEServer.h>      
#include <Preferences.h> 

// 🔴 SUA URL DO FIREBASE (Mantenha a barra "/" no final)
const String firebaseURL = "https://vazus-504c6-default-rtdb.firebaseio.com/";

// 🔑 UUIDs CORRIGIDOS PARA BATER EXATAMENTE COM O SEU APP FLUTTER
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
bool dadosWifiRecebidos = false;
String wifiSSID = "";
String wifiPASS = "";

Preferences preferences;
WebServer server(80);

// Configurações de Pinos
const int pinoSensor = 4;      // Fio amarelo no D4
const int pinoBotaoReset = 0;  // Botão BOOT físico do ESP32
const int pinoLedInterno = 2;  // LED interno nativo do ESP32 (D2)

volatile unsigned long contadorPulsos = 0;
float vazaoLmin = 0.0;
float volumeTotalL = 0.0;
unsigned long tempoAnterior = 0;
unsigned long tempoUltimoResetMinuto = 0; 
const float fatorCalibracao = 7.5; 

unsigned long tempoBotaoPressionado = 0;
bool botaoPressionadoAnteriormente = false;

void IRAM_ATTR contarPulsos() {
  contadorPulsos++;
}

class BLECallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue().c_str();
      if (rxValue.length() > 0) {
        // ✨ CORRIGIDO: O app Flutter envia os dados separados por ';' e não por ','
        int divisorIndex = rxValue.indexOf(';');
        if (divisorIndex != -1) {
          wifiSSID = rxValue.substring(0, divisorIndex);
          wifiPASS = rxValue.substring(divisorIndex + 1);
          
          preferences.begin("wifi-config", false);
          preferences.putString("ssid", wifiSSID);
          preferences.putString("pass", wifiPASS);
          preferences.end();
          
          dadosWifiRecebidos = true;
        }
      }
    }
};

void enviarParaFirebase() {
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClientSecure cliente;
    cliente.setInsecure(); 
    
    HTTPClient http;
    String url = firebaseURL + "sensor_vazao.json"; 
    
    http.begin(cliente, url); 
    http.addHeader("Content-Type", "application/json");
    
    String jsonDados = "{\"vazao\":" + String(vazaoLmin, 2) + ",\"volume\":" + String(volumeTotalL, 3) + "}";
    
    int httpResponseCode = http.PUT(jsonDados); 
    http.end();
  }
}

void tratarPaginaWeb() {
  unsigned long tempoDecorrido = millis() - tempoUltimoResetMinuto;
  long tempoRestanteSegundos = (60000 - tempoDecorrido) / 1000;
  if (tempoRestanteSegundos < 0) tempoRestanteSegundos = 0;
  float porcentagemRestante = (tempoRestanteSegundos / 60.0) * 100.0;

  String html = "<html><head><meta charset='UTF-8'><meta http-equiv='refresh' content='1'></head>";
  html += "<body style='font-family:Arial, sans-serif; text-align:center; padding-top:40px; background-color:#F8F9FA;'>";
  html += "<div style='max-width:500px; margin:0 auto; background:white; padding:30px; border-radius:10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);'>";
  html += "<h1>Medidor IoT</h1>";
  html += "<hr style='border:0; border-top:1px solid #EEE; margin:20px 0;'>";
  html += "<h2 style='color:#007BFF; font-size:36px;'>" + String(vazaoLmin, 2) + " L/min</h2>";
  html += "<h2 style='color:#28A745; font-size:36px;'>" + String(volumeTotalL, 3) + " Litros</h2>";
  html += "<hr style='border:0; border-top:1px solid #EEE; margin:20px 0;'>";
  html += "<p style='color:#DC3545; font-weight:bold; font-size:18px; margin-bottom:10px;'>⏱️ Reiniciando em: " + String(tempoRestanteSegundos) + " segundos</p>";
  html += "<div style='width:100%; background-color:#E9ECEF; border-radius:5px; height:15px; overflow:hidden;'>";
  html += "<div style='width:" + String(porcentagemRestante) + "%; background-color:#DC3545; height:100%;'></div>";
  html += "</div></div></body></html>";
  server.send(200, "text/html", html);
}

void iniciarBluetoothCadastro() {
  for(int i = 0; i < 3; i++) {
    digitalWrite(pinoLedInterno, HIGH);
    delay(100);
    digitalWrite(pinoLedInterno, LOW);
    delay(100);
  }
  
  digitalWrite(pinoLedInterno, HIGH);

  // 🌐 NOME CORRIGIDO: Agora o Flutter vai listar o dispositivo na busca Bluetooth automaticamente
  BLEDevice::init("ESP32_Medidor_Vazao");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_WRITE
                    );
  pCharacteristic->setCallbacks(new BLECallbacks());
  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("Modo de Cadastro ATIVO. Conecte via Bluetooth!");
}

void verificarBotaoReset() {
  int estadoBotao = digitalRead(pinoBotaoReset);
  if (estadoBotao == LOW) {
    if (!botaoPressionadoAnteriormente) {
      tempoBotaoPressionado = millis();
      botaoPressionadoAnteriormente = true;
    } else {
      if (millis() - tempoBotaoPressionado >= 3000) { 
        Serial.println("Botao BOOT segurado por 3s! Apagando rede e reiniciando...");
        preferences.begin("wifi-config", false);
        preferences.clear();
        preferences.end();
        delay(500);
        ESP.restart(); 
      }
    }
  } else {
    botaoPressionadoAnteriormente = false;
  }
}

void setup() {
  Serial.begin(115200);
  
  pinMode(pinoSensor, INPUT_PULLUP);
  pinMode(pinoBotaoReset, INPUT_PULLUP); 
  pinMode(pinoLedInterno, OUTPUT); 
  
  digitalWrite(pinoLedInterno, LOW);
  
  attachInterrupt(digitalPinToInterrupt(pinoSensor), contarPulsos, FALLING);
  
  preferences.begin("wifi-config", true);
  wifiSSID = preferences.getString("ssid", "");
  wifiPASS = preferences.getString("pass", "");
  preferences.end();

  if (wifiSSID == "" || wifiPASS == "") {
    iniciarBluetoothCadastro();
    while (!dadosWifiRecebidos) {
      verificarBotaoReset(); 
      delay(10);
    }
    BLEDevice::deinit(true); 
  }

  WiFi.begin(wifiSSID.c_str(), wifiPASS.c_str());
  Serial.println("Conectando ao Wi-Fi...");
  
  unsigned long tempoTentativa = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    verificarBotaoReset();
    if (millis() - tempoTentativa > 15000) {
      preferences.begin("wifi-config", false);
      preferences.clear();
      preferences.end();
      ESP.restart();
    }
  }
  
  digitalWrite(pinoLedInterno, LOW);
  
  Serial.println("Wi-Fi Conectado com Sucesso!");
  server.on("/", tratarPaginaWeb);
  server.begin();
  
  tempoAnterior = millis();
  tempoUltimoResetMinuto = millis(); 
}

void loop() {
  server.handleClient();
  verificarBotaoReset(); 
  
  if ((millis() - tempoUltimoResetMinuto) >= 60000) {
    volumeTotalL = 0.0;                  
    tempoUltimoResetMinuto = millis();    
    enviarParaFirebase(); 
  }
  
  if ((millis() - tempoAnterior) > 1000) {
    noInterrupts();
    unsigned long pulsosIntervalo = contadorPulsos;
    contadorPulsos = 0;
    interrupts();
    
    unsigned long tempoDecorrido = millis() - tempoAnterior;
    tempoAnterior = millis();
    
    float frequenciaHz = (pulsosIntervalo * 1000.0) / tempoDecorrido;
    vazaoLmin = frequenciaHz / fatorCalibracao;
    
    float volumeIntervaloL = (vazaoLmin / 60.0) * (tempoDecorrido / 1000.0);
    volumeTotalL += volumeIntervaloL;
    
    enviarParaFirebase(); 
  }
}