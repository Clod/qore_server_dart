import 'dart:convert';
import 'dart:io';
import 'package:dart_socket/model/paciente.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:logger/logger.dart';
import 'package:mysql_client/mysql_client.dart';

enum Commands {
  addPatient,
  getPatientsByIdDoc,
  getPatientsByLastName,
  getPatientById,
  updatePatient,
  deletePatient,
  lockPatient,
}

var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    lineLength: 80,
  ),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

late MySQLConnection conn;

////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////   main      ////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
void main() async {
  Logger.level = Level.debug;

  final certificate = File('cauto_chain.pem').readAsBytesSync();
  final privateKey = File('cauto_key.pem').readAsBytesSync();

  loggerNoStack.i("Connecting to DataBase...");

  bool connectedToDB = false;

  // Try to connect to DB
  if (connectedToDB = await connectToDB(connectedToDB)) {
    logger.i("Connected to DB");
  } else {
    logger.e("Unable to connect to DB");
  }

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
      // I convert the message to a list of int
      List<int> intList = frame.toString().split(',').map((str) => int.parse(str)).toList();

      String responseMessage = "";

      // Extract action
      int action = intList[0];
      logger.d("Action: $action");

      // Extract message length
      int messageLength = intList[1] * 255 + intList[2];
      // print("Message Length: $messageLength");

      if (intList.sublist(3).length == messageLength) {
        // Process command
        var decoded = utf8.decode(intList.sublist(3));
        logger.d(decoded);

        if (connectedToDB) {
          if (action == Commands.getPatientsByLastName.index) {
            responseMessage = await getPatientsByLastName(decoded);
            logger.d(responseMessage);
          } else if (action == Commands.getPatientsByIdDoc.index) {
            responseMessage = await getPatientsByIdDoc(decoded);
            logger.d(responseMessage);
          } else if (action == Commands.addPatient.index) {
            String patient = utf8.decode(intList.sublist(3));
            responseMessage = await addPatient(patient);
          } else if (action == Commands.updatePatient.index) {
            String patient = utf8.decode(intList.sublist(3));
            responseMessage = await updatePatient(patient);
          } else if (action == Commands.lockPatient.index) {
            String patient = utf8.decode(intList.sublist(3));
            responseMessage = await lockPatient(patient);
          }
        } else {
          if (connectedToDB = await connectToDB(connectedToDB)) {
            logger.i("Connected to DB");
            responseMessage = '{"Result" : "Warning", "Message" : "Conectad a la BD por favor reintentar"}';
          } else {
            logger.e("Unable to connect to DB");
            // Report that I am not connected to DB
            responseMessage = '{"Result" : "Fatal", "Message" : "No hay conexión contra la Base de Datos."}';
          }
        }

        final encodedMessage = utf8.encode(responseMessage);
        final length = encodedMessage.length;
        final lengthL = length % 255;
        final lengthH = (length / 255).truncate();
        final header = [0x01, lengthH, lengthL];
        final answerFrame = [...header, ...encodedMessage];
        // print(answerFrame);
        // print(answerFrame.runtimeType);
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

Future<String> lockPatient(String patientData) async {
  logger.i("Received LOCK request for:  $patientData");
  String result = "";
  // Remove curly braces from the string
  String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');

// Split the string into an array of key-value pairs
  List<String> keyValuePairs = keyValueString.split(',');

// Create a new Map<String, dynamic> object
  Map<String, dynamic> resultMap = {};

// Populate the Map with key-value pairs
  for (String keyValue in keyValuePairs) {
    // Split each key-value pair by the colon
    List<String> pair = keyValue.split(':');

    // Trim whitespace from the key and value strings
    String key = pair[0].trim();
    String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());

    // Add the key-value pair to the Map
    resultMap[key] = value;
  }

  Paciente patient = Paciente.fromJson(resultMap);

  // Check if there is already a patient with the same id document from the same country
  try {
    logger.i("Comezando el lockeo para patient: $patient");
    // await conn.execute("START TRANSACTION");
    var checkResult = await conn.execute("SELECT * FROM pacientes WHERE nacionalidad = :nac and documento = :doc FOR UPDATE",
        {"nac": patient.nacionalidad, "doc": patient.documento});

    IResultSet? creationResult;

    if (checkResult.numOfRows < 1) {
      logger.i("Trying to update an unexistent patient: $patient");
      result = '{"Result" : "Failure", "Message" : "No existe un paciente con esa nacionalidad y documento" }';
    } else {
      logger.i("El paciente: $patient debería estat loquito.");
    }
    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    return result;
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

Future<bool> connectToDB(bool connectedToDB) async {
  try {
    // create connection
    conn = await MySQLConnection.createConnection(
      host: "127.0.0.1",
      port: 3306,
      userName: "root", // claudio
      password: "root", // claudio
      databaseName: "qore", // optional
    );

    await conn.connect();

    // Deactivate autocommit in order to enable row locking
    var result = await conn.execute("SELECT @@autocommit");

    // print query result
    for (final row in result.rows) {
      logger.d(row.assoc());
    }

    await conn.execute("SET autocommit = 0");

    result = await conn.execute("SELECT @@autocommit;");

    // print query result
    for (final row in result.rows) {
      logger.d(row.assoc());
    }

    logger.i("Autocommit: ${result.first.toString()}");

    loggerNoStack.i("Connected");

    connectedToDB = true;
  } catch (e) {
    logger.f(e);
  }
  return connectedToDB;
}

Future<String> getPatientsByLastName(String s) async {
  logger.d("Looking for patients by Last Name: $s");

  List<Map<String, dynamic>> retrievedPatients = [];

  // make query
  try {
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
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

Future<String> getPatientsByIdDoc(String s) async {
  logger.i("Looking for patients by Id Document: $s");
  List<Map<String, dynamic>> retrievedPatients = [];
  try {
    // make query
    var result = await conn.execute("SELECT * FROM pacientes WHERE documento LIKE :doc  LIMIT 10", {"doc": '%$s%'});

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
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

Future<String> addPatient(String patientData) async {
  logger.i("Received Creation request for:  $patientData");
  String result = "";
  // Remove curly braces from the string
  String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');

// Split the string into an array of key-value pairs
  List<String> keyValuePairs = keyValueString.split(',');

// Create a new Map<String, dynamic> object
  Map<String, dynamic> resultMap = {};

// Populate the Map with key-value pairs
  for (String keyValue in keyValuePairs) {
    // Split each key-value pair by the colon
    List<String> pair = keyValue.split(':');

    // Trim whitespace from the key and value strings
    String key = pair[0].trim();
    String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());

    // Add the key-value pair to the Map
    resultMap[key] = value;
  }

  Paciente patient = Paciente.fromJson(resultMap);
  try {
    // Check if there is already a patient with the same id document from the same country
    var checkResult = await conn.execute("SELECT * FROM pacientes WHERE nacionalidad = :nac and documento = :doc ",
        {"nac": patient.nacionalidad, "doc": patient.documento});

    IResultSet? creationResult;

    if (checkResult.numOfRows >= 1) {
      logger.i("Trying to create an already existent patient: $patient");
      result = '{"Result" : "Failure", "Message" : "Ya existe un paciente de ese país con el mismo nro. de documento" }';
    } else {
      creationResult = await conn.execute(
          "INSERT INTO pacientes (id, nombre, apellido, documento, nacionalidad, fechanacimiento, fecha_creacion_ficha, sexo, diagnostico_prenatal, paciente_fallecido, semanas_gestacion, diag1, diag2, diag3, diag4, fecha_primer_diagnostico, nro_hist_clinica_papel, nro_ficha_diag_prenatal, comentarios ) VALUES (:id, :nombre, :apellido, :documento, :nacionalidad, :fechanacimiento, :fecha_creacion_ficha, :sexo, :diagnostico_prenatal, :paciente_fallecido, :semanas_gestacion, :diag1, :diag2, :diag3, :diag4, :fecha_primer_diagnostico, :nro_hist_clinica_papel, :nro_ficha_diag_prenatal, :comentarios )",
          {
            "id": null,
            "nombre": patient.nombre,
            "apellido": patient.apellido,
            "documento": patient.documento,
            "nacionalidad": patient.nacionalidad,
            "fechanacimiento": patient.fechaNacimiento,
            "fecha_creacion_ficha": patient.fechaCreacionFicha,
            "sexo": patient.sexo,
            "diagnostico_prenatal": patient.diagnosticoPrenatal,
            "paciente_fallecido": patient.pacienteFallecido,
            "semanas_gestacion": patient.semanasGestacion,
            "diag1": patient.diag1,
            "diag2": patient.diag2,
            "diag3": patient.diag3,
            "diag4": patient.diag4,
            "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico,
            "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
            "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
            "comentarios": patient.comentarios
          });

      result =
          '{"Result" : "Success", "Message" : "Se creó el paciente ${patient.nombre} ${patient.apellido} con índice nro. ${creationResult.lastInsertID.toInt()}"}';
    }
    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    return result;
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la conexión contra la BD" }';
  }
}

Future<String> updatePatient(String patientData) async {
  logger.i("Received update request for:  $patientData");
  String result = "";
  // Remove curly braces from the string
  String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');

// Split the string into an array of key-value pairs
  List<String> keyValuePairs = keyValueString.split(',');

// Create a new Map<String, dynamic> object
  Map<String, dynamic> resultMap = {};

// Populate the Map with key-value pairs
  for (String keyValue in keyValuePairs) {
    // Split each key-value pair by the colon
    List<String> pair = keyValue.split(':');

    // Trim whitespace from the key and value strings
    String key = pair[0].trim();
    String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());

    // Add the key-value pair to the Map
    resultMap[key] = value;
  }

  Paciente patient = Paciente.fromJson(resultMap);

  // Check if there is already a patient with the same id document from the same country
  try {
    var checkResult = await conn.execute("SELECT * FROM pacientes WHERE nacionalidad = :nac and documento = :doc ",
        {"nac": patient.nacionalidad, "doc": patient.documento});

    IResultSet? creationResult;

    if (checkResult.numOfRows < 1) {
      logger.i("Trying to update an unexistent patient: $patient");
      result = '{"Result" : "Failure", "Message" : "No existe un paciente con esa nacionalidad y documento" }';
    } else {
      creationResult = await conn.execute(
          "UPDATE pacientes SET nombre = :nombre, apellido = :apellido, documento = :documento, nacionalidad = :nacionalidad, fechanacimiento = :fechaNacimiento, fecha_creacion_ficha = :fecha_creacion_ficha, sexo = :sexo, diagnostico_prenatal = :diagnostico_prenatal, paciente_fallecido = :paciente_fallecido, semanas_gestacion = :semanas_gestacion, diag1 = :diag1, diag2 = :diag2, diag3 = :diag3, diag4 = :diag4, fecha_primer_diagnostico = :fecha_primer_diagnostico, nro_hist_clinica_papel = :nro_hist_clinica_papel, nro_ficha_diag_prenatal = :nro_ficha_diag_prenatal, comentarios = :comentarios WHERE id = :id",
          {
            "id": patient.id,
            "nombre": patient.nombre,
            "apellido": patient.apellido,
            "documento": patient.documento,
            "nacionalidad": patient.nacionalidad,
            "fechaNacimiento": patient.fechaNacimiento,
            "fecha_creacion_ficha": patient.fechaCreacionFicha,
            "sexo": patient.sexo,
            "diagnostico_prenatal": patient.diagnosticoPrenatal,
            "paciente_fallecido": patient.pacienteFallecido,
            "semanas_gestacion": patient.semanasGestacion,
            "diag1": patient.diag1,
            "diag2": patient.diag2,
            "diag3": patient.diag3,
            "diag4": patient.diag4,
            "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico,
            "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
            "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
            "comentarios": patient.comentarios
          });

      result = '{"Result" : "Success", "Message" : "Se acualizó el paciente con índice nro. ${patient.id}"}';
    }
    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    return result;
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}
