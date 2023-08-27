// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IGrant } from './IGrant.sol';

/////////////////////////////////////////
/// ONLY USED FOR STAGING.
/////////////////////////////////////////

contract StagingGrant is IGrant {
    uint256 internal immutable startOffsetInSeconds;
    uint256 internal immutable amount;

    constructor(uint256 _startOffsetInSeconds, uint256 _amount) {
        if (block.timestamp < _startOffsetInSeconds) revert InvalidConfiguration();

        startOffsetInSeconds = _startOffsetInSeconds;
        amount = _amount;
    }

    function getCurrentId() external view override returns (uint256) {
        return 2865 + (block.timestamp - startOffsetInSeconds) / 3 days;
    }

    function getAmount(uint256) external view override returns (uint256) {
        return amount;
    }

    function checkValidity(uint256 grantId) external view override{
        if (this.getCurrentId() != grantId) revert InvalidGrant();
    }
}
