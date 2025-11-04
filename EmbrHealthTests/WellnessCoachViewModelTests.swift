import XCTest
@testable import EmbrHealth

@MainActor
final class WellnessCoachViewModelTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testSendAppendsNetworkResponseToMessages() async throws {
        let expectedReply = "Great job pushing toward your goals!"
        let expectedKey = "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"
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

        let requestExpectation = expectation(description: "Request executed")

        MockURLProtocol.requestHandler = { request in
            requestExpectation.fulfill()
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(expectedKey)")
            let url = request.url ?? URL(string: "https://api.openai.com/v1/responses")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, responseData)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        var service = WellnessAIService()
        service.apiKeyProvider = { expectedKey }
        service.urlSession = session

        let viewModel = WellnessCoachViewModel(aiService: service)
        XCTAssertEqual(viewModel.messages.count, 1)

        await viewModel.send("How am I progressing?", metrics: [], goals: [], workouts: [])

        wait(for: [requestExpectation], timeout: 1.0)

        XCTAssertEqual(viewModel.messages.count, 3)
        XCTAssertEqual(viewModel.messages.last?.sender, .coach)
        XCTAssertEqual(viewModel.messages.last?.text, expectedReply)
    }
}
