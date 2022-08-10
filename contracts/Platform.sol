//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

contract Platform {
  using Counters for Counters.Counter;
  
  enum PostKind {
    QUERY,
    ANSWER
  }

  // Represents a single platform query or answer. 
  struct Post {
    // what kind of post (query or answer)
    PostKind kind;

    // Unique post id, assigned at creation time.
    uint256 id;

    // Id of parent post. Query have parentId == 0.
    uint256 parentId;

    // address of poster.
    address poster;

    // block number when post was submitted
    uint256 createdAtBlock;

    // ids of all child posts, with oldest posts at front.
    uint256[] childIds;

    /// IPFS CID of post content.
    string contentCID;
  }

  /// Vote state for a particular query or answer.
  struct VoteCount {
    // mapping of hash(voterAddress) => vote, where +1 == upvote, -1 == downvote, and 0 == not yet voted
    mapping(bytes32 => int8) votes;

    // accumulation of all votes for this content
    int256 total;
  }

  /// counter for issuing post ids
  Counters.Counter private postIdCounter;
  
  /// maps post id to vote state
  mapping(uint256 => VoteCount) private postVotes;

  /// maps poster address total query & answer vote score
  mapping(address => int256) private posterReputation;

  /// maps post id to post
  mapping(uint256 => Post) private posts;

  /// NewPost events are emitted when a query or answer is created.
  event NewPost(
    uint256 indexed id,
    uint256 indexed parentId,
    address indexed poster
  );

  /** Create a new query.
    * @param contentCID IPFS CID of query content object.
   */
  function addQuery(string memory contentCID) public {
    postIdCounter.increment();
    uint256 id = postIdCounter.current();
    address poster = msg.sender;

    uint256[] memory childIds;
    posts[id] = Post(PostKind.QUERY, id, 0, poster, block.number, childIds, contentCID);
    emit NewPost(id, 0, poster);
  }

  /**
    * Fetch a post by id.
    * reverts if no post exists with the given id.
    */
  function getPost(uint256 postId) public view returns (Post memory) {
    require(posts[postId].id == postId, "No item found");
    return posts[postId];
  }


  /** 
    * Adds an answer to a query or another answer.
    * will revert if the parent post does not exist.
    * parentId the id of an existing post
    * contentCID IPFS CID of answer content object
    */
  function addAnswer(uint256 parentId, string memory contentCID) public {
    require(posts[parentId].id == parentId, "Parent item does not exist");

    postIdCounter.increment();
    uint256 id = postIdCounter.current();
    address poster = msg.sender;

    posts[parentId].childIds.push(id);

    uint256[] memory childIds;
    posts[id] = Post(PostKind.ANSWER, id, parentId, poster, block.number, childIds, contentCID);
    emit NewPost(id, parentId, poster);
  }

  function voteForPost(uint256 postId, int8 voteValue) public {
    require(posts[postId].id == postId, "Item does not exist");
    require(voteValue >= -1 && voteValue <= 1, "Invalid vote value. Must be -1, 0, or 1");

    bytes32 voterId = _voterId(msg.sender);
    int8 oldVote = postVotes[postId].votes[voterId];
    if (oldVote != voteValue) {
      postVotes[postId].votes[voterId] = voteValue;
      postVotes[postId].total = postVotes[postId].total - oldVote + voteValue;

      address poster = posts[postId].poster;
      if (poster != msg.sender) {
        posterReputation[poster] = posterReputation[poster] - oldVote + voteValue;
      }
    }
  }

  function getPostScore(uint256 postId) public view returns (int256) {
    return postVotes[postId].total;
  }

  function getAuthorReputation(address poster) public view returns (int256) {
    return posterReputation[poster];
  }

  function _voterId(address voter) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(voter));
  }

}