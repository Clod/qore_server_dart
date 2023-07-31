class Paciente {
  Paciente({
    required this.id,
    required this.nombre,
    required this.apellido,
    this.fechaNacimiento,
    this.documento,
    this.nacionalidad,
    required this.fechaCreacionFicha,
    this.sexo,
    this.diagnosticoPrenatal,
    this.pacienteFallecido,
    this.semanasGestacion,
    this.diag1,
    this.diag2,
    this.diag3,
    this.diag4,
    this.fechaPrimerDiagnostico,
    this.nroHistClinicaPapel,
    this.nroFichaDiagPrenatal,
    this.comentarios,
  });

  final int id;
  String nombre;
  String apellido;
  String? documento;
  String? nacionalidad;
  String? fechaNacimiento;
  String fechaCreacionFicha;
  String? sexo;
  String? diagnosticoPrenatal;
  String? pacienteFallecido;
  int? semanasGestacion;
  String? diag1;
  String? diag2;
  String? diag3;
  String? diag4;
  String? fechaPrimerDiagnostico;
  String? nroHistClinicaPapel;
  String? nroFichaDiagPrenatal;
  String? comentarios;

  factory Paciente.fromJson(Map<String, dynamic> data) {
// note the explicit cast to String
// this is required if robust lint rules are enabled
    final id = int.parse(data['id']);
    final nombre = data['nombre'] as String;
    final apellido = data['apellido'] as String;
    final fechaNacimiento = data['fechaNacimiento'] != null ? data['fechaNacimiento'] as String? : null;
    final documento = data['documento'] as String?;
    final nacionalidad = data['nacionalidad'] as String?;
    final fechaCreacionFicha = data['fechaCreacionFicha'] as String;
    final sexo = data['sexo'] as String?;
    final diagnosticoPrenatal = data['diagnosticoPrenatal'] as String?;
    final pacienteFallecido = data['pacienteFallecido'] as String?;
    final semanasGestacion = data['semanasGestacion'] != null ? int.parse(data['semanasGestacion']) : null;
    final diag1 = data['diag1'] != null ? data['diag1'] as String? : null ;
    final diag2 = data['diag2'] != null ? data['diag2'] as String? : null ;
    final diag3 = data['diag3'] != null ? data['diag3'] as String? : null ;
    final diag4 = data['diag4'] != null ? data['diag4'] as String? : null ;
    final fechaPrimerDiagnostico = data['fechaPrimerDiagnostico'] != null ? data['fechaPrimerDiagnostico'] as String? : null;
    final nroHistClinicaPapel = data['nroHistClinicaPapel']  != null ? data['nroHistClinicaPapel'] as String? : null;
    final nroFichaDiagPrenatal = data['nroFichaDiagPrenatal'] != null ? data['nroFichaDiagPrenatal'] as String? : null;
    final comentarios = data['comentarios'] != null ? data['comentarios'] as String? : null;

    return Paciente(
      id: id,
      nombre: nombre,
      apellido: apellido,
      fechaNacimiento: fechaNacimiento,
      documento: documento,
      nacionalidad: nacionalidad,
      fechaCreacionFicha: fechaCreacionFicha,
      sexo: sexo,
      diagnosticoPrenatal: diagnosticoPrenatal,
      pacienteFallecido: pacienteFallecido,
      semanasGestacion: semanasGestacion,
      diag1: diag1,
      diag2: diag2,
      diag3: diag3,
      diag4: diag4,
      fechaPrimerDiagnostico: fechaPrimerDiagnostico,
      nroHistClinicaPapel: nroHistClinicaPapel,
      nroFichaDiagPrenatal: nroFichaDiagPrenatal,
      comentarios: comentarios,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'fechaNacimiento': fechaNacimiento,
        'documento': documento,
        'nacionalidad': nacionalidad,
        'fechaCreacionFicha': fechaCreacionFicha,
        'sexo': sexo,
        'diagnosticoPrenatal': diagnosticoPrenatal,
        'pacienteFallecido': pacienteFallecido,
        'semanasGestacion': semanasGestacion,
        'diag1': diag1,
        'diag2': diag2,
        'diag3': diag3,
        'diag4': diag4,
        'fechaPrimerDiagnostico': fechaPrimerDiagnostico,
        'nroHistClinicaPapel': nroHistClinicaPapel,
        'nroFichaDiagPrenatal': nroFichaDiagPrenatal,
        'comentarios': comentarios,
      };

  @override
  String toString() {
    // return (id.toString() + " " + nombre + " " + apellido);
    return toJson().toString();
  }
}
