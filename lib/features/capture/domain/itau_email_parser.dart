import 'package:intl/intl.dart';

enum EmailCaptureKind {
  transferOut,
  transferIn,
  servicePayment,
  ignored,
  unrecognized,
}

class EmailCapture {
  final EmailCaptureKind kind;
  final String messageId;
  final int? amount;
  final DateTime? occurredAt;
  final bool hasTime;
  final String? counterparty;
  final String? payer;
  final String? entity;
  final String? concept;
  final String? operationId;
  final String sanitizedRawText;

  const EmailCapture({
    required this.kind,
    required this.messageId,
    this.amount,
    this.occurredAt,
    this.hasTime = false,
    this.counterparty,
    this.payer,
    this.entity,
    this.concept,
    this.operationId,
    this.sanitizedRawText = '',
  });

  String get fingerprint => 'email:$messageId';
}

/// Normaliza un nombre de persona para usar como clave de búsqueda/reglas:
/// mayúsculas, sin tildes ni caracteres especiales, espacios simples y recortados.
String normalizePersonKey(String name) {
  var s = name.toUpperCase().trim();
  const map = {
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'À': 'A',
    'È': 'E',
    'Ì': 'I',
    'Ò': 'O',
    'Ù': 'U',
    'Â': 'A',
    'Ê': 'E',
    'Î': 'I',
    'Ô': 'O',
    'Û': 'U',
    'Ã': 'A',
    'Õ': 'O',
    'Ñ': 'N',
  };
  map.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

EmailCapture parseItauEmail({
  required String messageId,
  required String subject,
  required String bodyText,
  required DateTime receivedAt,
}) {
  final normSubject = subject.trim().toLowerCase();
  final EmailCaptureKind kind;
  if (normSubject == 'aviso de transferencia enviada') {
    kind = EmailCaptureKind.transferOut;
  } else if (normSubject == 'aviso de transferencia recibida') {
    kind = EmailCaptureKind.transferIn;
  } else if (normSubject == 'aviso de pago de servicios') {
    kind = EmailCaptureKind.servicePayment;
  } else {
    return EmailCapture(
      kind: EmailCaptureKind.ignored,
      messageId: messageId,
      sanitizedRawText: '',
    );
  }

  final cleanBody = bodyText.replaceAll('&nbsp;', ' ');

  String? extract(String label) {
    final pattern = RegExp(
      // El campo empieza al inicio, tras un salto o tras un "|": en el teléfono todo llega en una línea.
      r'(?:^|\n|\|)\s*' + RegExp.escape(label) + r'[:\s]*\|\s*(.*?)\s*\|',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(cleanBody);
    if (match == null) return null;
    final val = match.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (val == null || val.isEmpty) return null;
    return val;
  }

  String? operationId = extract('Nro. de operación');
  final dateStr = extract('Fecha y hora de operación');

  final String? payer;
  final String? counterparty;
  final String? entity;
  final String? concept;
  final String? amountRaw;

  if (kind == EmailCaptureKind.transferOut) {
    payer = extract('Cliente Pagador');
    counterparty = extract('Cliente Beneficiario');
    entity = extract('Entidad beneficiaria');
    concept = extract('Concepto de la Transferencia');
    amountRaw = extract('Moneda y Monto');
  } else if (kind == EmailCaptureKind.transferIn) {
    payer = extract('Cliente Pagador');
    counterparty = payer;
    entity = extract('Entidad pagadora');
    concept = extract('Concepto de la Transferencia');
    amountRaw = extract('Moneda y Monto');
  } else {
    // servicePayment
    payer = extract('Nombre del cliente');
    counterparty = null;
    entity = null;
    concept = extract('Concepto del servicio');
    amountRaw = extract('Monto del pago');
  }

  if (amountRaw == null) {
    return EmailCapture(
      kind: EmailCaptureKind.unrecognized,
      messageId: messageId,
      sanitizedRawText: '',
    );
  }

  final digits = amountRaw.replaceAll(RegExp(r'[^\d]'), '');
  final amount = int.tryParse(digits);
  if (amount == null || amount <= 0) {
    return EmailCapture(
      kind: EmailCaptureKind.unrecognized,
      messageId: messageId,
      sanitizedRawText: '',
    );
  }

  DateTime? occurredAt;
  bool hasTime = false;

  if (dateStr != null) {
    // Probar formatos comunes:
    // dd/MM/yyyy HH:mm:ss
    // dd/MM/yyyy HH:mm
    // dd/MM/yyyy
    final dateTimePattern = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
    );
    final m = dateTimePattern.firstMatch(dateStr.trim());
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      final h = m.group(4) != null ? int.parse(m.group(4)!) : null;
      final min = m.group(5) != null ? int.parse(m.group(5)!) : null;
      final s = m.group(6) != null ? int.parse(m.group(6)!) : 0;

      if (h != null && min != null) {
        hasTime = true;
        occurredAt = DateTime(y, mo, d, h, min, s);
      } else {
        hasTime = false;
        occurredAt = (kind == EmailCaptureKind.servicePayment)
            ? receivedAt
            : DateTime(y, mo, d);
      }
    }
  }

  occurredAt ??= receivedAt;

  // Sanitized raw text: nunca incluye números de cuenta ni ****XXXX.
  final parts = <String>[
    switch (kind) {
      EmailCaptureKind.transferOut => 'Transferencia enviada',
      EmailCaptureKind.transferIn => 'Transferencia recibida',
      EmailCaptureKind.servicePayment => 'Pago de servicio',
      _ => '',
    },
    if (counterparty != null && counterparty.isNotEmpty) counterparty,
    if (entity != null && entity.isNotEmpty) entity,
    'Gs. ${NumberFormat('#,##0', 'es_PY').format(amount).replaceAll(',', '.')}',
    dateStr ?? DateFormat('dd/MM/yyyy').format(occurredAt),
    if (concept != null && concept.isNotEmpty) concept,
    if (operationId != null && operationId.isNotEmpty) 'Op. $operationId',
  ];

  final sanitizedRawText = parts.join(' · ');

  return EmailCapture(
    kind: kind,
    messageId: messageId,
    amount: amount,
    occurredAt: occurredAt,
    hasTime: hasTime,
    counterparty: counterparty,
    payer: payer,
    entity: entity,
    concept: concept,
    operationId: operationId,
    sanitizedRawText: sanitizedRawText,
  );
}
