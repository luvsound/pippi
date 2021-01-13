# Raspberry Pi

Clone pippi and cython:

    cd myprojects
    git clone https://github.com/luvsound/pippi.git
    git clone https://github.com/cython/cython.git

Create a virtualenv:

    python3 -m venv venv

Activate it:

    source ./venv/bin/activate

Install llvmlite:

    sudo apt install llvm-9
    LLVM_CONFIG=llvm-config-9 pip install llvmlite

Install cython:

    cd cython; pip install -e .; cd -;

Then run the install script:

    cd pippi; make install; cd -;



