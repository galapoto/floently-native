import Foundation

public struct FloentlyUser: Codable, Equatable, Identifiable {
    public let id: String
    public let email: String
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case email
        case name
        case displayName = "display_name"
        case fullName = "full_name"
    }

    public init(id: String, email: String, name: String?) {
        self.id = id
        self.email = email
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .userId)
            ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
            ?? c.decodeIfPresent(String.self, forKey: .displayName)
            ?? c.decodeIfPresent(String.self, forKey: .fullName)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(email, forKey: .email)
        try c.encodeIfPresent(name, forKey: .name)
    }
}

public struct FloentlyTokenPair: Codable, Equatable {
    public let accessToken: String?
    public let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

public struct FloentlyAuthSession: Codable, Equatable {
    public let user: FloentlyUser
    public let token: String
    public let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case user
        case authUser = "auth_user"
        case token
        case refreshToken = "refresh_token"
        case tokens
    }

    public init(user: FloentlyUser, token: String, refreshToken: String? = nil) {
        self.user = user
        self.token = token
        self.refreshToken = refreshToken
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decodeIfPresent(FloentlyUser.self, forKey: .user)
            ?? c.decodeIfPresent(FloentlyUser.self, forKey: .authUser)
            ?? FloentlyUser(id: "", email: "", name: nil)

        let tokens = try c.decodeIfPresent(FloentlyTokenPair.self, forKey: .tokens)

        token = try c.decodeIfPresent(String.self, forKey: .token)
            ?? tokens?.accessToken
            ?? ""

        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken)
            ?? tokens?.refreshToken
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user, forKey: .user)
        try c.encode(token, forKey: .token)
        try c.encodeIfPresent(refreshToken, forKey: .refreshToken)
    }
}

public struct PasswordLoginRequest: Encodable {
    public let email: String
    public let password: String
}

public struct PasswordRegisterRequest: Encodable {
    public let email: String
    public let password: String
    public let name: String?
    public let captchaToken: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case name
        case captchaToken = "captcha_token"
    }
}

public struct PasswordResetRequest: Encodable {
    public let email: String
}

public struct PasswordResetConfirmRequest: Encodable {
    public let token: String
    public let password: String
}

public struct GoogleAuthRequest: Encodable {
    public let idToken: String?
    public let credential: String?
    public let oauthResultId: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case credential
        case oauthResultId = "oauth_result_id"
    }
}

public struct LogoutRequest: Encodable {
    public let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
