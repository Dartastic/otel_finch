// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_finch_suppression.dart';

const _tracerName = 'dartastic_otel_libs_finch';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class FinchResult {
  const FinchResult({
    this.itemCount,
    this.providerId,
    this.authMethod,
    this.connectionStatus,
    this.productCategory,
    this.batchSize,
    this.employmentStatus,
    this.dataSyncedAt,
    this.requestId,
    this.statusCode,
  });

  /// `data.length`.
  final int? itemCount;

  /// `gusto`, `rippling`, `paychex_flex_api`, `adp_workforce_now`,
  /// `workday`, etc. Slice cost + reliability by upstream provider.
  final String? providerId;

  /// `assisted` (Finch-assisted, expensive) vs `automated` vs
  /// `credential` (depending on connection mode).
  final String? authMethod;

  /// `connected` / `reauth_required` / `disconnected` / `pending`.
  final String? connectionStatus;

  /// `hris` / `payroll` / `directory` / `benefits` — products are
  /// licensed independently.
  final String? productCategory;

  /// Individuals batch size for `/employer/individual` and
  /// `/employer/employment` (Finch bills per individual fetched).
  final int? batchSize;

  /// `active` / `terminated` / `pending` from individual records.
  final String? employmentStatus;

  /// `data_synced_at` for staleness detection.
  final String? dataSyncedAt;

  /// `X-Finch-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class FinchCallResult<T> {
  const FinchCallResult({required this.value, this.result});
  final T value;
  final FinchResult? result;
}

/// Wraps a Finch API call in a CLIENT span. [operation] is one of
/// `introspect`, `company`, `directory`, `individual`, `employment`,
/// `payment`, `pay_statement`, `benefits.create`, `benefits.list`,
/// `benefits.enroll`, `webhooks.create`, `data_sync_all`,
/// `disconnect`.
Future<T> tracedFinch<T>({
  required String operation,
  required Future<FinchCallResult<T>> Function() invoke,
  String? productCategory,
}) async {
  if (finchInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'finch',
    'rpc.method': operation,
    'finch.operation': operation,
  };
  if (productCategory != null) m['finch.product'] = productCategory;

  final span = _tracer().startSpan(
    'finch $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'finch.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.providerId != null) {
        extras.add(OTel.attributeString(
          'finch.provider.id',
          r.result!.providerId!,
        ));
      }
      if (r.result!.authMethod != null) {
        extras.add(OTel.attributeString(
          'finch.auth.method',
          r.result!.authMethod!,
        ));
      }
      if (r.result!.connectionStatus != null) {
        extras.add(OTel.attributeString(
          'finch.connection.status',
          r.result!.connectionStatus!,
        ));
        if (r.result!.connectionStatus == 'reauth_required' ||
            r.result!.connectionStatus == 'disconnected') {
          span.setStatus(
            SpanStatusCode.Error,
            'Finch connection ${r.result!.connectionStatus}',
          );
        }
      }
      if (r.result!.productCategory != null) {
        extras.add(OTel.attributeString(
          'finch.product',
          r.result!.productCategory!,
        ));
      }
      if (r.result!.batchSize != null) {
        extras.add(OTel.attributeInt(
          'finch.batch_size',
          r.result!.batchSize!,
        ));
      }
      if (r.result!.employmentStatus != null) {
        extras.add(OTel.attributeString(
          'finch.employment.status',
          r.result!.employmentStatus!,
        ));
      }
      if (r.result!.dataSyncedAt != null) {
        extras.add(OTel.attributeString(
          'finch.data_synced_at',
          r.result!.dataSyncedAt!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'finch.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Finch HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
