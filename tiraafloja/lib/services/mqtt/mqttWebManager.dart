import 'dart:async';

import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:tiraafloja/services/mqtt/mqttController.dart';

class MqttWebManager {
  static final MqttWebManager _instance = MqttWebManager._internal();

  factory MqttWebManager() => _instance;

  MqttWebManager._internal();

  MqttBrowserClient? _mqttWebClient;

  final StreamController<String> _messageStreamController =
  StreamController.broadcast();
  Stream<String> get messageStream => _messageStreamController.stream;

  Future<void> initialize(String hostIp, int port) async {
    // El hostIp para HiveMQ Cloud es el que te proporcionan sin el protocolo.
    final host = '508c9593846c4549b1e00616ff6f42e9.s1.eu.hivemq.cloud';
    final clientId = 'flutter_web_${DateTime.now().millisecondsSinceEpoch}';

    // --- CORRECCIÓN AQUÍ ---
    // 1. Usa el constructor `withPort`.
    // 2. Pasa el host SIN 'wss://' y SIN '/mqtt'.
    // 3. Pasa el puerto como un entero separado.
    _mqttWebClient = MqttBrowserClient.withPort(host, clientId, 8884);
    _mqttWebClient!
    // 4. Habilita explícitamente los WebSockets. Esto es CRUCIAL.
      //..useWebSocket = true
      ..setProtocolV311()
      ..logging(on: true)
      ..keepAlivePeriod = 60
    // La ruta '/mqtt' se añade por defecto con WebSockets, pero puedes ser explícito
    // si es necesario con `path`. websocketProtocols se refiere a los subprotocolos.
      ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;

    // El resto de tu configuración es correcta
    _mqttWebClient!.connectionMessage = MqttConnectMessage()
        .authenticateAs('tiraafloja', 'Tiraafloja123')
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('topic/tiraafloja')
        .withWillMessage('Client disconnected')
        .withWillQos(MqttQos.atLeastOnce);

    _mqttWebClient!.onConnected = _onConnected;
    _mqttWebClient!.onDisconnected = _onDisconnected;
    _mqttWebClient!.onSubscribed = _onSubscribed;
    _mqttWebClient!.onSubscribeFail = _onSubscribeFail;

    try {
      print("Connecting to HiveMQ via WebSocket...");
      await _mqttWebClient!.connect();
      if (_mqttWebClient!.connectionStatus?.state == MqttConnectionState.connected) {
        print("Connected to HiveMQ Cloud!");
        subscribe();
      } else {
        print("Failed to connect. Status: ${_mqttWebClient!.connectionStatus}");
        disconnect();
      }
    } catch (e) {
      print("Connection error: $e");
      disconnect();
    }
  }

/*
  Future<void> initialize(String hostIp,int port) async {
    final host = '${hostIp}/mqtt';
    final clientId = 'flutter_web_${DateTime.now().millisecondsSinceEpoch}';

    //_mqttWebClient = MqttBrowserClient.withPort(host, clientId, port);
    *//*_mqttWebClient = MqttBrowserClient(
      'wss://$hostIp:$port/mqtt',
      clientId,
    );*//*
    _mqttWebClient = MqttBrowserClient(
      'wss://508c9593846c4549b1e00616ff6f42e9.s1.eu.hivemq.cloud:8884/mqtt',
      clientId,
    );

    _mqttWebClient!
      //..useWebSocket = true
      ..setProtocolV311()
      ..logging(on: true)
      ..keepAlivePeriod = 60
      ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;

    _mqttWebClient!.connectionMessage = MqttConnectMessage()
        .authenticateAs('userAlejo', 'passAlejo123')
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('topic/tiraafloja')
        .withWillMessage('Client disconnected')
        .withWillQos(MqttQos.atLeastOnce);

    _mqttWebClient!.onConnected = _onConnected;
    _mqttWebClient!.onDisconnected = _onDisconnected;
    _mqttWebClient!.onSubscribed = _onSubscribed;
    _mqttWebClient!.onSubscribeFail = _onSubscribeFail;

    try {
      print("Connecting to HiveMQ via WebSocket...");
      await _mqttWebClient!.connect();
      if (_mqttWebClient!.connectionStatus?.state == MqttConnectionState.connected) {
        print("Connected!");
        subscribe();
      } else {
        print("Failed to connect. Status: ${_mqttWebClient!.connectionStatus}");
        disconnect();
      }
    } catch (e) {
      print("Connection error: $e");
      disconnect();
    }
  }*/



  void disconnect() {
    if (_mqttWebClient != null &&
        _mqttWebClient!.connectionStatus?.state ==
            MqttConnectionState.connected) {
      _mqttWebClient?.disconnect();
      _mqttWebClient = null;
      print("MQTT Desconectado correctamente");
    } else {
      print("MQTT ya está desconectado");
    }
  }

  Future<void> subscribe() async {

    String mqttAuthorizerTopic="topic/tiraafloja";
    //_mqttWebClient?.subscribe(topic, MqttQos.atMostOnce);

    _mqttWebClient?.subscribe(
      '$mqttAuthorizerTopic/#',
      MqttQos.atMostOnce,
    );
    _mqttWebClient?.published!.listen((event) async {
      print(event.payload.message);
      final String topicReceived = event.variableHeader?.topicName??"noNamedTopic";
      final String payload = MqttPublishPayload.bytesToStringAsString(event.payload.message);

      print('[PRINTLOG] ------> MQTT: listener');
      print('[PRINTLOG] ------> Mensaje recibido: $payload');
      await MqttController.onMessageReceived(payload,topicReceived,"web");
    });
  }

  void publish(String topic, String message) {
    try{
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _mqttWebClient?.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    }catch(e){
      print("Publish failed: $e");
    }
  }

  void _onConnected() {
    print("MQTT Connected");
  }

  void _onDisconnected() {
    print("MQTT Disconnected");

    _mqttWebClient = null;
  }

  void _onSubscribed(String topic) {
    print("Subscribed to topic: $topic");
  }

  void _onSubscribeFail(String topic) {
    print("Failed to subscribe to topic: $topic");
  }

  void dispose() {
    _messageStreamController.close();
    disconnect();
  }
}
