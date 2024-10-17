import 'package:appble/App_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ble_scan_page.dart';

class HomeApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return HomeAppState();
  }
}

class HomeAppState extends State<HomeApp> {
  final List<Map<String, int>> _dataList = [];
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  late Stream<ConnectionStateUpdate> _connectionStream;
  bool _isConnected = false;
  late QualifiedCharacteristic _txCharacteristic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 146, 161, 173),
        title: Image.asset(
          'assets/Imagens/ImgLive.png',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
        actions: [CustomSw()],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Especificações'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller1,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tamanho do Json (em bytes)',
                      ),
                    ),
                    TextField(
                      controller: _controller2,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tamanho do Chunk (em bytes)',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        int input1 = int.parse(_controller1.text);
                        int input2 = int.parse(_controller2.text);
                        _dataList.add({'json': input1, 'chunk': input2});
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              _stopScan(); // Parar o scan antes de navegar
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleScanPage(
                    onDeviceSelected: _connectToDevice,
                  ),
                ),
              );
            },
            child: const Text('Iniciar Scaneamento BLE'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _dataList.length,
              itemBuilder: (context, index) {
                final item = _dataList[index];
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.0),
                  child: TextButton(
                    onPressed: () async {
                      if (_isConnected) {
                        int jsonSize = item['json']!;
                        int chunkSize = item['chunk']!;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Enviando JSON de $jsonSize bytes em pacotes de $chunkSize bytes',
                            ),
                          ),
                        );

                        String jsonData = _generateDummyJson(jsonSize);

                        await _sendJsonInChunks(jsonData, chunkSize);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Nenhum dispositivo Bluetooth conectado.'),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 167, 179, 189),
                    ),
                    child: ListTile(
                      title: Text(
                        'Tamanho do Json: ${item['json']} bytes, Chunk: ${item['chunk']} bytes',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    _connectionStream = _ble.connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 10),
    );

    _connectionStream.listen((event) {
      if (event.connectionState == DeviceConnectionState.connected) {
        if (!mounted) return; // Verifique se ainda está montado
        setState(() {
          _isConnected = true;
        });

        // Define a característica de transmissão (TX)
        _txCharacteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse("service-uuid"), // Substitua pelo UUID correto
          characteristicId:
              Uuid.parse("characteristic-uuid"), // Substitua pelo UUID correto
          deviceId: device.id,
        );

        if (!mounted) return; // Verifique se ainda está montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispositivo conectado')),
        );
      } else if (event.connectionState == DeviceConnectionState.disconnected) {
        if (!mounted) return; // Verifique se ainda está montado
        setState(() {
          _isConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispositivo desconectado')),
        );
      }
    }, onError: (error) {
      if (!mounted) return; // Verifique se ainda está montado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na conexão: $error')),
      );
    });
  }

  // Função para gerar um JSON fictício com o tamanho especificado
  String _generateDummyJson(int sizeInBytes) {
    String data = '';
    while (data.length < sizeInBytes) {
      data += 'A'; // Simplesmente preenche o JSON com a letra "A"
    }
    return '{"data": "$data"}'; // Formato JSON
  }

  // Função para enviar o JSON em chunks
  Future<void> _sendJsonInChunks(String jsonData, int chunkSize) async {
    int totalBytes = jsonData.length;
    int offset = 0;

    while (offset < totalBytes) {
      int end =
          (offset + chunkSize > totalBytes) ? totalBytes : offset + chunkSize;
      String chunk = jsonData.substring(offset, end);

      // Envia o chunk via BLE
      await _ble.writeCharacteristicWithResponse(_txCharacteristic,
          value: chunk.codeUnits);

      // Simular atraso de envio BLE
      await Future.delayed(Duration(milliseconds: 100));

      offset = end;
    }

    if (!mounted) return; // Verifique se ainda está montado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Envio completo!')),
    );
  }

  void _stopScan() {
    // Implementar a lógica para parar o scan, se necessário
  }
}

// Switch para alternar o tema
class CustomSw extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Switch(
      value: ThemeController.instance.switchValue,
      onChanged: (value) {
        ThemeController.instance.changeTheme();
      },
    );
  }
}
