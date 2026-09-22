import XCTest
@testable import Plannit

// Sign-up, sign-in, codes and password reset, at the two places they can go
// wrong without a server to try them against: the request we send, and how the
// app reads what comes back.

@MainActor
final class AuthTests: XCTestCase {
    private var client: SupabaseClient!

    private let sessionJSON = """
    {"access_token": "new-token", "token_type": "bearer", "expires_in": 3600,
     "refresh_token": "refresh", "user": {"id": "u1", "email": "sam@example.com"}}
    """

    override func setUp() async throws {
        StubTransport.reset()
        client = SupabaseClient(session: StubTransport.session(),
                                url: "https://stub.supabase.co", anonKey: "anon-key")
    }

    override func tearDown() async throws {
        StubTransport.reset()
    }

    // MARK: - Codes

    func testASignUpCodeIsVerifiedAsAnEmailOTP() async throws {
        StubTransport.on("/auth/v1/verify", body: sessionJSON)
        let uid = try await client.verifyCode("123456", email: "sam@example.com", purpose: .signUp)

        XCTAssertEqual(uid, "u1")
        XCTAssertEqual(client.accessToken, "new-token", "a confirmed code is a signed-in session")
        let body = try XCTUnwrap(StubTransport.sent(to: "/auth/v1/verify"))
        XCTAssertTrue(body.contains("\"type\":\"email\""),
                      "`email` is what matches a sign-up's confirmation token: \(body)")
        XCTAssertTrue(body.contains("\"token\":\"123456\""), body)
        XCTAssertTrue(body.contains("\"email\":\"sam@example.com\""), body)
    }

    func testAResetCodeIsVerifiedAsRecovery() async throws {
        StubTransport.on("/auth/v1/verify", body: sessionJSON)
        try await client.verifyCode("654321", email: "sam@example.com", purpose: .passwordReset)

        let body = try XCTUnwrap(StubTransport.sent(to: "/auth/v1/verify"))
        XCTAssertTrue(body.contains("\"type\":\"recovery\""), body)
    }

    func testResendAsksForASignUpCode() async throws {
        StubTransport.on("/auth/v1/resend", body: "{}")
        try await client.resendSignUpCode(email: "sam@example.com")

        let body = try XCTUnwrap(StubTransport.sent(to: "/auth/v1/resend"))
        XCTAssertTrue(body.contains("\"type\":\"signup\""), body)
    }

    func testAResetGoesToRecoverWithOnlyTheEmail() async throws {
        StubTransport.on("/auth/v1/recover", body: "{}")
        try await client.sendPasswordReset(email: "sam@example.com")

        let body = try XCTUnwrap(StubTransport.sent(to: "/auth/v1/recover"))
        XCTAssertEqual(body, "{\"email\":\"sam@example.com\"}")
    }

    func testANewPasswordIsAnAuthorisedPut() async throws {
        client.useSession(accessToken: "recovery-token", userId: "u1")
        StubTransport.on("/auth/v1/user", body: "{\"id\": \"u1\"}")
        try await client.updatePassword("correct horse")

        let request = try XCTUnwrap(StubTransport.requests(containing: "/auth/v1/user").first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer recovery-token",
                       "the session from the reset code is what authorises the change")
        XCTAssertEqual(StubTransport.sent(to: "/auth/v1/user"), "{\"password\":\"correct horse\"}")
    }

    // MARK: - Google (PKCE)

