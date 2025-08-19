import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:tiraafloja/services/mqtt/mqttController.dart';

class MqttAndManager {
  static final MqttAndManager _instance = MqttAndManager._internal();

  factory MqttAndManager() => _instance;

  MqttAndManager._internal();

  MqttClient? _mqttClient;

  final StreamController<String> _messageStreamController =
      StreamController.broadcast();
  Stream<String> get messageStream => _messageStreamController.stream;

  Future<void> initialize(String ip, int port) async {
    print("Hola MQTT: initialize");
    if (_mqttClient != null &&
        _mqttClient!.connectionStatus?.state == MqttConnectionState.connected) {
      print("MQTT already connected");

      return;
    }

    _mqttClient = MqttServerClient.withPort(
        ip, 'flutter_client_${DateTime.now().millisecondsSinceEpoch}', port);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
            'and_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    _mqttClient!.connectionMessage = connMessage;

    try {
      print("Intento conectar mqqtt");

      await _mqttClient!.connect();
      if (_mqttClient != null &&
          _mqttClient!.connectionStatus?.state ==
              MqttConnectionState.connected) {
        subscribe();
      }
    } catch (e) {
      print("Connection failed: $e");
      disconnect();
    }

    _mqttClient!.logging(on: true);
    _mqttClient!.keepAlivePeriod = 60;
    //_mqttClient!.websocketProtocols = ['mqtt'];
    //_mqttClient!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    _mqttClient!.setProtocolV311();
    _mqttClient!.onConnected = _onConnected;
    _mqttClient!.onDisconnected = _onDisconnected;
    _mqttClient!.onSubscribed = _onSubscribed;
    _mqttClient!.onSubscribeFail = _onSubscribeFail;
  }

  void disconnect() {
    if (_mqttClient != null &&
        _mqttClient!.connectionStatus?.state == MqttConnectionState.connected) {
      _mqttClient?.disconnect();
      _mqttClient = null;
      print("MQTT Desconectado correctamente");
    } else {
      print("MQTT ws:: ya está desconectado");
    }
  }

  Future<void> subscribe() async {
    String mqttAuthorizerTopic = "topic/tiraafloja";
    _mqttClient?.subscribe(
      '$mqttAuthorizerTopic/#',
      MqttQos.atMostOnce,
    );
    _mqttClient?.published!.listen((event) async {
      print(event.payload.message);
      final String topicReceived =
          event.variableHeader?.topicName ?? "noNamedTopic";
      final String payload =
          MqttPublishPayload.bytesToStringAsString(event.payload.message);
      print('[PRINTLOG] ------> MQTT: listener');
      print(
          '[PRINTLOG] ------> Mensaje recibido: $payload');
      await MqttController.onMessageReceived(payload, topicReceived, "web");
    });
  }

  void publish(String topic, String message) {
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _mqttClient?.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    } catch (e) {
      print("Publish failed: $e");
    }
  }

  void _onConnected() {
    print("MQTT Connected");

  }

  void _onDisconnected() {
    print("MQTT Disconnected");

    _mqttClient = null;
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
