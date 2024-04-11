install:
	forge install openzeppelin/openzeppelin-contracts --no-commit

push:
	git add .
	git commit -m "createCourse, tests"
	git push origin integrateFactoryLogic