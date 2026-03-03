//
//  TracingService.swift
//  SenseFlow
//
//  Created on 2026-01-27.
//  OpenTelemetry tracing integration with Langfuse
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

// MARK: - Custom HTTP Client for Authentication

/// Custom HTTP client that adds authentication headers to requests
private class CustomHeadersHTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let customHeaders: [String: String]

    init(baseClient: HTTPClient = BaseHTTPClient(), customHeaders: [String: String]) {
        self.baseClient = baseClient
        self.customHeaders = customHeaders
    }

    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        var modifiedRequest = request

        // Add custom headers
        for (key, value) in customHeaders {
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }

        print("🌐 [Tracing] Sending HTTP request to: \(modifiedRequest.url?.absoluteString ?? "unknown")")

        baseClient.send(request: modifiedRequest) { result in
            switch result {
            case .success(let response):
                print("✅ [Tracing] HTTP response: \(response.statusCode)")
                if response.statusCode >= 400 {
                    print("❌ [Tracing] HTTP error: Status \(response.statusCode)")
                }
                completion(result)
            case .failure(let error):
                print("❌ [Tracing] HTTP request failed: \(error.localizedDescription)")
                completion(result)
            }
        }
    }
}

// MARK: - Tracing Service

/// Tracing service for Langfuse integration via OpenTelemetry
class TracingService {

    // MARK: - Singleton

    static let shared = TracingService()

    // MARK: - Properties

    private var tracerProvider: TracerProviderSdk?
    private var tracer: Tracer?

    /// Whether tracing is enabled
    private(set) var isEnabled: Bool = false

    // MARK: - Configuration

    private struct Config {
        static let serviceName = "ai-clipboard"
        static let langfuseEndpoint = "https://cloud.langfuse.com/api/public/otel/v1/traces"
        // Keys: 环境变量 → UserDefaults
        static var publicKey: String? {
            ProcessInfo.processInfo.environment["LANGFUSE_PUBLIC_KEY"]
                ?? UserDefaults.standard.string(forKey: "langfusePublicKey")
        }
        static var secretKey: String? {
            ProcessInfo.processInfo.environment["LANGFUSE_SECRET_KEY"]
                ?? UserDefaults.standard.string(forKey: "langfuseSecretKey")
        }
    }

    // MARK: - Initialization

    private init() {
        setupTracing()
    }

    // MARK: - Setup

    private func setupTracing() {
        guard let publicKey = Config.publicKey,
              let secretKey = Config.secretKey,
              !publicKey.isEmpty,
              !secretKey.isEmpty else {
            print("⚠️ Langfuse tracing disabled: API keys not configured")
            print("   Set LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY environment variables")
            return
        }

        // Create Basic Auth header
        let credentials = "\(publicKey):\(secretKey)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            print("❌ Failed to encode Langfuse credentials")
            return
        }
        let base64Credentials = credentialsData.base64EncodedString()
        let authHeader = "Basic \(base64Credentials)"

        // Configure OTLP HTTP exporter with custom headers
        let customClient = CustomHeadersHTTPClient(
            customHeaders: ["Authorization": authHeader]
        )

        let exporter = OtlpHttpTraceExporter(
            endpoint: URL(string: Config.langfuseEndpoint)!,
            httpClient: customClient
        )

        // Create tracer provider
        let resource = Resource(attributes: [
            "service.name": AttributeValue.string(Config.serviceName),
            "deployment.environment": AttributeValue.string(getEnvironment())
        ])

            tracerProvider = TracerProviderBuilder()
                .add(spanProcessor: SimpleSpanProcessor(spanExporter: exporter))
                .with(resource: resource)
                .build()

            // Get tracer
            tracer = tracerProvider?.get(instrumentationName: Config.serviceName)

            isEnabled = true
            print("✅ Langfuse tracing initialized successfully")
    }

    // MARK: - Public Methods

    /// Start a new span
    /// - Parameters:
    ///   - name: Name of the span
    ///   - kind: Span kind (default: internal)
    ///   - attributes: Initial attributes
    /// - Returns: Started span, or nil if tracing is disabled
    func startSpan(
        name: String,
        kind: SpanKind = .internal,
        attributes: [String: AttributeValue] = [:]
    ) -> Span? {
        guard isEnabled, let tracer = tracer else {
            print("⚠️ [Tracing] Span '\(name)' not created - tracing disabled")
            return nil
        }

        let builder = tracer.spanBuilder(spanName: name)
            .setSpanKind(spanKind: kind)

        // Add attributes
        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        let span = builder.startSpan()
        print("🔍 [Tracing] Span started: '\(name)'")
        return span
    }

    /// Start a span as a child of the current active span
    /// - Parameters:
    ///   - name: Name of the span
    ///   - kind: Span kind
    ///   - attributes: Initial attributes
    /// - Returns: Started span, or nil if tracing is disabled
    func startChildSpan(
        name: String,
        kind: SpanKind = .internal,
        attributes: [String: AttributeValue] = [:]
    ) -> Span? {
        guard isEnabled, let tracer = tracer else { return nil }

        let builder = tracer.spanBuilder(spanName: name)
            .setSpanKind(spanKind: kind)

        // Add attributes
        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        return builder.startSpan()
    }

    /// Execute a block of code within a span
    /// - Parameters:
    ///   - name: Name of the span
    ///   - kind: Span kind
    ///   - attributes: Initial attributes
    ///   - block: Code to execute
    /// - Returns: Result of the block
    func withSpan<T>(
        name: String,
        kind: SpanKind = .internal,
        attributes: [String: AttributeValue] = [:],
        _ block: (Span?) -> T
    ) -> T {
        let span = startSpan(name: name, kind: kind, attributes: attributes)
        defer { span?.end() }
        return block(span)
    }

    /// Execute an async block of code within a span
    /// - Parameters:
    ///   - name: Name of the span
    ///   - kind: Span kind
    ///   - attributes: Initial attributes
    ///   - block: Async code to execute
    /// - Returns: Result of the block
    func withSpan<T>(
        name: String,
        kind: SpanKind = .internal,
        attributes: [String: AttributeValue] = [:],
        _ block: (Span?) async throws -> T
    ) async rethrows -> T {
        let span = startSpan(name: name, kind: kind, attributes: attributes)
        defer {
            span?.end()
            print("🔍 [Tracing] Span ended: '\(name)'")
        }
        return try await block(span)
    }

    /// Flush all pending spans
    func flush() {
        print("🔍 [Tracing] Flushing pending spans...")
        tracerProvider?.forceFlush()
        print("🔍 [Tracing] Flush completed")
    }

    /// Shutdown tracing
    func shutdown() {
        tracerProvider?.shutdown()
    }

    // MARK: - Helper Methods

    private func getEnvironment() -> String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}
