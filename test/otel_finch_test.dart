// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_finch/otel_finch.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_finch-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('individual records provider + auth_method + batch', () async {
    await tracedFinch<String>(
      operation: 'individual',
      productCategory: 'hris',
      invoke: () async => const FinchCallResult(
        value: 'ok',
        result: FinchResult(
          itemCount: 50,
          providerId: 'gusto',
          authMethod: 'automated',
          connectionStatus: 'connected',
          productCategory: 'hris',
          batchSize: 50,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('finch individual')!);
    expect(a['finch.provider.id'], 'gusto');
    expect(a['finch.auth.method'], 'automated');
    expect(a['finch.product'], 'hris');
    expect(a['finch.batch_size'], 50);
  });

  test('reauth_required sets span error', () async {
    await tracedFinch<String>(
      operation: 'directory',
      invoke: () async => const FinchCallResult(
        value: 'ok',
        result: FinchResult(connectionStatus: 'reauth_required'),
      ),
    );
    expect(
      spans.findSpanByName('finch directory')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutFinchInstrumentationAsync(() async {
      await tracedFinch<String>(
        operation: 'company',
        invoke: () async => const FinchCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('finch '), isEmpty);
  });
}
