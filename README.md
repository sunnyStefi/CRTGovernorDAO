## Certificate Generator and DAO v0.2 - cantsDAO

1. Controls funds received by CourseFactory students
2. Can execute a tx only if it's been voted on
3. **CRTokens** can be purchased only if a Certificate has been earned
4. The ratio between CRTokens (ERC20) minted and Certificates earned (ERC1155) must always be 1:1

## Flow
<img src="img/flow_general.png" alt="DAO" width="600"/>
<img src="img/course_factory.png" alt="Factory" width="600"/>
<img src="img/student_path.png" alt="StudentPath" width="600"/>

## Tools
- Openzeppelin: ERC1967Proxy, AccessControl
- Chainlink: VRF (for CourseId)