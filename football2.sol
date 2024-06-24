// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./IOracle.sol";

contract IntergalacticAmericanFootball {
    address private owner;
    address public oracleAddress;

    struct Message {
        string role;
        string content;
    }

    struct ChatRun {
        address owner;
        Message[] messages;
        uint messagesCount;
    }

    struct Team {
        uint256 id;
        string name;
        string logoUrl;
        address owner;
        mapping(string => Player) players;
        uint256 wins;
        uint256 losses;
        uint256 points;
    }

    struct Player {
        string name;
        string position;
        uint256 skill;
    }

    struct Game {
        uint256 homeTeamId;
        uint256 awayTeamId;
        uint256 homeScore;
        uint256 awayScore;
        bool completed;
    }

    mapping(uint256 => ChatRun) public chatRuns;
    mapping(uint256 => Team) public teams;
    mapping(address => uint256) public addressToTeamId;
    mapping(uint256 => Game) public games;

    uint256 private chatRunsCount;
    uint256 public currentWeek;
    uint256 public constant TEAMS_COUNT = 4;
    uint256 public constant SEASON_WEEKS = 3;
    bool public seasonInProgress;

    string[] public positions = ["QB", "RB", "WR1", "WR2", "TE", "FLEX", "K", "DEF"];

    event ChatCreated(address indexed owner, uint256 indexed chatId);
    event TeamCreated(uint256 teamId, address owner, string name, string logoUrl);
    event PlayerDrafted(uint256 teamId, string position, string playerName, uint256 skill);
    event GameScheduled(uint256 gameId, uint256 homeTeamId, uint256 awayTeamId, uint256 week);
    event GameSimulated(uint256 gameId, uint256 homeScore, uint256 awayScore, string commentary);
    event SeasonStarted(uint256 startTime);
    event SeasonEnded(uint256 winnerId);

// Add this mapping to store available players
mapping(string => string[]) public availablePlayers;

constructor(address initialOracleAddress) {
    owner = msg.sender;
    oracleAddress = initialOracleAddress;
    teamCount = 0;
    gameCount = 0;
    
    // Initialize available players
    availablePlayers["QB"] = ["Patrick Mahomes", "Josh Allen", "Lamar Jackson", "Joe Burrow", "Aaron Rodgers", "Justin Herbert", "Dak Prescott", "Russell Wilson"];
    
    availablePlayers["RB"] = ["Christian McCaffrey", "Derrick Henry", "Austin Ekeler", "Jonathan Taylor", "Saquon Barkley", "Najee Harris", "Dalvin Cook", "Alvin Kamara"];
    
    availablePlayers["WR1"] = ["Justin Jefferson", "Ja'Marr Chase", "Tyreek Hill", "Davante Adams", "Cooper Kupp", "CeeDee Lamb", "A.J. Brown", "Stefon Diggs"];
    
    availablePlayers["WR2"] = ["Jaylen Waddle", "DeVonta Smith", "Terry McLaurin", "DK Metcalf", "Mike Evans", "Keenan Allen", "Deebo Samuel", "Chris Godwin"];
    
    availablePlayers["TE"] = ["Travis Kelce", "Mark Andrews", "George Kittle", "T.J. Hockenson", "Kyle Pitts", "Dallas Goedert", "Darren Waller", "Pat Freiermuth"];
    
    availablePlayers["FLEX"] = ["Christian Kirk", "DeAndre Hopkins", "Amon-Ra St. Brown", "Rhamondre Stevenson", "Kenneth Walker III", "Breece Hall", "Chris Olave", "Garrett Wilson"];
    
    availablePlayers["K"] = ["Justin Tucker", "Harrison Butker", "Evan McPherson", "Tyler Bass", "Daniel Carlson", "Jake Elliott", "Ryan Succop", "Jason Sanders"];
    
    availablePlayers["DEF"] = ["San Francisco 49ers", "Dallas Cowboys", "Philadelphia Eagles", "Buffalo Bills", "New England Patriots", "Baltimore Ravens", "Denver Broncos", "Los Angeles Rams"];
}



function parseTeamInfo(string memory teamConcept, string memory logoUrl) private pure returns (string memory name, string memory url) {
    // Simplified parsing: assume team name is always at the start and ends with a period
    bytes memory conceptBytes = bytes(teamConcept);
    uint256 nameStart = 11; // length of "Team Name: "
    uint256 nameEnd = nameStart;
    for (uint i = nameStart; i < conceptBytes.length; i++) {
        if (conceptBytes[i] == '.') {
            nameEnd = i;
            break;
        }
    }
    name = substring(teamConcept, nameStart, nameEnd);
    url = logoUrl;
}

function parsePlayerSelection(string memory playerSelections) private view returns (string[] memory) {
    string[] memory selectedPlayers = new string[](positions.length);
    bytes memory selectionsBytes = bytes(playerSelections);
    uint256 start = 0;
    uint256 pos = 0;

    for (uint i = 0; i < selectionsBytes.length && pos < positions.length; i++) {
        if (selectionsBytes[i] == '\n') {
            string memory selection = substring(playerSelections, start, i);
            uint256 colonIndex = indexOf(selection, ':');
            if (colonIndex != type(uint256).max) {
                string memory player = substring(selection, colonIndex + 1, bytes(selection).length);
                selectedPlayers[pos] = player;
                pos++;
            }
            start = i + 1;
        }
    }

    return selectedPlayers;
}

function indexOf(string memory s, bytes1 c) private pure returns (uint256) {
    bytes memory sBytes = bytes(s);
    for (uint i = 0; i < sBytes.length; i++) {
        if (sBytes[i] == c) return i;
    }
    return type(uint256).max;
}
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracleAddress, "Caller is not oracle");
        _;
    }

    function setOracleAddress(address newOracleAddress) public onlyOwner {
        oracleAddress = newOracleAddress;
    }

