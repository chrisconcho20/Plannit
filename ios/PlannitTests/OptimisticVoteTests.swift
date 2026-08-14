import XCTest
@testable import Plannit

// Voting applies locally before the server hears about it. These run against the
// demo path (the test host has no Supabase config), which is the same local
// bookkeeping the optimistic live path uses — so the arithmetic is covered even
// though the round trip isn't.

@MainActor
final class OptimisticVoteTests: XCTestCase {
    private var model: AppModel!
    private var proposal: PProposal!

    override func setUp() async throws {
        model = AppModel()
        let members = [PMember(id: "me", name: "You"),
                       PMember(id: "maya", name: "Maya"),
                       PMember(id: "theo", name: "Theo")]
        let group = PGroup(id: "g1", name: "Soccer", hue: .teal, members: members, note: "")
        proposal = PProposal(
            id: "p1", title: "Five-a-side", group: group, constraint: "", status: "voting",
            votes: 1,
            slots: [PSlot(id: "s1", day: "SAT", date: 15, time: "2:00 PM", free: 3),
                    PSlot(id: "s2", day: "SUN", date: 16, time: "1:00 PM", free: 2)],
            voteCounts: ["s1": 1])          // Maya already voted for s1
        model.proposals = [proposal]
    }

    private var live: PProposal { model.proposals[0] }

    func testVotingIsVisibleImmediately() async {
        await model.vote(for: proposal.slots[1], on: proposal)   // you pick s2
        XCTAssertEqual(live.myVoteSlotId, "s2")
        XCTAssertEqual(live.voteCounts["s2"], 1)
        XCTAssertEqual(live.voteCounts["s1"], 1, "Maya's vote is untouched")
        XCTAssertEqual(live.votes, 2)
    }

    func testChangingYourVoteMovesItRatherThanAddingOne() async {
        await model.vote(for: proposal.slots[1], on: proposal)
        await model.vote(for: live.slots[0], on: live)

        XCTAssertEqual(live.myVoteSlotId, "s1")
        XCTAssertEqual(live.voteCounts["s2"], 0, "your old pick gives the vote back")
        XCTAssertEqual(live.voteCounts["s1"], 2, "Maya's, plus yours")
        XCTAssertEqual(live.votes, 2, "still two people, not three")
    }

    func testVotingTwiceForTheSameSlotIsIdempotent() async {
        await model.vote(for: proposal.slots[0], on: proposal)
        let after = live.voteCounts["s1"]
        await model.vote(for: live.slots[0], on: live)
        XCTAssertEqual(live.voteCounts["s1"], after, "no double count")
        XCTAssertEqual(live.votes, 2)
    }

    func testRemovingYourVoteGivesItBack() async {
        await model.vote(for: proposal.slots[1], on: proposal)
        await model.removeVote(on: live)

        XCTAssertNil(live.myVoteSlotId)
        XCTAssertEqual(live.voteCounts["s2"], 0)
        XCTAssertEqual(live.votes, 1, "back to Maya's vote alone")
    }

    func testRemovingWhenYouNeverVotedChangesNothing() async {
        await model.removeVote(on: proposal)
        XCTAssertNil(live.myVoteSlotId)
        XCTAssertEqual(live.votes, 1)
    }

    func testACountCanNeverGoNegative() async {
        // Local state can disagree with the server (someone else's delete, a
        // failed retry). Bookkeeping must not produce -1 votes.
        model.proposals[0].myVoteSlotId = "s2"      // claim a vote that isn't counted
        await model.removeVote(on: live)
        XCTAssertEqual(live.voteCounts["s2"] ?? 0, 0)
        XCTAssertGreaterThanOrEqual(live.votes, 0)
    }

    func testTheBadgeFollowsYourVote() async {
        XCTAssertEqual(model.plansBadge, 1, "unanswered plan nags")
        await model.vote(for: proposal.slots[0], on: proposal)
        XCTAssertNil(model.plansBadge, "answered — stop nagging")
        await model.removeVote(on: live)
        XCTAssertEqual(model.plansBadge, 1, "unanswered again")
    }
}
