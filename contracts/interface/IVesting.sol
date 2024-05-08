// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";

interface IVesting {
    struct VestingSchedule {
        euint32 start; // Timestamp when vesting starts
        euint32 cliffDuration; // Duration of the cliff in seconds
        euint32 totalDuration; // Total duration of vesting in seconds
        euint32 amountTotal; // Total amount of tokens to be vested
        euint32 releaseAtStartPercentage; // Amount to be released at the start
        euint32 releaseAtCliffPercentage; // Amount to be released after the cliff
        euint32 linearReleasePercentage; // Amount to be released monthly after the cliff
        //  uint256 amountClaimed;
    }
}
