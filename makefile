install:
	forge install openzeppelin/openzeppelin-contracts --no-commit

push:
	git add .
	git commit -m "init"
	git push origin main