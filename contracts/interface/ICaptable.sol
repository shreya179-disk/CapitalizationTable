// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.20;

import {IVesting} from "contracts/interface/IVesting.sol";
import "fhevm/lib/TFHE.sol";

interface IEncryptedCapTable is IVesting {
    /// EmployeeDetails represents details of all employs of company
    /// @param stakeholder: address of the employe
    /// @param totalAllocation : total allocated amount
    /// @param unlocked: unlocked amount
    /// @param isClaimAvailable : if currently any claimable amount is availabe
    /// @param allocationTime : Time stamp at which employ was allocated
    struct EmployeeDetails {
        string name;
        address stakeholder;
        euint32 totalAllocation;
        euint32 unlocked;
        euint32 claimed;
        ebool isClaimAvailable;
        uint32 allocationTime;
        euint32 lastClaimed;
    }

    /// CompanyDetails : represents details of companies associated with key
    /// @param employs: total Number of employees
    /// @param admin:  Address of the admin
    /// @param totalFund: Total funds allocated to the company
    /// @param totalClaimedFund : Total funds claimed by all employees
    /// @param totalLocked : Total funds currently locked
    /// @param ercAddres : Address of the ERC20 token contract
    struct CompanyDetails {
        euint32 employs;
        address admin;
        euint32 totalFund;
        euint32 totalClaimedFund;
        euint32 totalLocked;
        address ercAddres;
    }

    function createCompanykey(
        string memory _string,
        uint256 _registeryear
    ) external returns (bytes32);
    function addEmploy(
        string memory _name,
        address _address,
        bytes32 _key
    ) external;
    function addAllocation(
        address _address,
        bytes calldata _Eamount,
        bytes32 _key
    ) external;
    function addSchedule(VestingSchedule memory vesting, bytes32 _key) external;
    function request(bytes32 key) external returns (euint32);
    function claim(bytes calldata _amount, bytes32 _key) external;
    function claimableAmount(bytes32 key) external view returns (euint32);
    function claimAmount(bytes32 key) external view returns (euint32);
    function getcompany(
        bytes32 key
    ) external view returns (CompanyDetails memory);

    function getemployee(
        bytes32 key,
        address employee
    ) external view returns (EmployeeDetails memory);
}
