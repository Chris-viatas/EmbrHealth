import Foundation
import XCTest
@testable import EmbrHealth

final class WellnessAIServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testRespondIncludesConversationHistoryAndParsesOutput() async throws {
        let expectedReply = "Great job staying active!"
        let responseJSON: [String: Any] = [
            "output": [
                [
                    "content": [
                        ["type": "output_text", "text": expectedReply]
                    ]
                ]
            ],
            "output_text": [expectedReply]
        ]
        let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let url = request.url ?? URL(string: "https://api.openai.com/v1/responses")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, responseData)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        var service = WellnessAIService()
        service.apiKeyProvider = { "test-key" }
        service.urlSession = session

        let snapshot = WellnessSnapshot(
            observationWindowDays: 7,
            averageSteps: 9200,
            averageActiveEnergy: 550,
            averageExerciseMinutes: 38,
            averageRestingHeartRate: 58,
            averageMaxHeartRate: 170,
            averageSleepHours: 7.1,
            averageSleepEfficiency: 0.92,
            averageVo2Max: 42.5,
            goalStatuses: [
                .init(category: .steps, completionRatio: 0.9, target: 10000)
            ],
            workouts: .init(totalDuration: 3600, count: 4, calorieBurn: 2200, predominantTypes: ["Run"])
        )

        let history: [WellnessChatMessage] = [
            WellnessChatMessage(sender: .user, text: "Hi coach, I walked 5k steps"),
            WellnessChatMessage(sender: .coach, text: "Nice work staying consistent!")
        ]

        let reply = try await service.respond(to: "Any tips to improve my stamina?", history: history, snapshot: snapshot)
        XCTAssertEqual(reply, expectedReply)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let input = try XCTUnwrap(json?["input"] as? [[String: Any]])

        XCTAssertEqual(input.count, 5)
        XCTAssertEqual(input.first?["role"] as? String, "system")

        let historyUser = input[2]
        XCTAssertEqual(historyUser["role"] as? String, "user")
        let historyUserContent = try XCTUnwrap(historyUser["content"] as? [[String: Any]])
        XCTAssertTrue(historyUserContent.contains { ($0["text"] as? String)?.contains("walked 5k steps") == true })

        let historyCoach = input[3]
        XCTAssertEqual(historyCoach["role"] as? String, "assistant")
        let historyCoachContent = try XCTUnwrap(historyCoach["content"] as? [[String: Any]])
        XCTAssertTrue(historyCoachContent.contains { ($0["text"] as? String)?.contains("Nice work staying consistent") == true })

        let latestUser = input.last
        XCTAssertEqual(latestUser?["role"] as? String, "user")
        let latestUserContent = try XCTUnwrap(latestUser?["content"] as? [[String: Any]])
        XCTAssertTrue(latestUserContent.contains { ($0["text"] as? String)?.contains("improve my stamina") == true })
    }

    func testRespondFallsBackWhenApiKeyUnavailable() async throws {
        let expectation = XCTestExpectation(description: "No network call should be made")
        expectation.isInverted = true
        MockURLProtocol.requestHandler = { _ in
            expectation.fulfill()
            let url = URL(string: "https://api.openai.com/v1/responses")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        var service = WellnessAIService()
        service.apiKeyProvider = { nil }
        service.urlSession = session

        let snapshot = WellnessSnapshot(
            observationWindowDays: 7,
            averageSteps: 8000,
            averageActiveEnergy: 400,
            averageExerciseMinutes: 30,
            averageRestingHeartRate: 60,
            averageMaxHeartRate: 170,
            averageSleepHours: 7.5,
            averageSleepEfficiency: 0.9,
            averageVo2Max: 40,
            goalStatuses: [],
            workouts: .init(totalDuration: 0, count: 0, calorieBurn: 0, predominantTypes: [])
        )

        let response = try await service.respond(to: "How am I doing?", history: [], snapshot: snapshot)
        XCTAssertTrue(response.hasPrefix("Here's a local summary while the network is offline"))
        wait(for: [expectation], timeout: 0.1)
    }

    func testDefaultApiKeyProviderReadsEnvironmentVariable() {
        let key = "OPENAI_API_KEY"
        let originalValue = getenv(key).flatMap { String(cString: $0) }
        setenv(key, "env-key", 1)

        var service = WellnessAIService()
        defer {
            if let originalValue {
                setenv(key, originalValue, 1)
            } else {
                unsetenv(key)
            }
        }

        XCTAssertEqual(service.apiKeyProvider(), "env-key")
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
