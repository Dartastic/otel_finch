// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_finch/otel_finch.dart';

/// Traces Finch calls with OpenTelemetry.
///
/// `otel_finch` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Finch call in
/// [tracedFinch]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'finch-example');

  // Wraps a Finch API call in a CLIENT span.
  final finchId = await tracedFinch<String>(
    operation: 'benefits.create',
    productCategory: 'example',
    invoke: () async {
      // Make the Finch call here, then report what it returned.
      const id = 'finch_8f3a2c';
      return const FinchCallResult(
          value: id,
          result: FinchResult(
              itemCount: 3,
              providerId: 'gusto',
              authMethod: 'assisted',
              connectionStatus: 'connected',
              productCategory: 'hris',
              batchSize: 512,
              employmentStatus: 'active',
              dataSyncedAt: 'data_synced_at',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedFinch benefits.create returned $finchId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutFinchInstrumentationAsync.
  await runWithoutFinchInstrumentationAsync(
    () => tracedFinch<String>(
      operation: 'benefits.create',
      productCategory: 'example',
      invoke: () async {
        const id = 'finch_8f3a2c';
        return const FinchCallResult(
            value: id,
            result: FinchResult(
                itemCount: 3,
                providerId: 'gusto',
                authMethod: 'assisted',
                connectionStatus: 'connected',
                productCategory: 'hris',
                batchSize: 512,
                employmentStatus: 'active',
                dataSyncedAt: 'data_synced_at',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
