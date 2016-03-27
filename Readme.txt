This is a git repo, and a Dropbox folder
.idea is the PyCharm IDE files
output is a folder for programmatic outputs, used to pass around outputs or save outputs for debugging
	Generally don't put things in there
test temp is for scratch scripts to try out syntax
testfiles is test inputs
.gitignore filters compiled files and IDE files from repo (*.c, *.so, *.pyc, etc)
build.bat and build.sh are cmd line scripts running setup.py to compile Cython code
cloc is "Count lines of code", a fun tool
dbgImport - run execfile("dbgImport.py") in (sudo python) to import and compile everything for debugging interactive session
