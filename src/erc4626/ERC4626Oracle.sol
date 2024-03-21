// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC4626} from "./IERC4626.sol";

contract ERC4626Oracle {
    error OracleUnsupportedPair();

    IERC4626 public immutable VAULT;
    address public immutable ASSET;

    constructor(address _vault) {
        VAULT = IERC4626(_vault);
        ASSET = VAULT.asset();
    }

    function valueOf(address base, address quote, uint256 baseAmount) external view returns (uint256 quoteAmount) {
        if (quote == address(VAULT) && base == ASSET) {
            return VAULT.convertToShares(baseAmount);
        } else if (quote == ASSET && base == address(VAULT)) {
            return VAULT.convertToAssets(baseAmount);
        } else {
            revert OracleUnsupportedPair();
        }
    }

    function priceOf(address base, address quote) external view returns (uint256 baseQuotePrice) {
        if (quote == address(VAULT) && base == ASSET) {
            return VAULT.convertToShares(10 ** IERC20(base).decimals());
        } else if (quote == ASSET && base == address(VAULT)) {
            return VAULT.convertToAssets(10 ** IERC20(quote).decimals());
        } else {
            revert OracleUnsupportedPair();
        }
    }
}
