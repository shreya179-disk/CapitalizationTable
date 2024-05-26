// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

//import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {EncryptedERC20} from "contracts/EncryptedERC20.sol";
import {IEncryptedCapTable} from "contracts/interface/ICaptable.sol";
import {IVesting} from "contracts/interface/IVesting.sol";

// Contract to manage encrypted cap table data

contract CapTableData is EIP712 {
    IEncryptedCapTable captable;

    // Constructor to initialize the contract with cap table address
    constructor(address capTableAddr) EIP712("Authorization token", "1") {
        captable = IEncryptedCapTable(capTableAddr);
    }

    // Function to retrieve company details using a key
    function getCompany(
        bytes32 key
    ) internal view returns (IEncryptedCapTable.CompanyDetails memory) {
        return captable.getcompany(key);
    }

    // Function to retrieve employee details using a key and employee address
    function getEmployee(
        bytes32 key,
        address _employee
    ) internal view returns (IEncryptedCapTable.EmployeeDetails memory) {
        return captable.getemployee(key, _employee);
    }

    // Function to view encrypted company employs data
    function viewCompanyemploys(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlyAdmin(key)
        onlySignedPublicKey(publicKey, signature, key)
        returns (bytes memory)
    {
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);
        bytes memory details = TFHE.reencrypt(com.employs, publicKey, 0);
        return details;
    }

    // Function to view encrypted company total fund data
    function viewCompanytotalFund(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlyAdmin(key)
        onlySignedPublicKey(publicKey, signature, key)
        returns (bytes memory)
    {
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);
        bytes memory details = TFHE.reencrypt(com.totalFund, publicKey, 0);
        return details;
    }

    // Function to view encrypted company total locked data
    function viewCompanytotalLocked(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlyAdmin(key)
        onlySignedPublicKey(publicKey, signature, key)
        returns (bytes memory)
    {
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);
        bytes memory details = TFHE.reencrypt(com.totalLocked, publicKey, 0);
        return details;
    }

    // Function to view encrypted company total claimed fund data
    function viewCompanytotalClaimedFund(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlyAdmin(key)
        onlySignedPublicKey(publicKey, signature, key)
        returns (bytes memory)
    {
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);
        bytes memory details = TFHE.reencrypt(
            com.totalClaimedFund,
            publicKey,
            0
        );
        return details;
    }

    // Modifier to restrict access to only admin of the company
    modifier onlyAdmin(bytes32 key) {
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);

        require(msg.sender == com.admin);
        _;
    }

    // Function to view encrypted employee total allocation data
    function viewEmployeTotalAllocation(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature,
        address caller
    )
        external
        view
        onlySignedPublicKeyEmp(publicKey, signature, key, caller)
        returns (bytes memory)
    {
        IEncryptedCapTable.EmployeeDetails memory employe = getEmployee(
            key,
            caller
        );
        bytes memory details = TFHE.reencrypt(
            employe.totalAllocation,
            publicKey,
            0
        );
        return details;
    }

    // Function to view encrypted employee last claimed data
    function viewEmployeLastClaimed(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature,
        address caller
    )
        external
        view
        onlySignedPublicKeyEmp(publicKey, signature, key, caller)
        returns (bytes memory)
    {
        IEncryptedCapTable.EmployeeDetails memory employe = getEmployee(
            key,
            caller
        );
        bytes memory details = TFHE.reencrypt(
            employe.lastClaimed,
            publicKey,
            0
        );
        return details;
    }

    function viewEmployeName(
        bytes32 key
    ) external view returns (string memory) {
        IEncryptedCapTable.EmployeeDetails memory employe = getEmployee(
            key,
            msg.sender
        );
        string memory details = employe.name;
        return details;
    }

    // Function to view encrypted employee claimed data
    function viewEmployeClaimed(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature,
        address caller
    )
        external
        view
        onlySignedPublicKeyEmp(publicKey, signature, key, caller)
        returns (bytes memory)
    {
        IEncryptedCapTable.EmployeeDetails memory employe = getEmployee(
            key,
            caller
        );
        bytes memory details = TFHE.reencrypt(employe.claimed, publicKey, 0);
        return details;
    }

    // Function to view encrypted employee unlocked data
    function viewEmployeUnlocked(
        bytes32 key,
        bytes32 publicKey,
        bytes calldata signature,
        address caller
    )
        external
        view
        onlySignedPublicKeyEmp(publicKey, signature, key, caller)
        returns (bytes memory)
    {
        IEncryptedCapTable.EmployeeDetails memory employe = getEmployee(
            key,
            caller
        );
        bytes memory details = TFHE.reencrypt(employe.unlocked, publicKey, 0);
        return details;
    }

    modifier onlySignedPublicKey(
        bytes32 publicKey,
        bytes memory signature,
        bytes32 key
    ) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(keccak256("Reencrypt(bytes32 publicKey)"), publicKey)
            )
        );
        address signer = ECDSA.recover(digest, signature);
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);
        require(
            (signer == msg.sender) || (msg.sender == com.admin),
            "EIP712 signer and transaction signer do not match"
        );
        _;
    }

    modifier onlySignedPublicKeyEmp(
        bytes32 publicKey,
        bytes memory signature,
        bytes32 key,
        address caller
    ) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(keccak256("Reencrypt(bytes32 publicKey)"), publicKey)
            )
        );
        address signer = ECDSA.recover(digest, signature);
        IEncryptedCapTable.CompanyDetails memory com = getCompany(key);
        require(
            ((signer == msg.sender) && (msg.sender == caller)) ||
                (msg.sender == com.admin),
            "EIP712 signer and transaction signer do not match"
        );
        _;
    }
}
