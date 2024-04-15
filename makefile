install:
	forge install openzeppelin/openzeppelin-contracts --no-commit &&
	forge install smartcontractkit/chainlink --no-commit  &&
	forge install transmissions11/solmate@v6 --no-commit

push:
	git add .
	git commit -m "chainlink vrf"
	git push origin integrateFactoryLogic