uint256 public gameCount;

function createTeams() public returns (uint) {
    require(teamCount == 0, "Teams already created");
    
    ChatRun storage run = chatRuns[chatRunsCount];
    run.owner = msg.sender;
    
    string memory message = "Generate concepts for 4 Intergalactic American Football team logos. For each, provide a team name and a brief, vivid logo description. Keep descriptions concise and suitable for 2D, flat designs. Separate each team concept with a '|' character.";
    
    addMessage(message, chatRunsCount);

    uint currentId = chatRunsCount;
    chatRunsCount++;

    IOracle(oracleAddress).createLlmCall(currentId);
    
    emit ChatCreated(msg.sender, currentId);

    return currentId;
}

function onOracleLlmResponse(
    uint runId,
    string memory response,
    string memory /*errorMessage*/
) public onlyOracle {
    ChatRun storage run = chatRuns[runId];
    require(run.messagesCount > 0, "No message to respond to");

    addMessage(response, runId);

    if (run.messagesCount == 2 && runId == 0) {
        // Split the response into 4 parts and create teams
        string[] memory teamConcepts = split(response, "|");
        for (uint i = 0; i < 4 && i < teamConcepts.length; i++) {
            createTeamFromConcept(teamConcepts[i]);
            
            // Generate logo for each team
            IOracle(oracleAddress).createFunctionCall(
                runId * 10 + i,
                "image_generation",
                teamConcepts[i]
            );
        }

        // Start the season if all teams are created
        if (teamCount == 4) {
            startSeason();
        }
    } else if (seasonInProgress) {
        // This is a response for game simulation
        finalizeGameSimulation(runId);
    }
}

function onOracleFunctionResponse(
    uint256 callbackId,
    string memory response,
    string memory errorMessage
) public onlyOracle {
    require(bytes(errorMessage).length == 0, "Error in function response");

    uint256 teamId = (callbackId % 10) + 1;
    teams[teamId].logoUrl = response;
}