    func testTheChallengeMatchesTheRFCExample() {
        // RFC 7636, appendix B.
        XCTAssertEqual(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testAVerifierIsURLSafeAndLongEnough() {
        let verifier = PKCE.makeVerifier()
        XCTAssertGreaterThanOrEqual(verifier.count, 43)
        XCTAssertNil(verifier.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
        XCTAssertNotEqual(verifier, PKCE.makeVerifier())
    }

    func testTheAuthorizeURLCarriesTheChallengeNotTheVerifier() throws {
        let url = try XCTUnwrap(client.authorizeURL(provider: "google",
                                                    redirectTo: WebSignIn.redirectURL,
                                                    codeChallenge: "challenge-value"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertTrue(url.path.hasSuffix("/auth/v1/authorize"), url.absoluteString)
        XCTAssertEqual(query["provider"], "google")
        XCTAssertEqual(query["redirect_to"], "plannit://auth-callback")
        XCTAssertEqual(query["code_challenge"], "challenge-value")
        XCTAssertEqual(query["code_challenge_method"], "s256")
    }

    func testTheCodeIsExchangedWithTheVerifier() async throws {
        StubTransport.on("grant_type=pkce", body: sessionJSON)
        try await client.exchangeAuthCode("auth-code", verifier: "the-verifier")

        let body = try XCTUnwrap(StubTransport.sent(to: "grant_type=pkce"))
        XCTAssertTrue(body.contains("\"auth_code\":\"auth-code\""), body)
        XCTAssertTrue(body.contains("\"code_verifier\":\"the-verifier\""), body)
        XCTAssertEqual(client.userId, "u1")
    }

    func testTheRedirectCodeIsReadFromQueryOrFragment() throws {
        let query = try XCTUnwrap(URL(string: "plannit://auth-callback?code=abc"))
        let fragment = try XCTUnwrap(URL(string:
            "plannit://auth-callback#error=access_denied&error_description=Nope"))

        XCTAssertEqual(WebSignIn.value("code", in: query), "abc")
        XCTAssertNil(WebSignIn.value("code", in: fragment))
        XCTAssertEqual(WebSignIn.value("error_description", in: fragment), "Nope")
    }

    // MARK: - Passwords

    func testANewPasswordNeedsLengthAndAMatchingConfirmation() {
        XCTAssertNotNil(PasswordRules.problem("abc", confirm: "abc"), "too short")
        XCTAssertNotNil(PasswordRules.problem("abcdefg", confirm: "abcdefg"),
                        "one short of the minimum")
        XCTAssertEqual(PasswordRules.problem("abcdefgh", confirm: "abcdefgi"),
                       "The passwords don't match.")
        XCTAssertNil(PasswordRules.problem("abcdefgh", confirm: "abcdefgh"))
    }

    func testAMismatchIsOnlyShownOnceTheConfirmationIsTyped() {
        XCTAssertFalse(PasswordRules.showMismatch("secret1", confirm: ""))
        XCTAssertFalse(PasswordRules.showMismatch("secret1", confirm: "sec"),
                       "half-way through typing isn't a mistake yet")
        XCTAssertTrue(PasswordRules.showMismatch("secret1", confirm: "secret2"))
        XCTAssertFalse(PasswordRules.showMismatch("secret1", confirm: "secret1"))
    }

    // MARK: - Reading the server's answers

    func testAnUnconfirmedAccountIsRecognised() {
        let body = #"{"code":400,"error_code":"email_not_confirmed","msg":"Email not confirmed"}"#
        XCTAssertTrue(AppModel.isUnconfirmed(body))
        XCTAssertFalse(AppModel.isUnconfirmed(
            #"{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#))
    }

    func testEmailsAndCodesAreCleanedBeforeSending() {
        XCTAssertEqual(AppModel.clean("  Sam@Example.com \n"), "sam@example.com")
        XCTAssertEqual(AppModel.digits("123 456"), "123456",
                       "a code pasted from the email often carries a space")
    }

    func testSignUpFailuresSayWhatToDo() {
        XCTAssertEqual(AppModel.signUpMessage(status: 422, body: #"{"msg":"User already registered"}"#),
                       "That email already has an account. Sign in instead.")
        XCTAssertEqual(AppModel.signUpMessage(status: 429, body: ""),
                       "Too many sign-ups from here. Wait a minute and try again.")
    }
}
