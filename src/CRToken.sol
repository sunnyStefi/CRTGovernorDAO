// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {CertificateNFT} from "./CertificateNFT.sol";

contract CRToken is ERC20, ERC20Permit, ERC20Votes {
    CertificateNFT certificateNFT;

    error CertificantsDAO_OnlyCertificantOwnersCanOwnCRToken();

    constructor(address _certificateNFT) ERC20("CRToken", "CERT") ERC20Permit("CRToken") {
        certificateNFT = CertificateNFT(_certificateNFT);
    }

    function mint(address to, uint256 amount) public {
        if (!certificateNFT.isCertified(to)) {
            revert CertificantsDAO_OnlyCertificantOwnersCanOwnCRToken();
        }
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, value);
        if (from == address(0)) {
            uint256 supply = totalSupply();
            uint256 cap = _maxSupply();
            if (supply > cap) {
                revert ERC20ExceededSafeSupply(supply, cap);
            }
        }
        _transferVotingUnits(from, to, value);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