function createTeamFromConcept(string memory concept) private {
    teamCount++;
    Team storage newTeam = teams[teamCount];
    newTeam.id = teamCount;
    
    string[] memory parts = split(concept, ".");
    if (parts.length > 1) {
        newTeam.name = parts[0];
        newTeam.logoUrl = "Pending...";
    } else {
        newTeam.name = concept;
        newTeam.logoUrl = "Pending...";
    }

    // Assign random players to positions
    for (uint i = 0; i < positions.length; i++) {
        string[] memory positionPlayers = availablePlayers[positions[i]];
        uint randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, teamCount, i))) % positionPlayers.length;
        newTeam.players[positions[i]] = Player(positionPlayers[randomIndex], positions[i], 50 + (randomIndex * 5));
    }

    emit TeamCreated(teamCount, address(0), newTeam.name, newTeam.logoUrl);
}

function startSeason() private {
    require(!seasonInProgress, "Season already in progress");
    seasonInProgress = true;
    currentWeek = 1;
    scheduleGames();
    emit SeasonStarted(block.timestamp);
}

function scheduleGames() private {
    for (uint256 week = 1; week <= SEASON_WEEKS; week++) {
        gameCount++;
        games[gameCount] = Game(week % 2 == 1 ? 1 : 2, week % 2 == 1 ? 2 : 1, 0, 0, false);
        emit GameScheduled(gameCount, games[gameCount].homeTeamId, games[gameCount].awayTeamId, week);

        gameCount++;
        games[gameCount] = Game(week % 2 == 1 ? 3 : 4, week % 2 == 1 ? 4 : 3, 0, 0, false);
        emit GameScheduled(gameCount, games[gameCount].homeTeamId, games[gameCount].awayTeamId, week);
    }
}

function simulateGame(uint256 gameId) public {
    require(seasonInProgress, "Season not in progress");
    require(gameId > 0 && gameId <= gameCount, "Invalid game ID");
    Game storage game = games[gameId];
    require(!game.completed, "Game already completed");

    uint256 chatId = chatRunsCount++;
    ChatRun storage run = chatRuns[chatId];
    run.owner = owner;

    string memory gamePrompt = string(abi.encodePacked(
        "Simulate an exciting Intergalactic American Football game between ",
        teams[game.homeTeamId].name, " and ", teams[game.awayTeamId].name,
        ". Provide a play-by-play commentary highlighting key moments and player performances. ",
        "End the commentary with 'Final Score: [Home Team Score] - [Away Team Score]' using only numbers for the scores."
    ));
    addMessage(gamePrompt, chatId);
    IOracle(oracleAddress).createLlmCall(chatId);
}

function parseGameResult(string memory commentary) private pure returns (uint256 homeScore, uint256 awayScore) {
    bytes memory commentaryBytes = bytes(commentary);
    uint256 length = commentaryBytes.length;
    bool foundFinalScore = false;

    // Look for "Final Score:" in the commentary
    for (uint i = 0; i < length - 11; i++) {
        if (keccak256(abi.encodePacked(substring(commentary, i, i + 12))) == keccak256(abi.encodePacked("Final Score:"))) {
            foundFinalScore = true;
            
            // Search for the scores after "Final Score:"
            for (uint j = i + 12; j < length - 2; j++) {
                uint8 charCode = uint8(commentaryBytes[j]);
                if (charCode >= 48 && charCode <= 57) {
                    homeScore = uint256(charCode - 48);
                    if (uint8(commentaryBytes[j+1]) >= 48 && uint8(commentaryBytes[j+1]) <= 57) {
                        homeScore = homeScore * 10 + uint256(uint8(commentaryBytes[j+1]) - 48);
                        j++;
                    }
                    
                    // Find the away score
                    for (uint k = j + 1; k < length - 1; k++) {
                        charCode = uint8(commentaryBytes[k]);
                        if (charCode >= 48 && charCode <= 57) {
                            awayScore = uint256(charCode - 48);
                            if (uint8(commentaryBytes[k+1]) >= 48 && uint8(commentaryBytes[k+1]) <= 57) {
                                awayScore = awayScore * 10 + uint256(uint8(commentaryBytes[k+1]) - 48);
                            }
                            break;
                        }
                    }
                    break;
                }
            }
            break;
        }
    }

    require(foundFinalScore, "Final score not found in commentary");
    require(homeScore > 0 || awayScore > 0, "Invalid scores parsed");
}

