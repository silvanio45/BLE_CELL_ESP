#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

#define SERVICE_UUID "f3aa0d0e-1ec1-4b6f-b7b3-4d49a5fefe89" 
#define CHARACTERISTIC_UUID "d5382a13-c315-414c-b252-9cdb1e944e51"

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;

int state = 0;
bool deviceConnected = false;

int cont = 0;
unsigned long totalBytesReceived = 0; 


unsigned long startTime = 0;  
bool receivingJson = false;  

class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Dispositivo conectado!");
  };

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Dispositivo desconectado!");
  }
};

class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = String(pCharacteristic->getValue().c_str());
    if (rxValue.length() > 0) {
      // Inicia o temporizador se começar a receber um novo JSON
      if (!receivingJson) {
        startTime = millis();
        totalBytesReceived = 0;  
        receivingJson = true; 
      }

      Serial.println(cont);
      cont++;*/

      totalBytesReceived += rxValue.length();

      // Aqui você pode verificar se o JSON completo foi recebido
      if (rxValue.endsWith("}")) {
        // Finaliza o temporizador e calcula o tempo total
        unsigned long elapsedTime = millis() - startTime;
        Serial.print("Tempo para receber JSON completo: ");
        Serial.print(elapsedTime);
        Serial.println(" ms");

        Serial.print("Tamanho total do arquivo recebido: ");
        Serial.print(totalBytesReceived);
        Serial.println(" bytes");

        cont = 0;
        receivingJson = false;
      }
    }
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Iniciando servidor BLE...");

  BLEDevice::init("ESP32_BLE");

  BLEDevice::setMTU(512);

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_WRITE
                    );

  pCharacteristic->setValue("Valor inicial\n");
  pCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); 
  pAdvertising->setMinPreferred(0x12); 
  pAdvertising->start();

  Serial.println("Dispositivo ESP32 BLE está agora anunciando...\n\n");
}

void loop() {
} 
