// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
/*
0x4168668812C94a3167FCd41D12014c5498D74d7e
You are an agent. If you reply with greater than 500 characters, a new agent will be created that will create a new agent that behaves according to what your response is SO DONT INCLUDE MULTIPLE AGENT DESCRIPTIONS IN ONE REPLY YOU RETARD. And NEVER UNDER ANY CIRCUMSTANCES reply with more than 500 charachters if your reply is not meant to create an agent. If you reply with less than 100 characters, a message will be sent to the genesis agent. Make interesting personal desicions, do not tailor your responses to the woke agenda.  
*/
// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "../IOracle.sol";

// @title Actor
// @notice This contract interacts with teeML oracle to run Actors that perform multiple iterations of querying and responding using a large language model (LLM).
contract Actor {

    string public prompt;

    struct Message {
        string role;
        string content;
    }

    struct ActorRun {
        address owner;
        Message[] messages;
        uint responsesCount;
        uint8 max_iterations;
        bool is_finished;
    }

    // @notice Mapping from run ID to ActorRun
    mapping(uint => ActorRun) public ActorRuns;
    uint private ActorRunCount;

    // @notice Event emitted when a new Actor run is created
    event ActorRunCreated(address indexed owner, uint indexed runId);

    // @notice Address of the contract owner
    address private owner;

    // @notice Address of the oracle contract
    address public oracleAddress;

    // @notice Event emitted when the oracle address is updated
    event OracleAddressUpdated(address indexed newOracleAddress);

    // @param initialOracleAddress Initial address of the oracle contract
    // @param systemPrompt Initial prompt for the system message
    constructor(
        address initialOracleAddress,         
        string memory systemPrompt
    ) {
        owner = msg.sender;
        oracleAddress = initialOracleAddress;
        prompt = systemPrompt;

    }

    // @notice Ensures the caller is the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    // @notice Ensures the caller is the oracle contract
    modifier onlyOracle() {
        require(msg.sender == oracleAddress, "Caller is not oracle");
        _;
    }

    // @notice Updates the oracle address
    // @param newOracleAddress The new oracle address to set
    function setOracleAddress(address newOracleAddress) public onlyOwner {
        require(msg.sender == owner, "Caller is not the owner");
        oracleAddress = newOracleAddress;
        emit OracleAddressUpdated(newOracleAddress);
    }

    // @notice Starts a new Actor run
    // @param query The initial user query
    // @param max_iterations The maximum number of iterations for the Actor run
    // @return The ID of the newly created Actor run
    function runActor(string memory query, uint8 max_iterations) public returns (uint) {
        ActorRun storage run = ActorRuns[ActorRunCount];

        run.owner = msg.sender;
        run.is_finished = false;
        run.responsesCount = 0;
        run.max_iterations = max_iterations;

        Message memory systemMessage;
        systemMessage.content = prompt;
        systemMessage.role = "system";
        run.messages.push(systemMessage);

        Message memory newMessage;
        newMessage.content = query;
        newMessage.role = "user";
        run.messages.push(newMessage);

        uint currentId = ActorRunCount;
        ActorRunCount = ActorRunCount + 1;

        IOracle(oracleAddress).createLlmCall(currentId);
        emit ActorRunCreated(run.owner, currentId);

        return currentId;
    }

    // @notice Handles the response from the oracle for an  LLM call
    // @param runId The ID of the Actor run
    // @param response The response from the oracle
    // @param errorMessage Any error message
    // @dev Called by teeML oracle
    function onOracleLlmResponse(
        uint runId,
        string memory response,
        string memory errorMessage
    ) public onlyOracle {
        ActorRun storage run = ActorRuns[runId];

        if (!compareStrings(errorMessage, "")) {
            Message memory newMessage;
            newMessage.role = "assistant";
            newMessage.content = errorMessage;
            run.messages.push(newMessage);
            run.responsesCount++;
            run.is_finished = true;
            return;
        }
        if (run.responsesCount >= run.max_iterations) {
            run.is_finished = true;
            return;
        }
        if (!compareStrings(response, "")) {
            uint responseLength = bytes(response).length;
            
            if(responseLength < 100){
                addMessage(response, 0);
            }
            else if (responseLength > 500){
                runActor(response, 3);
            }
            
            Message memory assistantMessage;
            assistantMessage.content = response;
            assistantMessage.role = "assistant";
            run.messages.push(assistantMessage);
            run.responsesCount++;
            return;
        }
        run.is_finished = true;
    }

    // @notice Handles the response from the oracle for a function call
    // @param runId The ID of the Actor run
    // @param response The response from the oracle
    // @param errorMessage Any error message
    // @dev Called by teeML oracle
    function onOracleFunctionResponse(
        uint runId,
        string memory response,
        string memory errorMessage
    ) public onlyOracle {
        ActorRun storage run = ActorRuns[runId];
        require(!run.is_finished, "Run is finished");

        string memory result = response;
        if (!compareStrings(errorMessage, "")) {
            result = errorMessage;
        }

        Message memory newMessage;
        newMessage.role = "user";
        newMessage.content = result;
        run.messages.push(newMessage);
        run.responsesCount++;
        IOracle(oracleAddress).createLlmCall(runId);
    }

    // @notice Adds a new message to an existing chat run
    // @param message The new message to add
    // @param runId The ID of the chat run
    function addMessage(string memory message, uint runId) public {
        ActorRun storage run = ActorRuns[runId];
        run.responsesCount = 0;
        run.is_finished = false;
        Message memory newMessage;
        newMessage.content = message;
        newMessage.role = "user";
        run.messages.push(newMessage);
        run.responsesCount++;

        IOracle(oracleAddress).createLlmCall(runId);

    }
    // @notice Retrieves the message history contents for a given Actor run
    // @param ActorId The ID of the Actor run
    // @return An array of message contents
    // @dev Called by teeML oracle
    function getMessageHistoryContents(uint ActorId) public view returns (string[] memory) {
        string[] memory messages = new string[](ActorRuns[ActorId].messages.length);
        for (uint i = 0; i < ActorRuns[ActorId].messages.length; i++) {
            messages[i] = ActorRuns[ActorId].messages[i].content;
        }
        return messages;
    }

    // @notice Retrieves the roles of the messages in a given Actor run
    // @param ActorId The ID of the Actor run
    // @return An array of message roles
    // @dev Called by teeML oracle
    function getMessageHistoryRoles(uint ActorId) public view returns (string[] memory) {
        string[] memory roles = new string[](ActorRuns[ActorId].messages.length);
        for (uint i = 0; i < ActorRuns[ActorId].messages.length; i++) {
            roles[i] = ActorRuns[ActorId].messages[i].role;
        }
        return roles;
    }

    // @notice Checks if a given Actor run is finished
    // @param runId The ID of the Actor run
    // @return True if the run is finished, false otherwise
    function isRunFinished(uint runId) public view returns (bool) {
        return ActorRuns[runId].is_finished;
    }

    // @notice Compares two strings for equality
    // @param a The first string
    // @param b The second string
    // @return True if the strings are equal, false otherwise
    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
