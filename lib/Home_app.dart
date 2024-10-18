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
              _stopScan();
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

    _connectionStream.listen((event) async {
      if (event.connectionState == DeviceConnectionState.connected) {
        if (!mounted) return; 
        setState(() {
          _isConnected = true;
        });

        try {
          final mtuResult = await _ble.requestMtu(
            deviceId: device.id,
            mtu: 512,
          );
          print("MTU ajustado para: $mtuResult");
        } catch (e) {
          print("Erro ao ajustar o MTU: $e");
        }

        _txCharacteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(
              "f3aa0d0e-1ec1-4b6f-b7b3-4d49a5fefe89"),
          characteristicId: Uuid.parse(
              "d5382a13-c315-414c-b252-9cdb1e944e51"),
          deviceId: device.id,
        );

        if (!mounted) return; 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispositivo conectado')),
        );
      } else if (event.connectionState == DeviceConnectionState.disconnected) {
        if (!mounted) return; 
        setState(() {
          _isConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispositivo desconectado')),
        );
      }
    }, onError: (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na conexão: $error')),
      );
    });
  }

  String _generateDummyJson(int sizeInBytes) {
    String data = '';
    while (data.length < sizeInBytes) {
      data += 'A'; 
    }
    return '{"data": "$data"}';
  }

  Future<void> _sendJsonInChunks(String jsonData, int chunkSize) async {
    int totalBytes = jsonData.length;
    int offset = 0;

    while (offset < totalBytes) {
      int end =
          (offset + chunkSize > totalBytes) ? totalBytes : offset + chunkSize;
      String chunk = jsonData.substring(offset, end);

      await _ble.writeCharacteristicWithoutResponse(
        _txCharacteristic,
        value: chunk.codeUnits,
      );
      Future.delayed(Duration(milliseconds: 1));
      offset = end;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Envio completo!')),
    );
  }

  void _stopScan() {

  }
}

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
