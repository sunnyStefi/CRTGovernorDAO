install:
	forge install openzeppelin/openzeppelin-contracts --no-commit

push:
	git add .
	git commit -m "amount ERC1155 must be less or equal to ERC20"
	git push origin main