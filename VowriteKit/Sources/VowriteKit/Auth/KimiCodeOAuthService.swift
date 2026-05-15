// VowriteKit/Sources/VowriteKit/Auth/KimiCodeOAuthService.swift
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Kimi Code OAuth Error

public enum KimiCodeOAuthError: LocalizedError {
    case deviceAuthFailed(String)
    case pollingTimedOut
    case pollingFailed(String)
    case tokenSaveFailed

    public var errorDescription: String? {
        switch self {
        case .deviceAuthFailed(let msg):  return "获取 Kimi 授权码失败: \(msg)"
        case .pollingTimedOut:            return "Kimi Code 登录超时，请重试"
        case .pollingFailed(let msg):     return "Kimi Code 登录失败: \(msg)"
        case .tokenSaveFailed:            return "Token 保存失败"
        }
    }
}

// MARK: - Device Authorization Response

struct KimiDeviceAuthResponse: Codable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int
}

// MARK: - KimiCodeOAuthService

public enum KimiCodeOAuthService {

    private static let clientID            = "17e5f671-d194-4dfb-9706-5516cb48c098"
    private static let deviceAuthEndpoint  = "https://auth.kimi.com/api/oauth/device_authorization"
    private static let tokenEndpoint       = "https://auth.kimi.com/api/oauth/token"
    private static let grantType           = "urn:ietf:params:oauth:grant-type:device_code"
    static let kimiCodeBaseURL             = "https://api.kimi.com/coding/v1"

    // nonisolated(unsafe) because KimiCodeOAuthService is an enum (no actor isolation).
    // All reads and writes are protected by pollingTaskLock to prevent data races.
    private nonisolated(unsafe) static var pollingTask: Task<OAuthToken, Error>?
    private nonisolated(unsafe) static let pollingTaskLock = NSLock()

    public static func cancelSignIn() {
        pollingTaskLock.withLock {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    public static func signIn(onDeviceCode: @escaping (String, String) -> Void) async throws -> OAuthToken {
        let deviceResponse = try await requestDeviceCode()
        onDeviceCode(deviceResponse.user_code, deviceResponse.verification_uri)
        openBrowser(url: deviceResponse.verification_uri)
        let task = Task<OAuthToken, Error> {
            try await pollForToken(deviceCode: deviceResponse.device_code,
                                   interval: deviceResponse.interval,
                                   expiresIn: deviceResponse.expires_in)
        }
        pollingTaskLock.withLock { pollingTask = task }
        let token = try await task.value
        pollingTaskLock.withLock { pollingTask = nil }
        return token
    }

    private static func requestDeviceCode() async throws -> KimiDeviceAuthResponse {
        guard let url = URL(string: deviceAuthEndpoint) else {
            throw KimiCodeOAuthError.deviceAuthFailed("Invalid endpoint URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        applyKimiHeaders(to: &request)
        request.httpBody = formEncode(["client_id": clientID])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw KimiCodeOAuthError.deviceAuthFailed("HTTP error: \(body)")
        }
        return try JSONDecoder().decode(KimiDeviceAuthResponse.self, from: data)
    }

    private static func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> OAuthToken {
        let deadline = Date().addingTimeInterval(Double(expiresIn))
        var pollInterval = max(interval, 5)
        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            try Task.checkCancellation()
            guard let url = URL(string: tokenEndpoint) else {
                throw KimiCodeOAuthError.pollingFailed("Invalid token endpoint")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            applyKimiHeaders(to: &request)
            request.httpBody = formEncode([
                "grant_type":  grantType,
                "device_code": deviceCode,
                "client_id":   clientID,
            ])
            guard let (data, _) = try? await URLSession.shared.data(for: request) else { continue }
            struct ErrorResponse: Codable { let error: String? }
            if let errResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               let error = errResponse.error {
                switch error {
                case "authorization_pending": continue
                case "slow_down": pollInterval += 5; continue
                case "expired_token": throw KimiCodeOAuthError.pollingTimedOut
                default: throw KimiCodeOAuthError.pollingFailed(error)
                }
            }
            struct TokenResponse: Codable {
                let access_token: String
                let refresh_token: String?
                let expires_in: Int?
                let email: String?
            }
            if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data),
               !tokenResponse.access_token.isEmpty {
                let expiresAt = tokenResponse.expires_in.map { Date().addingTimeInterval(Double($0)) }
                let token = OAuthToken(
                    accessToken: tokenResponse.access_token,
                    refreshToken: tokenResponse.refresh_token,
                    expiresAt: expiresAt,
                    email: tokenResponse.email,
                    baseURL: kimiCodeBaseURL
                )
                OAuthTokenStore.save(token, for: "kimi")
                return token
            }
        }
        throw KimiCodeOAuthError.pollingTimedOut
    }

    public static func refresh(refreshToken: String) async {
        guard let url = URL(string: tokenEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        applyKimiHeaders(to: &request)
        request.httpBody = formEncode([
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
            "client_id":     clientID,
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
        }
        guard let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data),
              !tokenResponse.access_token.isEmpty else {
            OAuthTokenStore.delete(for: "kimi")
            return
        }
        let expiresAt = tokenResponse.expires_in.map { Date().addingTimeInterval(Double($0)) }
        let stored = OAuthTokenStore.load(for: "kimi")
        let newToken = OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? refreshToken,
            expiresAt: expiresAt,
            email: stored?.email,
            baseURL: kimiCodeBaseURL
        )
        OAuthTokenStore.save(newToken, for: "kimi")
    }

    public static func signOut() {
        cancelSignIn()
        OAuthTokenStore.delete(for: "kimi")
        VowriteStorage.defaults.removeObject(forKey: "auth.method.kimi")
    }

    private static func formEncode(_ params: [String: String]) -> Data? {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "+&=")
        return params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: cs) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: cs) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&").data(using: .utf8)
    }

    private static func applyKimiHeaders(to request: inout URLRequest) {
        request.setValue("desktop",          forHTTPHeaderField: "X-Msh-Platform")
        request.setValue("0.0.1",            forHTTPHeaderField: "X-Msh-Version")
        request.setValue(deviceID(),         forHTTPHeaderField: "X-Msh-Device-Id")
        request.setValue(deviceName(),       forHTTPHeaderField: "X-Msh-Device-Name")
        request.setValue(deviceModel(),      forHTTPHeaderField: "X-Msh-Device-Model")
        request.setValue(osVersion(),        forHTTPHeaderField: "X-Msh-Os-Version")
    }

    /// Headers required by the Kimi Code Coding Plan endpoint
    /// (`api.kimi.com/coding/v1`). Without a coding-agent User-Agent and the
    /// X-Msh-* device metadata, the server returns 403.
    public static func applyCodingPlanHeaders(to request: inout URLRequest) {
        request.setValue("kimi-cli/0.0.1",   forHTTPHeaderField: "User-Agent")
        applyKimiHeaders(to: &request)
    }

    private static func deviceID() -> String {
        let key = "kimi.device_id"
        if let existing = VowriteStorage.defaults.string(forKey: key) { return existing }
        let newID = UUID().uuidString
        VowriteStorage.defaults.set(newID, forKey: key)
        return newID
    }

    private static func deviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }

    private static func deviceModel() -> String {
        #if os(macOS)
        return "Mac"
        #else
        return UIDevice.current.model
        #endif
    }

    private static func osVersion() -> String {
        #if os(macOS)
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #else
        return "iOS \(UIDevice.current.systemVersion)"
        #endif
    }

    private static func openBrowser(url: String) {
        guard let url = URL(string: url) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        Task { @MainActor in UIApplication.shared.open(url) }
        #endif
    }
}
