// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

contract Crowdfunding {
    // List of existing projects
    Project[] private projects;

    // Event that will be emitted whenever a new project is started
    event ProjectStarted(
        address contractAddress,
        address projectStarter,
        uint256 deadline,
        uint256 goalAmount,
        string uniqueId
    );

    /** @dev Function to start a new project.
     * @param amountToRaise Project goal in wei
     */
    function startProject(
        address payable feesTaker,
        uint256 amountToRaise,
        uint256 deadline,
        string calldata uniqueId
    ) external {
        Project newProject = new Project(
            payable(msg.sender),
            feesTaker,
            deadline,
            amountToRaise,
            uniqueId
        );
        projects.push(newProject);
        emit ProjectStarted(
            address(newProject),
            msg.sender,
            deadline,
            amountToRaise,
            uniqueId
        );
    }

    /** @dev Function to get all projects' contract addresses.
     * @return A list of all projects' contract addreses
     */
    function returnAllProjects() external view returns (Project[] memory) {
        return projects;
    }
}

contract Project {
    // Data structures
    enum State {
        Fundraising,
        Expired,
        Successful
    }

    // State variables
    address payable public feesTaker;
    address payable public creator;
    uint256 public amountGoal; // required to reach at least this much, else everyone gets refund
    uint256 public completeAt;
    uint256 public currentBalance;
    uint256 public raiseBy;
    string public uniqueId;
    // uint256 public cc =  block.timestamp;

    State public state = State.Fundraising; // initialize on create
    mapping(address => uint256) public contributions;

    // Event that will be emitted whenever funding will be received
    event FundingReceived(
        address contributor,
        uint256 amount,
        uint256 currentTotal
    );
    // Event that will be emitted whenever the project starter has received the funds
    event CreatorPaid(address recipient);

    event Expired(State state);

    // Modifier to check current state
    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    // Modifier to check if the function caller is the project creator
    modifier isCreator() {
        require(msg.sender == creator);
        _;
    }

    constructor(
        address payable projectStarter,
        address payable feeAddress,
        uint256 fundRaisingDeadline,
        uint256 goalAmount,
        string memory uid
    ) {
        creator = projectStarter;
        feesTaker = feeAddress;
        amountGoal = goalAmount;
        raiseBy = fundRaisingDeadline;
        currentBalance = 0;
        uniqueId = uid;
    }

    /** @dev Function to fund a certain project.
     */
    function contribute() external payable inState(State.Fundraising) {
        require(msg.sender != creator);
        if (block.timestamp < raiseBy) {
            contributions[msg.sender] += msg.value;
            currentBalance += msg.value;
            emit FundingReceived(msg.sender, msg.value, currentBalance);
            checkIfFundingCompleteOrExpired();
        } else {
            state = State.Expired;
            emit Expired(state);
        }
    }

    /** @dev Function to change the project state depending on conditions.
     */
    function checkIfFundingCompleteOrExpired() public {
        if (currentBalance >= amountGoal) {
            state = State.Successful;
            payOut();
        } else if (block.timestamp > raiseBy) {
            state = State.Expired;
        }
        completeAt = block.timestamp;
    }

    /** @dev Function to give the received funds to project starter.
     */
    function payOut() internal inState(State.Successful) returns (bool) {
        uint256 totalRaised = currentBalance;

        uint256 fs = (totalRaised * 95) / 10000;
        uint256 tam = totalRaised - fs;
        feesTaker.transfer(fs);

        currentBalance = 0;

        if (creator.send(tam)) {
            emit CreatorPaid(creator);
            return true;
        } else {
            currentBalance = tam;
            state = State.Successful;
        }

        return false;
    }

    /** @dev Function to retrieve donated amount when a project expires.
     */
    function getRefund() public returns (bool) {
        require(block.timestamp > raiseBy);
        require(contributions[msg.sender] > 0);

        state = State.Expired;

        uint256 amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;

        if (!payable(msg.sender).send(amountToRefund)) {
            contributions[msg.sender] = amountToRefund;
            return false;
        } else {
            currentBalance -= amountToRefund;
        }
        return true;
    }

    function getDetails()
        public
        view
        returns (
            address payable projectStarter,
            uint256 deadline,
            State currentState,
            uint256 currentAmount,
            uint256 goalAmount,
            string memory uniqueIdentifier
        )
    {
        projectStarter = creator;
        deadline = raiseBy;
        currentState = state;
        currentAmount = currentBalance;
        goalAmount = amountGoal;
        uniqueIdentifier = uniqueId;
    }
}
