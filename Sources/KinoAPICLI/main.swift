import Foundation
import KinoAPI

let kodiClientID = "xbmc"
let kodiSecret = "cgg3gtifu46urtfp2zp1nqtba0k2ezxh"

let authService = AuthorizationService(clientId: kodiClientID, clientSecret: kodiSecret)

let task = Task {
    do {
        let code = try await authService.getDeviceCode()
        print(code.userCode)
        
        let token = try await authService.waitAccessToken(codeRequest: code)
        print(token)
        
        exit(0)
    } catch {
        print(error)
    }
}

RunLoop.main.run()
