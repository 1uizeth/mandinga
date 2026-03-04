// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Minimal VRFCoordinatorV2 mock.
///      `requestRandomWords` records requests and returns a sequential ID.
///      `fulfillRequest` lets tests trigger the VRF callback on any consumer.
contract MockVRFCoordinatorV2 {
    uint256 private _nextRequestId = 1;
    mapping(uint256 => address) private _consumers;

    function requestRandomWords(
        bytes32, // keyHash
        uint64,  // subId
        uint16,  // confirmations
        uint32,  // callbackGasLimit
        uint32   // numWords
    ) external returns (uint256 requestId) {
        requestId = _nextRequestId++;
        _consumers[requestId] = msg.sender;
    }

    /// @notice Trigger the VRF callback with a specific random word.
    /// @param requestId  Must match a previously issued request
    /// @param randomWord The random value delivered to the consumer
    function fulfillRequest(uint256 requestId, uint256 randomWord) external {
        address consumer = _consumers[requestId];
        require(consumer != address(0), "unknown requestId");

        uint256[] memory words = new uint256[](1);
        words[0] = randomWord;

        // rawFulfillRandomWords is external on VRFConsumerBaseV2 and checks msg.sender == coordinator
        (bool ok,) = consumer.call(
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words)
        );
        require(ok, "rawFulfillRandomWords reverted");
    }

    function getLastRequestId() external view returns (uint256) {
        return _nextRequestId - 1;
    }
}
