// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";

import {EncryptedERC20} from "contracts/EncryptedERC20.sol";
import {IEncryptedCapTable} from "contracts/interface/ICaptable.sol";
import {IVesting} from "contracts/interface/IVesting.sol";
import {IEncryptedERC20} from "contracts/IERC20.sol";
///@title EncryptedCapTable : This contract allows companies to created there token distribution and manage employ holding
/// with the coustimized Vesting period
///  :  Company owner is represed as admin
///  : The share holders are considerd as Employee
/// : Contract allows you to create company (a key which is uniquire to the company).
///  : Add employee and allocate funds and create Vesting plans

contract EncryptedCapTable is IEncryptedCapTable, EIP712WithModifier {
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
    ) external view returns (address) {
        return stakeHolders[_key][_index];
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
        require(com.admin == address(0), "company already exist");
        com.admin = msg.sender;
        company[key] = com;
        keys[msg.sender] = key;
        emit NewKey(key);

        return (key);
    }

    function createToken(
        string memory tokenName,
        bytes32 key
    ) external returns (bool) {
        EncryptedERC20 token = new EncryptedERC20(tokenName);
        CompanyDetails memory com = company[key];
        com.ercAddres = address(token);
        company[key] = com;
        return true;
    }

    /// This Function is use to add employee to the company.;
    ///  This requires an Admin of the company to call the function
    /// @param _key : Retrieve company details
    /// Initialize employee details
    function addEmploy(
        string memory _name,
        address _address,
        bytes32 _key,
        bytes calldata _eAmount
    ) external {
        CompanyDetails memory com = company[_key];
        require(msg.sender == com.admin, "caller is not admin");
        isEmpoloyee[_key][_address] = true;
        com.employs = TFHE.add(com.employs, TFHE.asEuint32(1));
        com.totalFund = TFHE.add(com.totalFund, TFHE.asEuint32(_eAmount));
        company[_key] = com;

        EmployeeDetails memory employ = employDetails[_key][_address];
        employ.totalAllocation = TFHE.asEuint32(_eAmount);
        employ.stakeholder = _address;
        employ.name = _name;
        stakeHolders[_key].push(_address);
        employDetails[_key][_address] = employ;
    }

    function addSchedule(VestingSchedule memory vesting, bytes32 _key) public {
        schedule[_key] = vesting;
    }

    /// A dunction called by vesting contract to add Vesting Schedule:
    /// vesting is the Vesting structed defined in Vesting contract

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
    function request(bytes32 key) external {
        VestingSchedule memory vest = schedule[key];
        EmployeeDetails memory employ = employDetails[key][msg.sender];
        CompanyDetails memory com = company[key];
        require(isEmpoloyee[key][msg.sender], "not a employee");

        uint32 timestamp = uint32(block.timestamp);
        euint32 eTimeStamp = TFHE.asEuint32(timestamp);
        euint32 cliffTime = TFHE.add(vest.start, vest.cliffDuration);

        euint32 eTimeElapsed = TFHE.cmux(
            TFHE.ge(eTimeStamp, vest.start),
            TFHE.sub(eTimeStamp, vest.start),
            TFHE.asEuint32(0)
        );
        euint32 eCliffStartTimeDiff = vest.cliffDuration;

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

        employ.unlocked = TFHE.asEuint32(100);
        com.totalLocked = TFHE.sub(com.totalLocked, unlockAmt);

        employDetails[key][msg.sender] = employ;
        // company[key] = com;
    }

    //amount unlocked after cliff.
    function valueAfterCliff(
        EmployeeDetails memory employ,
        VestingSchedule memory vest,
        euint32 eTimeElapsed,
        euint32 eCliffStartTimeDiff,
        euint32 eTimeStamp,
        euint32 cliffTime
    ) internal view returns (euint32) {
        // unlock at the start
        euint32 unlockAtStart = valueBeforeCliff(
            vest,
            cliffTime,
            eTimeElapsed,
            employ
        );

        // unlocked at the cliff
        euint32 unlockatCliff = valueAtCliff(vest, employ, cliffTime);

        // check if previously tokens were claimed
        //if yes then time diff will be time stamp - Last claimed time
        //if no then cliff time is the initial time
        euint32 lastTime = TFHE.cmux(
            TFHE.ge(employ.lastClaimed, cliffTime),
            employ.lastClaimed,
            cliffTime
        );
        // the time diff calculation
        euint32 timeFromCliff = TFHE.cmux(
            TFHE.ge(eTimeStamp, lastTime),
            TFHE.sub(eTimeStamp, lastTime),
            TFHE.asEuint32(0)
        );

        // unlock amount after cliff
        euint32 unlockAfterCliff = TFHE.mul(
            TFHE.mul(timeFromCliff, employ.totalAllocation),
            vest.linearReleasePercentage
        );

        /// total unlock
        euint32 totalUnlock = TFHE.add(
            unlockAfterCliff,
            TFHE.add(unlockAtStart, unlockatCliff)
        );

        return unlockatCliff;
    }

    // number of tokens getting unlock at cliff.
    //this function is an iteranl functiom and only be called when current time stamp is greater than cliff time stamp
    // we check if last claimed is greater than cliff time.
    // if yes then the amount that get unlocked at cliff is already claimed
    function valueAtCliff(
        VestingSchedule memory vest,
        EmployeeDetails memory employ,
        euint32 cliffTime
    ) public view returns (euint32) {
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
    ) internal view returns (euint32) {
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
        EmployeeDetails memory employ = employDetails[_key][msg.sender];
        euint32 claimable = employ.unlocked;
        CompanyDetails memory com = company[_key];
        employ.claimed = TFHE.add(employ.claimed, eamount);
        //employ.lastClaimed = TFHE.asEuint32(uint32(block.timestamp));
        //com.totalClaimedFund = TFHE.add(com.totalClaimedFund, eamount);

        TFHE.optReq(TFHE.ge(claimable, eamount));
        TFHE.optReq(TFHE.ge(employ.totalAllocation, employ.claimed));
        IEncryptedERC20(com.ercAddres).mint(_amount);

        employDetails[_key][msg.sender] = employ;
        company[_key] = com;
    }
}
