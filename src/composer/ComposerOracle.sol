// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IOracle} from "../interfaces/IOracle.sol";
import {BoringERC20} from "../libraries/BoringERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title ComposerOracle
 */
contract ComposerOracle is IOracle {

    event OracleSet(address indexed base, address indexed quote, IOracle indexed oracle);
    event PathSet(address indexed base, address indexed quote, address[] indexed path);

    struct OracleWithDecimals {
        IOracle oracle;
        uint8 baseDecimals;
        uint8 quoteDecimals;
    }

    struct SetOracle {
        address base;
        address quote;
        OracleWithDecimals oracle;
    }

    struct SetPath {
        address base;
        address quote;
        address[] path;
    }

    mapping(address => mapping(address => OracleWithDecimals)) public oracles;
    mapping(address => mapping(address => address[])) public paths;

    constructor (SetOracle[] memory oracles_, SetPath[] memory paths_) {
        uint256 oraclesLength = oracles_.length;
        unchecked {
            for (uint256 p; p < oraclesLength; ++p) {
                _setOracle(oracles_[p].base, oracles_[p].quote, oracles_[p].oracle);
            }
        }
        
        uint256 pathsLength = paths_.length;
        unchecked {
            for (uint256 p; p < pathsLength; ++p) {
                _setPath(paths_[p].base, paths_[p].quote, paths_[p].path);
            }
        }
    }

    /// @notice Set or reset an oracle
    /// @param base base token
    /// @param quote quote token
    /// @param oracle IOracle contract
    function _setOracle(
        address base,
        address quote,
        OracleWithDecimals memory oracle
    ) internal {
        oracles[base][quote] = oracle;
        emit OracleSet(base, quote, oracle.oracle);
    }

    /// @notice Set or reset an oracle path
    /// @param base base token
    /// @param quote quote token
    /// @param path Path from base to quote
    function _setPath(
        address base,
        address quote,
        address[] memory path
    ) internal {
        uint256 pathLength = path.length;
        unchecked {
            for (uint256 p; p < pathLength; ++p) {
                OracleWithDecimals memory oracle_ = oracles[base][path[p]];
                if(oracle_.oracle == IOracle(address(0))) revert OracleUnsupportedPair(base, path[p]);
                base = path[p];
            }
        }
        paths[base][quote] = path;
        emit PathSet(base, quote, path);
    }

    /// @notice Convert amountBase base into quote at the latest oracle price, through a path is exists.
    /// @param base base token
    /// @param quote quote token
    /// @param amountBase Amount of base to convert to quote
    /// @return amountQuote Amount of quote token converted from base
    function valueOf(
        address base,
        address quote,
        uint256 amountBase
    ) external view virtual override returns (uint256 amountQuote) {
        amountQuote = amountBase;
        address[] memory path = paths[base][quote];
        uint256 pathLength = path.length;
        unchecked {
            for (uint256 p; p < pathLength; ++p) {
                amountQuote = _valueOf(base, path[p], amountQuote);
                base = path[p];
            }
        }
        amountQuote = _valueOf(base, quote, amountQuote);
    }

    /// @notice Return the price of base in quote terms, with 18 decimals, at the latest oracle price, through a path is exists.
    /// @param base base token
    /// @param quote quote token
    /// @return price price of base in quote terms, with 18 decimals
    function priceOf(
        address base,
        address quote
    ) external view virtual override returns (uint256 price) {
        address[] memory path = paths[base][quote];
        uint256 pathLength = path.length;
        
        OracleWithDecimals memory oracle = oracles[base][path[0]];
        price = 10 ** oracle.baseDecimals;
        unchecked {
            for (uint256 p; p < pathLength; ++p) {
                price = _valueOf(base, path[p], price);
                base = path[p];
            }
        }
        price = _valueOf(base, quote, price) * 1e18 / 10 ** oracle.quoteDecimals;
    }

    /// @notice Convert amountBase base into quote at the latest oracle price, through a path is exists.
    /// @param base base token
    /// @param quote quote token
    /// @param amountBase Amount of base to convert to quote
    /// @return amountQuote Amount of quote token converted from base
    function _valueOf(
        address base,
        address quote,
        uint256 amountBase
    ) private view returns (uint256 amountQuote) {
        OracleWithDecimals memory oracle = oracles[base][quote];
        if (address(oracle.oracle) == address(0)) revert OracleUnsupportedPair(base, quote);
        amountQuote = oracle.oracle.valueOf(base, quote, amountBase);
    }
}