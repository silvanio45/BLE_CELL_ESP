import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleScanPage extends StatefulWidget {
  final Function(DiscoveredDevice) onDeviceSelected;

  BleScanPage({required this.onDeviceSelected});

  @override
  _BleScanPageState createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  Future<void> _checkPermissionsAndStartScan() async {
    var locationStatus = await Permission.location.status;
    var bluetoothScanStatus = await Permission.bluetoothScan.status;
    var bluetoothConnectStatus = await Permission.bluetoothConnect.status;

    if (!locationStatus.isGranted) {
      await Permission.location.request();
    }
    if (!bluetoothScanStatus.isGranted) {
      await Permission.bluetoothScan.request();
    }
    if (!bluetoothConnectStatus.isGranted) {
      await Permission.bluetoothConnect.request();
    }

    if (await Permission.location.isGranted &&
        await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      _startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permissões necessárias não concedidas.')),
        );
      }
    }
  }

  void _startScan() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    _scanSubscription = _ble.scanForDevices(
      withServices: [], 
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (_scanResults.every((element) => element.id != device.id)) {
        if (mounted) {
          setState(() {
            _scanResults.add(device);
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
      print('Erro durante o escaneamento: $error');
    }, onDone: () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  void _stopScan() {
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    _stopScan();
    try {
      _ble
          .connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 10),
      )
          .listen((connectionState) {
        if (connectionState.connectionState ==
            DeviceConnectionState.connected) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Conectado a ${device.name}')),
            );
          }
        }
      }, onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao conectar: $error')),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar ao dispositivo: $e')),
        );
      }
      print('Erro ao conectar ao dispositivo: $e');
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos BLE Disponíveis'),
        actions: [
          _isScanning
              ? IconButton(icon: Icon(Icons.stop), onPressed: _stopScan)
              : IconButton(icon: Icon(Icons.search), onPressed: _startScan),
        ],
      ),
      body: Column(
        children: [
          _isScanning
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      return ListTile(
                        title: Text(result.name.isNotEmpty
                            ? result.name
                            : 'Desconhecido'),
                        subtitle: Text(result.id),
                        onTap: () {
                          widget.onDeviceSelected(
                              result); 
                        },
                      );
                    },
                  ),
                ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }
}