function finalizeGameSimulation(uint256 runId) private {
    ChatRun storage run = chatRuns[runId];
    string memory commentary = run.messages[1].content;
    
    // Parse game results
    (uint256 homeScore, uint256 awayScore) = parseGameResult(commentary);
    
    // Find the corresponding game
    for (uint256 i = 1; i <= gameCount; i++) {
        if (!games[i].completed) {
            Game storage game = games[i];
            game.homeScore = homeScore;
            game.awayScore = awayScore;
            game.completed = true;

            updateTeamStats(game.homeTeamId, game.awayTeamId, homeScore, awayScore);

            emit GameSimulated(i, homeScore, awayScore, commentary);

            if (allGamesCompletedForWeek()) {
                currentWeek++;
                if (currentWeek > SEASON_WEEKS) {
                    endSeason();
                }
            }
            break;
        }
    }
}


function split(string memory _base, string memory _delimiter) internal pure returns (string[] memory) {
    bytes memory baseBytes = bytes(_base);
    bytes memory delimiterBytes = bytes(_delimiter);

    uint count = 1;
    for (uint i = 0; i < baseBytes.length - delimiterBytes.length; i++) {
        bool foundDelimiter = true;
        for (uint j = 0; j < delimiterBytes.length; j++) {
            if (baseBytes[i + j] != delimiterBytes[j]) {
                foundDelimiter = false;
                break;
            }
        }
        if (foundDelimiter) {
            count++;
            i += delimiterBytes.length - 1;
        }
    }

    string[] memory result = new string[](count);
    uint start = 0;
    count = 0;

    for (uint i = 0; i < baseBytes.length - delimiterBytes.length + 1; i++) {
        bool foundDelimiter = true;
        for (uint j = 0; j < delimiterBytes.length; j++) {
            if (i + j >= baseBytes.length || baseBytes[i + j] != delimiterBytes[j]) {
                foundDelimiter = false;
                break;
            }
        }
        if (foundDelimiter || i == baseBytes.length - delimiterBytes.length) {
            uint end = foundDelimiter ? i : baseBytes.length;
            uint len = end - start;
            bytes memory tmpBytes = new bytes(len);
            for (uint j = 0; j < len; j++) {
                tmpBytes[j] = baseBytes[start + j];
            }
            result[count] = string(tmpBytes);
            count++;
            start = i + delimiterBytes.length;
            i += delimiterBytes.length - 1;
        }
    }

    return result;
}



    uint256 public teamCount;

function finalizeTeamCreation(uint256 runId) private {
    ChatRun storage run = chatRuns[runId];
    teamCount++;
    uint256 newTeamId = teamCount;
    Team storage newTeam = teams[newTeamId];
    newTeam.id = newTeamId;
    newTeam.owner = run.owner;
    
    // Parse team name and logo URL from chat responses
    (string memory teamName, string memory logoUrl) = parseTeamInfo(run.messages[1].content, run.messages[3].content);
    newTeam.name = teamName;
    newTeam.logoUrl = logoUrl;

    // Parse and create players
    string[] memory playerNames = parsePlayerNames(run.messages[5].content);
    for (uint256 i = 0; i < positions.length; i++) {
        uint256 skill = uint256(keccak256(abi.encodePacked(playerNames[i], block.timestamp))) % 100;
        newTeam.players[positions[i]] = Player(playerNames[i], positions[i], skill);
        emit PlayerDrafted(newTeamId, positions[i], playerNames[i], skill);
    }

    addressToTeamId[run.owner] = newTeamId;
    emit TeamCreated(newTeamId, run.owner, teamName, logoUrl);

    if (newTeamId == TEAMS_COUNT) {
        startSeason();
    }
}


    function updateTeamStats(uint256 homeTeamId, uint256 awayTeamId, uint256 homeScore, uint256 awayScore) private {
        Team storage homeTeam = teams[homeTeamId];
        Team storage awayTeam = teams[awayTeamId];

        if (homeScore > awayScore) {
            homeTeam.wins++;
            awayTeam.losses++;
        } else {
            awayTeam.wins++;
            homeTeam.losses++;
        }

        homeTeam.points += homeScore;
        awayTeam.points += awayScore;
    }

