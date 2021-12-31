import Foundation

public class AuthorizationService {
    enum AuthorizationError: Error {
        case brokenURL
    }
    
    let kodiSecret = "cgg3gtifu46urtfp2zp1nqtba0k2ezxh"
    public struct DeviceCodeResponse: Codable {
        public let code: String
        public let userCode: String
        public let interval: Int
        public let expiresIn: TimeInterval
        public let timestamp: Date = .now
        
        private enum CodingKeys: CodingKey {
            case code, userCode, interval, expiresIn
        }
    }
    
    let baseURL = URL(string: "https://api.service-kp.com")!
    
    public let networkService: NetworkService
    public let clientId: String
    public let clientSecret: String
    
    let jsonDecoder: JSONDecoder
    
    public init(networkService: NetworkService = DefaultNetworkService(session: .shared), clientId: String, clientSecret: String) {
        self.networkService = networkService
        self.clientId = clientId
        self.clientSecret = clientSecret
        
        jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    public func getDeviceCode() async throws -> DeviceCodeResponse {
        let queryItems = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "device_code"
        ]
        guard let url = URL(path: "/oauth2/device", baseURL: baseURL, queryItems: queryItems) else {
            throw AuthorizationError.brokenURL
        }
        let request = URLRequest(url: url, httpMethod: "POST")
        
        return try await networkService.object(for: request, decoder: jsonDecoder)
    }
    
    public struct AccessTokenResponse: Codable {
        let accessToken: String
        let expiresIn: TimeInterval
        let refreshToken: String
    }
    
    enum AccessTokenError: Error {
        case authorizationPending
        case cannotReceiveAccessToken
    }
    
    public func accessToken(codeRequest: DeviceCodeResponse) async throws -> AccessTokenResponse {
        let queryItems = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "device_token",
            "code": codeRequest.code
        ]
        guard let url = URL(path: "/oauth2/device", baseURL: baseURL, queryItems: queryItems) else {
            throw AuthorizationError.brokenURL
        }
        let request = URLRequest(url: url, httpMethod: "POST")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw AccessTokenError.authorizationPending
        }
        
        return try jsonDecoder.decode(AccessTokenResponse.self, from: data)
    }
    
    public func waitAccessToken(codeRequest: DeviceCodeResponse) async throws -> AccessTokenResponse {
        let expirationDeadline = Date(timeInterval: codeRequest.expiresIn, since: codeRequest.timestamp)
        repeat {
            do {
                return try await accessToken(codeRequest: codeRequest)
            } catch AccessTokenError.authorizationPending {
                try await Task.sleep(nanoseconds: UInt64(codeRequest.interval * 1_000_000_000))
            } catch {
                throw error
            }
        } while .now < expirationDeadline
        
        throw AccessTokenError.cannotReceiveAccessToken
    }
}
