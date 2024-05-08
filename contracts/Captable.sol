// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";

import {EncryptedERC20} from "contracts/EncryptedERC20.sol";
import {IEncryptedCapTable} from "contracts/interface/ICaptable.sol";
import {IVesting} from "contracts/interface/IVesting.sol";

///@title EncryptedCapTable : This contract allows companies to created there token distribution and manage employ holding
/// with the coustimized Vesting period
///  :  Company owner is represed as admin
///  : The share holders are considerd as Employee
/// : Contract allows you to create company (a key which is uniquire to the company).
///  : Add employee and allocate funds and create Vesting plans

contract EncryptedCapTable is IVesting, IEncryptedCapTable, EIP712WithModifier {
    uint256 constant SECONDS_IN_DAY = 86400;

    /// @dev company: Mapping to store company details keyed by a unique identifier
    mapping(bytes32 => CompanyDetails) public company;
    /// @dev isEmpoloyee:Mapping to check if an address is an employee of a specific company
    mapping(bytes32 => mapping(address => bool)) public isEmpoloyee;
    /// @dev employDetailsv :Mapping to store employee details keyed by company and address
    mapping(bytes32 => mapping(address => EmployeeDetails))
        public employDetails;
    /// @dev schedule: Mapping to store vesting schedules keyed by a unique identifier
    mapping(bytes32 => VestingSchedule) public schedule;
    /// Address of the vesting contract
    address public vestingAddr;
    /// a value represend to get percentage values:
    uint32 percent = 100;
    mapping(address => bytes32) public keys;
    //// a mapping that give employee addresses list.
    mapping(bytes32 => address[]) public stakeHolders;

    event NewKey(bytes32 key);

    constructor(
        address _vestingContract
    ) EIP712WithModifier("Authorization token", "1") {
        vestingAddr = _vestingContract;
    }

    function adminKey(address _address) public view returns (bytes32) {
        return keys[_address];
    }
    function getcompany(
        bytes32 key
    ) public view returns (CompanyDetails memory) {
        return company[key];
    }

    function getemployee(
        bytes32 key,
        address employee
    ) public view returns (EmployeeDetails memory) {
        return employDetails[key][employee];
    }

    function getEmployeeList(
        bytes32 _key,
        uint256 _index
    ) external view returns (address[] memory) {
        stakeHolders[_key];
    }

    // Function to create a unique key for a company and deploy an ERC20 token contract
    function createCompanykey(
        string memory _string,
        uint256 _registeryear
    ) external returns (bytes32) {
        // Generate token name based on company name and registration year
        string memory tokenName = string(abi.encodePacked("EERC20", _string));
        // Deploy an ERC20 token contract
        // EncryptedERC20 token = new EncryptedERC20(tokenName);
        bytes32 key = keccak256(abi.encodePacked(_string, _registeryear));
        CompanyDetails memory com = company[key];
        require(com.admin == address(0), "comapny already exist");
        com.admin = msg.sender;
        company[key] = com;
        keys[msg.sender] = key;
        emit NewKey(key);
        return (key);
    }

    /// This Function is use to add employee to the company.;
    ///  This requires an Admin of the company to call the function
    /// @param _key : Retrieve company details
    /// Initialize employee details
    function addEmploy(
        string memory _name,
        address _address,
        bytes32 _key
    ) external {
        CompanyDetails memory com = company[_key];
        require(msg.sender == com.admin, "caller is not admin");
        isEmpoloyee[_key][_address] = true;
        com.employs = TFHE.add(com.employs, TFHE.asEuint32(1));
        company[_key] = com;

        EmployeeDetails memory employ = employDetails[_key][_address];
        employ.stakeholder = _address;
        employ.name = _name;
        stakeHolders[_key].push(_address);
        employDetails[_key][_address] = employ;
    }

    ///  :Function to add allocation/tokens to an employee
    ///  Retrieve company details to increase employee numbers
    ///  caller should be admin
    ///  employ: Retrive Employe details from Struct EmployeeDetails
    ///  com : Retrive CompanyDetails
    function addAllocation(
        address _address,
        bytes calldata _eAmount,
        bytes32 _key
    ) external {
        euint32 eamount = TFHE.asEuint32(_eAmount);
        CompanyDetails memory com = company[_key];
        require(msg.sender == com.admin, "not a valid admin");
        EmployeeDetails memory employ = employDetails[_key][_address];
        employ.totalAllocation = TFHE.add(eamount, employ.totalAllocation);
        com.totalFund = TFHE.add(com.totalFund, eamount);
        employ.allocationTime = uint32(block.timestamp % 2 ** 32);
        employDetails[_key][_address] = employ;
        company[_key] = com;
    }

    /// A dunction called by vesting contract to add Vesting Schedule:
    /// vesting is the Vesting structed defined in Vesting contract
    /// @dev : schedule mapping is created from company key to VestingSchedule
    function addSchedule(VestingSchedule memory vesting, bytes32 _key) public {
        require(vestingAddr == msg.sender);
        schedule[_key] = vesting;
    }

    ///  employee requests to unlock tokens according to timestamp
    ///  Input key is the key of the company and caller should be the employe of company
    ///  we get the vesting schedule of the company
    ///  employ: the employ details by using employDetails mapping
    ///  makes sure that the caller is employee of the company by using require statement
    ///  gets the current timestamp to find the total unlocked token at any point of time
    ///  eTimeStamp is the encrypted version of the current  block.timestamp of type bytes32
    ///  clippTime gives the timestamp at which cliff would start. This is done by adding start timestamp and cliff time
    ///       both start timestamp and cliff time will be availabe in Vesting schedule paramater
    ///         * so Vesting here is designed in a way where it will be unlocked in 3 facets
    ///         1. percentage of unlock at the start of schedule i.e at vest.start time stamp:
    ///                  *This can also be 0 which means no unlock at the start of the schedule
    ///         2. no unlock happens till the cliff time has reached but big chunck gets unlock atfter cliff
    ///                  *Which mean if 5 percent unlock happens at start + unlocked at cliff
    ///         3. after cliff unlock will happen linearly till the end of schedule.
    ///                  *The linear percentage will totally depend on vesting period i.e start time and end time .
    ///                    ** checks if current timeStamp is greate than start Time stamp:
    ///                     * if Yes: then it gives the time passed from the start (current TimeStamp - start TimeStamp )
    ///                     * if No : Then time passes is 0
    /// eCliffStartTimeDiff : Gives the time period till cliff from start. i.e ( cliff TimeStamp - start TimeStamp )
    /// valueBeforeCliff: This function gives the unlocked amount before cliff. i.e amount that should be unlocked at the start
    /// valueAfterCliff : This function gives the unlockedd amount after cliff . i.e start + at cliff + linearly till end of the period
    /// unlockAmt : If cliff duration is greater than time elapsed. then valueBeforeCliff is chossen else valueAfterCliff.
    /// this amount is added to unlock tokens on employ
    /// this value is subtracted from total lock tokens of company
    function request(bytes32 key) external returns (euint32) {
        VestingSchedule memory vest = schedule[key];
        EmployeeDetails memory employ = employDetails[key][msg.sender];
        CompanyDetails memory com = company[key];
        require(isEmpoloyee[key][msg.sender], "not a employee");

        uint32 timestamp = uint32(block.timestamp % 2 ** 32);
        euint32 eTimeStamp = TFHE.asEuint32(timestamp);
        euint32 cliffTime = TFHE.add(vest.start, vest.cliffDuration);

        euint32 eTimeElapsed = TFHE.cmux(
            TFHE.ge(eTimeStamp, vest.start),
            TFHE.sub(timestamp, vest.start),
            TFHE.asEuint32(0)
        );
        euint32 eCliffStartTimeDiff = TFHE.sub(cliffTime, vest.start);

        euint32 unLockeBeforeCliff = valueBeforeCliff(
            vest,
            cliffTime,
            eTimeElapsed,
            employ
        );

        //--------------------------- second method ---------------------//
        euint32 unLockAfterCliff = valueAfterCliff(
            employ,
            vest,
            eTimeElapsed,
            eCliffStartTimeDiff,
            eTimeStamp,
            cliffTime
        );
        euint32 unlockAmt = TFHE.cmux(
            TFHE.ge(vest.cliffDuration, eTimeElapsed),
            unLockeBeforeCliff,
            unLockAfterCliff
        );

        employ.unlocked = TFHE.add(employ.unlocked, unlockAmt);
        com.totalLocked = TFHE.sub(com.totalLocked, unlockAmt);

        employDetails[key][msg.sender] = employ;
        company[key] = com;
        return unlockAmt;
    }

    // amount unlocked after cliff.
    function valueAfterCliff(
        EmployeeDetails memory employ,
        VestingSchedule memory vest,
        euint32 eTimeElapsed,
        euint32 eCliffStartTimeDiff,
        euint32 eTimeStamp,
        euint32 cliffTime
    ) internal returns (euint32) {
        // unlock at the start
        euint32 unlockAtStart = valueBeforeCliff(
            vest,
            cliffTime,
            eTimeElapsed,
            employ
        );

        // unlocked at the cliff
        euint32 unlockatCliff = valueAtCliff(vest, employ, cliffTime);

        /// check if previously tokens were claimed
        /// if yes then time diff will be time stamp - Last claimed time
        /// if no then cliff time is the initial time
        euint32 lastTime = TFHE.cmux(
            TFHE.ge(employ.lastClaimed, cliffTime),
            employ.lastClaimed,
            cliffTime
        );
        /// the time diff calculation
        euint32 timeFromCliff = TFHE.cmux(
            TFHE.ge(eTimeStamp, lastTime),
            TFHE.sub(eTimeStamp, lastTime),
            TFHE.asEuint32(0)
        );

        /// unlock amount after cliff
        euint32 unlockAfterCliff = TFHE.div(
            TFHE.mul(timeFromCliff, employ.totalAllocation),
            percent
        );

        /// total unlock
        euint32 totalUnlock = TFHE.add(
            unlockAfterCliff,
            TFHE.add(unlockAtStart, unlockatCliff)
        );

        return totalUnlock;
    }

    /// number of tokens getting unlock at cliff.
    /// this function is an iteranl functiom and only be called when current time stamp is greater than cliff time stamp
    /// we check if last claimed is greater than cliff time.
    /// if yes then the amount that get unlocked at cliff is already claimed
    function valueAtCliff(
        VestingSchedule memory vest,
        EmployeeDetails memory employ,
        euint32 cliffTime
    ) internal returns (euint32) {
        euint32 unlockAtCliff = TFHE.div(
            TFHE.mul(vest.releaseAtCliffPercentage, employ.totalAllocation),
            percent
        );

        TFHE.cmux(
            TFHE.ge(employ.lastClaimed, cliffTime),
            TFHE.asEuint32(0),
            unlockAtCliff
        );
        return unlockAtCliff;
    }

    /// amount unlocked before cliff
    /// we check the unlock percentage at start
    /// if already claimed then we conclude the vale to be 0
    function valueBeforeCliff(
        VestingSchedule memory vest,
        euint32 cliffTime,
        euint32 eTimeElapsed,
        EmployeeDetails memory employ
    ) internal returns (euint32) {
        euint32 unlockAtStart = TFHE.div(
            TFHE.mul(vest.releaseAtStartPercentage, employ.totalAllocation),
            percent
        );
        unlockAtStart = TFHE.cmux(
            TFHE.ne(employ.lastClaimed, TFHE.asEuint32(0)),
            TFHE.asEuint32(0),
            unlockAtStart
        );
        return unlockAtStart;
    }

    // function which makes employee claim the tokens.
    function claim(bytes calldata _amount, bytes32 _key) external {
        // is unlock > 0 then we claim and transfer funds to sender
        euint32 eamount = TFHE.asEuint32(_amount);
        euint32 claimable = claimableAmount(_key);
        EmployeeDetails memory employ = employDetails[_key][msg.sender];
        CompanyDetails memory com = company[_key];
        employ.claimed = TFHE.add(employ.claimed, eamount);
        employ.lastClaimed = TFHE.asEuint32(uint32(block.timestamp % 2 ** 32));
        com.totalClaimedFund = TFHE.add(com.totalClaimedFund, eamount);

        TFHE.optReq(TFHE.ge(claimable, eamount));
        TFHE.optReq(TFHE.ge(employ.totalAllocation, employ.claimed));

        employDetails[_key][msg.sender] = employ;
        company[_key] = com;
    }

    /// a view function representing claimable amonunt
    function claimableAmount(bytes32 key) public view returns (euint32) {
        EmployeeDetails memory employ = employDetails[key][msg.sender];
        return employ.unlocked;
    }

    /// a view function representing already claimed amount
    function claimAmount(bytes32 key) public view returns (euint32) {
        EmployeeDetails memory employ = employDetails[key][msg.sender];
        return employ.claimed;
    }
}