function allGamesCompletedForWeek() private view returns (bool) {
    uint256 gamesThisWeek = (currentWeek - 1) * 2 + 1;
    return gamesThisWeek <= gameCount && 
           games[gamesThisWeek].completed && 
           games[gamesThisWeek + 1].completed;
}

function endSeason() private {
    seasonInProgress = false;
    uint256 highestPoints = 0;
    uint256 winnerId = 0;
    for (uint256 i = 1; i <= teamCount; i++) {
        if (teams[i].points > highestPoints) {
            highestPoints = teams[i].points;
            winnerId = i;
        }
    }
    emit SeasonEnded(winnerId);
}
    function addMessage(string memory content, uint256 runId) private {
        ChatRun storage run = chatRuns[runId];
        run.messages.push(Message({
            role: run.messagesCount % 2 == 0 ? "assistant" : "user",
            content: content
        }));
        run.messagesCount++;
    }


    function parsePlayerNames(string memory playerNamesResponse) private pure returns (string[] memory) {
        // Simple implementation - in practice, you'd want more robust parsing
        string[] memory names = new string[](8);
        bytes memory responseBytes = bytes(playerNamesResponse);
        uint256 nameStart = 0;
        uint256 nameCount = 0;
        for (uint i = 0; i < responseBytes.length && nameCount < 8; i++) {
            if (responseBytes[i] == '\n') {
                names[nameCount] = substring(playerNamesResponse, nameStart, i);
                nameStart = i + 1;
                nameCount++;
            }
        }
        if (nameCount < 8 && nameStart < responseBytes.length) {
            names[nameCount] = substring(playerNamesResponse, nameStart, responseBytes.length);
        }
        return names;
    }

    function substring(string memory str, uint256 startIndex, uint256 endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function getMessageHistoryRoles(uint256 callbackId) public view returns (string[] memory) {
        ChatRun storage run = chatRuns[callbackId];
        string[] memory roles = new string[](run.messagesCount);
        for (uint256 i = 0; i < run.messagesCount; i++) {
            roles[i] = run.messages[i].role;
        }
        return roles;
    }

    function getMessageHistoryContents(uint256 callbackId) public view returns (string[] memory) {
        ChatRun storage run = chatRuns[callbackId];
        string[] memory contents = new string[](run.messagesCount);
        for (uint256 i = 0; i < run.messagesCount; i++) {
            contents[i] = run.messages[i].content;
        }
        return contents;
    }

function getMessageHistory(uint256 callbackId) public view returns (IOracle.Message[] memory) {
        ChatRun storage run = chatRuns[callbackId];
        IOracle.Message[] memory messages = new IOracle.Message[](run.messagesCount);
        for (uint256 i = 0; i < run.messagesCount; i++) {
            IOracle.Content[] memory content = new IOracle.Content[](1);
            content[0] = IOracle.Content({
                contentType: "text",
                value: run.messages[i].content
            });
            messages[i] = IOracle.Message({
                role: run.messages[i].role,
                content: content
            });
        }
        return messages;
    }

    function getTeam(uint256 teamId) public view returns (string memory name, string memory logoUrl, address teamOwner, uint256 wins, uint256 losses, uint256 points) {
        Team storage team = teams[teamId];
        return (team.name, team.logoUrl, team.owner, team.wins, team.losses, team.points);
    }

    function getPlayer(uint256 teamId, string memory position) public view returns (string memory name, uint256 skill) {
        Player storage player = teams[teamId].players[position];
        return (player.name, player.skill);
    }

    function getGame(uint256 gameId) public view returns (uint256 homeTeamId, uint256 awayTeamId, uint256 homeScore, uint256 awayScore, bool completed) {
        Game storage game = games[gameId];
        return (game.homeTeamId, game.awayTeamId, game.homeScore, game.awayScore, game.completed);
    }

    function getCurrentWeek() public view returns (uint256) {
        return currentWeek;
    }

    function isSeasonInProgress() public view returns (bool) {
        return seasonInProgress;
    }
function getTotalGames() public view returns (uint256) {
    return gameCount;
}
}