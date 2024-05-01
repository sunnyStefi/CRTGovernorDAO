//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
//named-imports

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {StudentPath} from "./StudentPath.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract CertificateNFT is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant EVALUATOR = keccak256("EVALUATOR");
    bytes32 public constant STUDENT = keccak256("STUDENT"); //todo assign
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event CertificateCreated();
    event DefaultRolesAssigned();

    error CertificateNFT_StudentHasNotCompletedHisPath();

    address private s_defaultAdmin;

    mapping(uint256 => CertificateStruct) private s_certificates;
    mapping(address => uint256) private s_certificatesOwned;
    EnumerableSet.UintSet s_certificatesIds;
    EnumerableSet.AddressSet s_certificatesOwners;
    uint256 private s_courseCompletedRequiredForCertificate;
    ERC1967Proxy s_studentPathProxy;

    uint256[49] __gap;

    struct CertificateStruct {
        uint256 placeFee;
        uint256 totalPlacesAvailable;
        uint256 placesPurchased;
        address creator;
        string uri;
        string[] lessonsUris;
    }

    struct EvaluatedStudent {
        uint256 mark;
        uint256 date;
        address student;
        address evaluator;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address upgrader, address studentPath) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(EVALUATOR, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));
        _grantRole(ADMIN, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);

        s_defaultAdmin = defaultAdmin;
        s_studentPathProxy = ERC1967Proxy(payable(studentPath));
        s_courseCompletedRequiredForCertificate = 1;

        emit DefaultRolesAssigned();
    }

    function createCertificate(address from, uint256 id, bytes memory data) public onlyRole(ADMIN) returns (uint256) {
        if (
            StudentPath(payable(s_studentPathProxy)).getCoursesCompleted(from)
                != s_courseCompletedRequiredForCertificate
        ) {
            revert CertificateNFT_StudentHasNotCompletedHisPath();
        }
        _mint(from, id, 1, data);
        s_certificatesIds.add(id);
        s_certificatesOwners.add(from);
        s_certificatesOwned[from] += 1;
        emit CertificateCreated();
        return id;
    }

    /**
     * Get
     */
    function getCertificateIds() public view returns (uint256[] memory) {
        return s_certificatesIds.values();
    }

    function isCertified(address _user) public view returns (bool) {
        return s_certificatesOwners.contains(_user);
    }

    function getCertificatesAmountPerUser(address user) public view returns (uint256) {
        return s_certificatesOwned[user];
    }

    /**
     * Set
     */
    function setCourseCompletedRequiredForCertificate(uint256 newValue) public onlyRole(ADMIN) {
        s_courseCompletedRequiredForCertificate = newValue;
    }
    /**
     * Overrides
     */

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data)
        public
        override
        onlyRole(ADMIN)
    {
        super.safeTransferFrom(from, to, id, value, data);
    }

    // OPENSEA

    function uri(uint256 _tokenid) public view override returns (string memory) {
        return s_certificates[_tokenid].uri;
    }

    function setApprovalForAll(address operator, bool approved) public override onlyRole(ADMIN) {
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // PROXY

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
