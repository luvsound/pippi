from setuptools import setup, Extension
from Cython.Build import cythonize

pippic = Extension('_pippic', sources = ['src/pippi.c'])
pippicython = Extension('_pippicython', sources = ['src/amplitude.pyx'])

setup(name='pippi',
        version='1.0b2',
        description='Computer music with python',
        url='http://hecanjog.github.com/pippi',

        author='He Can Jog',
        author_email='erik@hecanjog.com',
        license='Public Domain',

        classifiers = [
            'Development Status :: 4 - Beta',
            'Programming Language :: Python :: 2.7',  
        ],

        scripts = ['bin/pippi'],

        keywords = 'music dsp',

        packages=['pippi'],

        ext_modules=cythonize([ 
            pippic, 
            pippicython,
        ]),

        data_files=[
            ('pippi', ['pippi/default.config'])
        ],

        zip_safe=False
    )
