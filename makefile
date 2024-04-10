install:
	forge install openzeppelin/openzeppelin-contracts --no-commit

push:
	git add .
	git commit -m "added ERC1155 check before mint"
	git push origin main