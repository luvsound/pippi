#!/usr/bin/env python
from setuptools import setup
from setuptools.extension import Extension
from Cython.Build import cythonize
import numpy as np

ext_modules = cythonize([
        Extension('pippi.defaults', ['pippi/defaults.pyx']), 
        Extension('pippi.dsp', ['pippi/dsp.pyx']), 
        Extension('pippi.drummachine', ['pippi/drummachine.pyx']), 
        Extension('pippi.fx', ['pippi/fx.pyx'],
            libraries=['soundpipe', 'm'], 
            extra_compile_args=['-O3', '-ffast-math', '-march=native', '-fopenmp'],
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ),
        Extension('pippi.grains', ['pippi/grains.pyx'],
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ),
        Extension('pippi.sampler', ['pippi/sampler.pyx'],
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ),
        Extension('pippi.graph', ['pippi/graph.pyx']), 
        Extension('pippi.interpolation', ['pippi/interpolation.pyx']),

        Extension('pippi.oscs', ['pippi/oscs.pyx']), 
        Extension('pippi.dss', ['pippi/dss.pyx']), 
        Extension('pippi.fold', ['pippi/fold.pyx']), 
        Extension('pippi.osc', ['pippi/osc.pyx']), 
        Extension('pippi.osc2d', ['pippi/osc2d.pyx']), 
        Extension('pippi.pulsar', ['pippi/pulsar.pyx']), 
        Extension('pippi.pulsar2d', ['pippi/pulsar2d.pyx']), 
        Extension('pippi.pluck', ['pippi/pluck.pyx']), 
        Extension('pippi.alias', ['pippi/alias.pyx']), 

        Extension('pippi.rhythm', ['pippi/rhythm.pyx']), 
        Extension('pippi.rand', ['pippi/rand.pyx']), 
        Extension('pippi.soundbuffer', ['pippi/soundbuffer.pyx'], 
            include_dirs=[np.get_include()], 
        ), 
        Extension('pippi.soundpipe', ['pippi/soundpipe.pyx'], 
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ), 
        Extension('pippi.wavesets', ['pippi/wavesets.pyx']), 
        Extension('pippi.wavetables', ['pippi/wavetables.pyx'],
            include_dirs=[np.get_include()], 
        ),
    ], 
    annotate=True
) 

with open('README.md') as f:
    readme = f.read()

setup(
    name='pippi',
    version='2.0.0-beta-4',
    description='Computer music with Python',
    long_description=readme,
    long_description_content_type='text/markdown',
    author='He Can Jog',
    author_email='erik@hecanjog.com',
    url='https://github.com/hecanjog/pippi',
    packages=['pippi', 'pippi.tune'],
    ext_modules=ext_modules, 
    install_requires=[
        'numpy', 
        'Pillow', 
        'PySoundFile'
    ], 
    keywords='algorithmic computer music', 
    python_requires='>=3',
    classifiers=[
        'Development Status :: 4 - Beta', 
        'Intended Audience :: Developers',
        'Intended Audience :: Education',
        'Intended Audience :: Other Audience', # Musicians and audio tinkerers, and of course anyone else...
        'License :: Public Domain', 
        'Natural Language :: English', 
        'Operating System :: POSIX', 
        'Operating System :: POSIX :: Linux', 
        'Operating System :: Microsoft :: Windows', 
        'Operating System :: MacOS', 
        'Programming Language :: Cython', 
        'Programming Language :: Python :: 3 :: Only', 
        'Programming Language :: Python :: 3.6', 
        'Topic :: Artistic Software', 
        'Topic :: Multimedia :: Sound/Audio', 
        'Topic :: Multimedia :: Sound/Audio :: Sound Synthesis', 
    ]
)
