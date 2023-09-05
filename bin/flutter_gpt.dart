import 'dart:async';
import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

Future<void> main() async {
  final server = await shelf_io.serve(handleRequest, 'localhost', 8080);
  print('Server running on localhost:${server.port}');
}

Future<Response> handleRequest(Request request) async {
  final responseCompleter = Completer<Response>();

  // Connect to MySQL database
  final conn = await MySqlConnection.connect(ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'root',
    db: 'qore',
  ));

  // Handle each request in a different thread
  Future(() async {
    // Process the request here
    // You can perform database operations using the `conn` instance

    // Example: Fetch data from a table
    final results = await conn.query('SELECT * FROM pacientes');
    for (var row in results) {
      print(row);
    }

    // Close the database connection
    await conn.close();

    // Return the response
    final response = Response.ok('Request handled successfully');
    responseCompleter.complete(response);
  });

  return responseCompleter.future;
}