// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.7.6;

interface IVaultFactory {
    function create() external returns (address vault);

    function createFor(address beneficiary) external returns (address vault);

    function create2(bytes32 salt) external returns (address vault);

    function getOwnerVault(address owner) external view returns (address);
}