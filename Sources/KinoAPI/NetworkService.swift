import Foundation

public protocol NetworkService {
    func data(_ request: URLRequest) async throws -> (Data, URLResponse)
    
    func object<T: Decodable>(for request: URLRequest, decoder: JSONDecoder) async throws -> T
    func object<T: Decodable>(for request: URLRequest) async throws -> T
}

public class DefaultNetworkService: NetworkService {
    
    let session: URLSession
    
    public init(session: URLSession) {
        self.session = session
    }
    
    public func data(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                switch (data, response, error) {
                case let (data?, response?, _):
                    continuation.resume(returning: (data, response))
                case let (_, _, error?):
                    continuation.resume(throwing: error)
                default:
                    let error = NSError(domain: "com.kinopub.network", code: NSURLErrorBadServerResponse, userInfo: nil)
                    continuation.resume(throwing: error)
                }
            }.resume()
        }
    }
    
    public func object<T: Decodable>(for request: URLRequest) async throws -> T {
        return try await object(for: request, decoder: JSONDecoder())
    }
    
    public func object<T: Decodable>(for request: URLRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let (data, _) = try await data(request)
        
        return try decoder.decode(T.self, from: data)
    }
}

extension URLRequest {
    init(url: URL, httpMethod: String) {
        self.init(url: url)
        self.httpMethod = httpMethod
    }
}

extension URL {
    init?(path: String, baseURL: URL, queryItems: [String: String?]) {
        guard let url = URL(string: path, relativeTo: baseURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else {
            return nil
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems.map({ URLQueryItem(name: $0.key, value: $0.value) })
        }
        
        guard let fullURL = components.url else {
            return nil
        }
        
        self = fullURL
    }
}
