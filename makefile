install:
	forge install openzeppelin/openzeppelin-contracts --no-commit

push:
	git add .
	git commit -m "test init"
	git push origin main