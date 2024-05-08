// SPDX-License-Identifier: BSD-3-Clause-Clear

// Import interfaces
import {IVesting} from "contracts/interface/IVesting.sol";
//import {IERC20} from "node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import {IEncryptedCapTable} from "contracts/interface/ICaptable.sol";

// Import TFHE library
import "fhevm/lib/TFHE.sol";

// Solidity version pragma
pragma solidity ^0.8.20;

// Vesting contract implementing IVesting interface

contract Vesting is IVesting {
    // ERC20 basic token contract being held
    //IERC20 private _token;
    IEncryptedCapTable captable;

    event TokensReleased(address beneficiary, uint256 amount);
    address private capTable;
    address internal contractOwner;

    constructor() {
        contractOwner = msg.sender;
    }

    function addCaptable(address _address) external onlyContractOwner {
        captable = IEncryptedCapTable(_address);
    }

    function getCompany(
        bytes32 key
    ) internal view returns (IEncryptedCapTable.CompanyDetails memory) {
        return captable.getcompany(key);
    }

    struct VestingParam1 {
        bytes startTimestamp;
        bytes cliffDurationInSeconds;
        bytes totalVestingDurationInSeconds;
    }
    struct VestingParam2 {
        // bytes totalAmount;
        bytes EreleaseAtStartPercentage;
        bytes EreleaseAtCliffPercentage;
        bytes ElinearReleasePercentage;
    }

    // Add a vesting schedule for a beneficiary
    function addVestingPeriod(
        bytes32 _key,
        VestingParam1 calldata params
    ) external onlyAdmin(_key) {
        VestingSchedule memory schedule = VestingSchedule({
            start: TFHE.asEuint32(params.startTimestamp),
            cliffDuration: TFHE.asEuint32(params.cliffDurationInSeconds),
            totalDuration: TFHE.asEuint32(params.totalVestingDurationInSeconds),
            amountTotal: TFHE.asEuint32(0),
            releaseAtStartPercentage: TFHE.asEuint32(0),
            releaseAtCliffPercentage: TFHE.asEuint32(0),
            linearReleasePercentage: TFHE.asEuint32(0)
        });

        IEncryptedCapTable(capTable).addSchedule(schedule, _key);
    }

    function addVestingPercentage(
        bytes32 _key,
        VestingParam2 calldata params
    ) external onlyAdmin(_key) {
        IEncryptedCapTable(capTable).addPercentages(
            TFHE.asEuint32(params.EreleaseAtStartPercentage),
            TFHE.asEuint32(params.EreleaseAtCliffPercentage),
            TFHE.asEuint32(params.ElinearReleasePercentage),
            _key
        );
    }

    function addTotalVestingAmount(
        bytes32 _key,
        bytes memory totalAmount
    ) external onlyAdmin(_key) {
        IEncryptedCapTable(capTable).addTotalVestedAmount(
            TFHE.asEuint32(totalAmount),
            _key
        );
    }

    modifier onlyAdmin(bytes32 key) {
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);

        require(msg.sender == com.admin);
        _;
    }

    modifier onlyContractOwner() {
        require(msg.sender == contractOwner);
        _;
    }
}
