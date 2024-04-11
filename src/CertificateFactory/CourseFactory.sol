//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
//named-imports

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @notice This contract govern the creation, transfer and management of certificates.
 */
contract CourseFactory is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    // enum Difficulty {
    //     BEGINNER,
    //     INTERMEDIATE,
    //     ADVANCED,
    //     PROFESSIONAL
    // }

    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event CourseFactory_CertificateCreated(uint256 indexed id);
    event CourseFactory_DefaultRolesAssigned();

    error CourseFactory_CourseAlreadyExists();
    error CourseFactory_EachLessonMustHaveOneQuiz();

    address private s_defaultAdmin;

    uint256 s_courseIdCounter;
    mapping(uint256 => CourseStruct) private s_idToCourse;

    uint256[49] __gap;

    struct CourseStruct {
        //0. others
        address creator;
        bool isOpen;
        string uri;
        //1. places
        uint256 placesTotal;
        uint256 placesAvailable;
        //2. test
        string[] testsUris;
        //3. certification
        string certificationUri;
        //4. sections -- not consider for now
        //4.1 lessons
        //4.1.1 quiz
        uint256[] lessonsIds;
        string[] lessonsUris;
        string[] quizUris;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address upgrader) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(ADMIN, ADMIN);

        _grantRole(ADMIN, _msgSender());
        _grantRole(ADMIN, address(this));
        _grantRole(ADMIN, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);

        s_defaultAdmin = defaultAdmin;
        s_courseIdCounter = 0;

        emit CourseFactory_DefaultRolesAssigned();
    }

    function createCourse(
        string memory uri,
        uint256 _placesTotal,
        string[] memory _testsUris,
        string memory _certificationUri,
        string[] memory _lessonsUris,
        string[] memory _quizUris
    ) public onlyRole(ADMIN) returns (CourseStruct memory) {
        if (_lessonsUris.length != _quizUris.length) {
            revert CourseFactory_EachLessonMustHaveOneQuiz();
        }

        uint256[] memory lessonsIds = new uint256[](_lessonsUris.length);
        for (uint256 i = 0; i < _lessonsUris.length; i++) {
            lessonsIds[i] = i;
        }

        CourseStruct memory newCourse = CourseStruct(
            _msgSender(),
            true,
            uri,
            _placesTotal,
            _placesTotal,
            _testsUris,
            _certificationUri,
            lessonsIds,
            _lessonsUris,
            _quizUris
        );

        s_idToCourse[s_courseIdCounter] = newCourse;
        emit CourseFactory_CertificateCreated(s_courseIdCounter);
        s_courseIdCounter.tryAdd(1); //todo research add and safemath current state
        return s_idToCourse[s_courseIdCounter];
    }

    /**
     * Getters
     */
    function getIdCounter() public view returns (uint256) {
        return s_courseIdCounter;
    }

    function getCourse(uint256 id) public view returns (CourseStruct memory) {
        return s_idToCourse[id];
    }

    function getCreator(uint256 id) public view returns (address) {
        return s_idToCourse[id].creator;
    }

    function isAdmin(address user) public view returns (bool) {
        return hasRole(ADMIN, user);
    }
    // PROXY

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
