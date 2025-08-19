import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:tiraafloja/services/mqtt/mqttManager.dart';
import 'package:tiraafloja/services/mqtt/mqttWebManager.dart';
class MqttController {
  static tryStartMqttConnection() async {
    if (kIsWeb) {
      String mqttIPAddress = "508c9593846c4549b1e00616ff6f42e9.s1.eu.hivemq.cloud";
      int mqttWebPort = 8884;
      //Para evitar errores, mientra pulimos el tema de mqtt interlo luego borrar las tres siguientes asignaciones
      //mqttIPAddress= await SettingsDataController.getLinuxAddress();
      //String portLinuxString = await SettingsDataController.getLinuxPort();
      //mqttWebPort= int.tryParse(portLinuxString)??1884;
      //mqttWebPort=1884;

      String ipWeb = "${mqttIPAddress}";
      print("Intento MQTT con WEB $ipWeb");
      final mqttManager = MqttWebManager();
      // Primera conexión
      await mqttManager.initialize(ipWeb, mqttWebPort);
    } else {
      String mqttIPAddress = "508c9593846c4549b1e00616ff6f42e9.s1.eu.hivemq.cloud";
      int mqttPort = 8883;
      String ipAnd = "${mqttIPAddress}";
      print("Intento MQTT con AND $ipAnd $mqttPort");
      final mqttManager = MqttAndManager();
      // Primera conexión
      await mqttManager.initialize(ipAnd, mqttPort);
    }
  }

  static onMessageReceived(
      String payloadString, String topicReceived, String origin) async {
    if (topicReceived.endsWith("rojo")) {
      print("topicAgent");
      recibidoRojo(payloadString, topicReceived, origin);
    } else if (topicReceived.endsWith("azul")) {
      print("topicAuth");
      recibidoAzul(payloadString, topicReceived, origin);
    }
  }

  static recibidoRojo(
      String payloadString, String topicReceived, String origin) {
    print("recibidoRojo: $payloadString");
  }

  static recibidoAzul(
      String payloadString, String topicReceived, String origin){
    print("recibidoAzul: $payloadString");
  }

  static sendMqttMessage(
      {required String topic, required String message}) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    print("Topico enviado desde Flutter");
    print(topic);
    print("Mensaje enviado desde Flutter");
    print(message);

    if (kIsWeb) {
      final mqttWebManager = MqttWebManager();
      // Primera conexión
      //topic, MqttQos.atMostOnce, builder.payload!
      mqttWebManager.publish(topic, message);
    } else {}
    return;
  }
}
