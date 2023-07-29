import 'dart:convert';
import 'dart:io';
import 'package:dart_socket/model/paciente.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:logger/logger.dart';
import 'package:mysql_client/mysql_client.dart';

enum Commands { addPatient, getPatientsByIdDoc, getPatientsByLastName, getPatientById, updatePatient, deletePatient }

var logger = Logger(
  printer: PrettyPrinter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

late MySQLConnection conn;

void main() async {
  Logger.level = Level.debug;

  final certificate = File('cauto_chain.pem').readAsBytesSync();
  final privateKey = File('cauto_key.pem').readAsBytesSync();

  loggerNoStack.i("Connecting to DataBase...");

/* Para corresrlo en el VPS
  final conn = await MySQLConnection.createConnection(
    host: "127.0.0.1",
    port: 3306,
    secure: false,
    userName: "claudio",
    password: "claudio",
    databaseName: "qore", // optional
  );
*/

  // create connection
  conn = await MySQLConnection.createConnection(
    host: "127.0.0.1",
    port: 3306,
    userName: "root",
    password: "root",
    databaseName: "qore", // optional
  );

  await conn.connect();

  loggerNoStack.i("Connected");

/*
  // make query
  var result = await conn.execute("SELECT * FROM pacientes LIMIT 2");

  // print some result data
  logger.d(result.numOfColumns);
  logger.d(result.numOfRows);
  logger.d(result.lastInsertID);
  logger.d(result.affectedRows);

  // print query result
  for (final row in result.rows) {
    // print(row.colAt(0));
    // print(row.colByName("title"));

    // print all rows as Map<String, String>
    logger.d(row.assoc());
  }
*/

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
    webSocket.stream.listen((frame) async {
      logger.d(frame.runtimeType);
      // I convert the message to a list of int
      List<int> intList = frame.toString().split(',').map((str) => int.parse(str)).toList();

      String listaPacientes = "";

      // Extract action
      int action = intList[0];
      logger.d("Action: $action");

      // Extract message length
      int messageLength = intList[1];
      print("Message Length: $messageLength");

      if (intList.sublist(2).length == messageLength) {
        // Process command
        var decoded = utf8.decode(intList.sublist(2));
        logger.d(decoded);

        if (action == Commands.getPatientsByLastName.index) {
          logger.d("Looking for patients by Last Name");
          listaPacientes = await getPatientsByLastName(decoded);
          logger.d(listaPacientes);
        }

        final message = listaPacientes;
        final encodedMessage = utf8.encode(message);
        final length = encodedMessage.length;
        final lengthL = length % 255;
        final lengthH = (length / 255).truncate();
        final header = [0x01, lengthH, lengthL];
        final answerFrame = [...header, ...encodedMessage];
        print(answerFrame);
        print(answerFrame.runtimeType);
        webSocket.sink.add(answerFrame);


        webSocket.sink.add("$frame");
      } else {
        print("Recibí: $frame llegó corrupto");
        final message = "Error de comunicacion";
        final encodedMessage = utf8.encode(message);
        final length = encodedMessage.length;
        final header = [0x01, length];
        final answerFrame = [...header, ...encodedMessage];
        print(answerFrame);
        print(answerFrame.runtimeType);
        webSocket.sink.add(answerFrame);
      }
    });
  });

  try {
    shelf_io
        .serve(
      handler,
      '0.0.0.0',
      8080,
      securityContext: context,
    )
        .then((server) {
      loggerNoStack.i('Serving at wss://${server.address.host}:${server.port}');
    });
  } catch (e) {
    loggerNoStack.f(e);
  }
}

Future<String> getPatientsByLastName(String s) async {
  List<Map<String, dynamic>> retrievedPatients = [];

  // make query
  var result = await conn.execute("SELECT * FROM pacientes WHERE apellido LIKE :ape  LIMIT 10", {"ape": '%$s%'});

  // print query result
  for (final row in result.rows) {
    logger.d(row.assoc());
    logger.d(row.assoc().runtimeType);
    // retrievedPatients.add(Paciente.fromJson(row.assoc()));
    retrievedPatients.add(row.assoc());
  }
  // logger.d("Number of rows retrieved: ${result.numOfRows}");
  // logger.d("Rows retrieved: $retrievedPatients");
  logger.d(jsonEncode(retrievedPatients));

  return jsonEncode(retrievedPatients);
}
