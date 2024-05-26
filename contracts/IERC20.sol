// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "fhevm/abstracts/EIP712WithModifier.sol";
import "fhevm/lib/TFHE.sol";

interface IEncryptedERC20 {
    // Returns the name of the token.
    function name() external view returns (string memory);

    // Returns the number of decimals used to get its user representation.
    function decimals() external pure returns (uint8);

    // Mints tokens by adding the encryptedAmount to the caller's balance.
    function mint(bytes calldata encryptedAmount) external;

    // Transfers an encrypted amount from the caller to the specified address.
    function transfer(address to, bytes calldata encryptedAmount) external;

    // Transfers an amount from the caller to the specified address.
    function transfer(address to, euint32 amount) external;

    // Returns the total supply of tokens, reencrypted with the provided public key.
    function getTotalSupply(
        bytes32 publicKey,
        bytes calldata signature
    ) external view returns (bytes memory);

    // Returns the balance of the caller, reencrypted with the provided public key.
    function balanceOf(
        bytes32 publicKey,
        bytes calldata signature
    ) external view returns (bytes memory);

    // Approves the specified spender to spend the given encrypted amount on behalf of the caller.
    function approve(address spender, bytes calldata encryptedAmount) external;

    // Returns the remaining number of tokens that the spender is allowed to spend
    // on behalf of the caller, reencrypted with the provided public key.
    function allowance(
        address spender,
        bytes32 publicKey,
        bytes calldata signature
    ) external view returns (bytes memory);

    // Transfers an encrypted amount of tokens from one address to another using the caller's allowance.
    function transferFrom(
        address from,
        address to,
        bytes calldata encryptedAmount
    ) external;

    // Transfers an amount of tokens from one address to another using the caller's allowance.
    function transferFrom(address from, address to, euint32 amount) external;
}
