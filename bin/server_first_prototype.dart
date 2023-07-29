import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_static/shelf_static.dart';

void main() async {
  // openssl s_client -connect vcsinc.com.ar:8080 -showcerts
  print("Arrancando el servidor");
  // Load the SSL certificates
  // final certificate = File('cert.pem').readAsBytesSync();
  // final privateKey = File('key.pem').readAsBytesSync();
  // Certificates and keys can be added to a SecurityContext from either PEM or PKCS12 containers.
//  final certificate = File('vcsinc_public.pem').readAsBytesSync();

  final certificate = File('cauto_chain.pem').readAsBytesSync();
  final privateKey = File('cauto_key.pem').readAsBytesSync();

  late final SecurityContext context;

  try {
      context = SecurityContext()
        ..useCertificateChainBytes(certificate)
        ..usePrivateKeyBytes(privateKey);
  } catch (e) {
    print(e);
    exit(33);
  }

  var handler = webSocketHandler((webSocket) {
    webSocket.stream.listen((message) {
      webSocket.sink.add("echo $message");
      print("Recibí: $message");
      final decoded = utf8.decode(message);
      print("Recibí: $decoded");
    });
  });


  try {
    shelf_io
          .serve(
        handler,
        '127.0.0.1',
        8080,
        securityContext: context,
      )
          .then((server) {
        print('Serving at ws://${server.address.host}:${server.port}');
      });
  } catch (e) {
    print(e);
  }

}
