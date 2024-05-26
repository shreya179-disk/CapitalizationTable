const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EncryptedCapTable", function () {
    let EncryptedCapTable;
    let encryptedCapTable;
    let owner;
    let employee;
    let nonEmployee;
    let vestingSchedule;
    let companyKey;
    let vestingContractAddress = "0x1234567890123456789012345678901234567890"; // Dummy address

    beforeEach(async function () {
        [owner, employee, nonEmployee] = await ethers.getSigners();

        EncryptedCapTable = await ethers.getContractFactory("EncryptedCapTable");
        encryptedCapTable = await EncryptedCapTable.deploy(vestingContractAddress);
        await encryptedCapTable.deployed();

        // Create a company key
        companyKey = await encryptedCapTable.createCompanykey("TestCompany", 2023);

        // Add an employee to the company
        await encryptedCapTable.addEmploy("Employee1", employee.address, companyKey);

        // Define a vesting schedule
        vestingSchedule = {
            start: 1622505600, // Some past timestamp
            cliffDuration: 300, // 30 days
            totalDuration: 300,
            amountTotal: 1000,
            releaseAtStartPercentage: 10,
            releaseAtCliffPercentage: 10,
            linearReleasePercentage: 10 // 1 year
        };

        // Add vesting schedule
        await encryptedCapTable.addSchedule(vestingSchedule, companyKey);
    });

    it("should correctly calculate unlock amount for an employee", async function () {
        // Advance time to simulate vesting period (e.g., 90 days after start)
        await ethers.provider.send("evm_increaseTime", [60]);
        await ethers.provider.send("evm_mine");

        // Request token unlock
        const unlockAmount = await encryptedCapTable.connect(employee).request(companyKey);

        // Verify the unlocked amount (dummy assertion, you should calculate expected amount)
        expect(unlockAmount).to.be.gt(0);
    });

    // it("should revert if called by a non-employee", async function () {
    //     await expect(encryptedCapTable.connect(nonEmployee).request(companyKey)).to.be.revertedWith("not a employee");
    // });

    // it("should correctly update unlocked and totalLocked amounts", async function () {
    //     const initialEmployeeDetails = await encryptedCapTable.getemployee(companyKey, employee.address);
    //     const initialCompanyDetails = await encryptedCapTable.getcompany(companyKey);

    //     // Advance time to simulate vesting period (e.g., 90 days after start)
    //     await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 90]);
    //     await ethers.provider.send("evm_mine");

    //     // Request token unlock
    //     await encryptedCapTable.connect(employee).request(companyKey);

    //     const updatedEmployeeDetails = await encryptedCapTable.getemployee(companyKey, employee.address);
    //     const updatedCompanyDetails = await encryptedCapTable.getcompany(companyKey);

    //     // Verify the unlocked amount and the updated totalLocked amount
    //     expect(updatedEmployeeDetails.unlocked).to.be.gt(initialEmployeeDetails.unlocked);
    //     expect(updatedCompanyDetails.totalLocked).to.be.lt(initialCompanyDetails.totalLocked);
    // });
});
