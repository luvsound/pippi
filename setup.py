#!/usr/bin/env python
from setuptools import setup
from setuptools.extension import Extension
from Cython.Build import cythonize
import numpy as np

ext_modules = cythonize([
        Extension('pippi.breakpoints', ['pippi/breakpoints.pyx'],
            include_dirs=[np.get_include()], 
        ),
        Extension('pippi.multiband', ['pippi/multiband.pyx'], 
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include', np.get_include()]
        ), 
        Extension('pippi.events', ['pippi/events.pyx'],
            include_dirs=[np.get_include()], 
        ),

        Extension('pippi.defaults', ['pippi/defaults.pyx']), 
        Extension('pippi.dsp', ['pippi/dsp.pyx']), 
        Extension('pippi.fx', ['pippi/fx.pyx'],
            libraries=['soundpipe', 'm'], 
            extra_compile_args=['-O3', '-ffast-math', '-march=native', '-fopenmp'],
            extra_link_args=['-fopenmp'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include', 'modules/fft', np.get_include()]
        ),
        Extension('pippi.grains', ['pippi/grains.pyx'],
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ),
        Extension('pippi.lists', ['pippi/lists.pyx'],
            include_dirs=[np.get_include()], 
        ),
        Extension('pippi.sampler', ['pippi/sampler.pyx'],
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ),
        Extension('pippi.fft', ['modules/fft/fft.c', 'pippi/fft.pyx'], 
            include_dirs=['modules/fft', np.get_include()], 
        ), 

        Extension('pippi.hyperupic', ['pippi/hyperupic.pyx'],
            include_dirs=[np.get_include()], 
        ), 
        Extension('pippi.graph', ['pippi/graph.pyx']), 
        Extension('pippi.interpolation', ['pippi/interpolation.pyx']),
        Extension('pippi.noise', ['pippi/noise/noise.pyx'], 
            include_dirs=[np.get_include()], 
        ), 
        Extension('pippi.shapes', ['pippi/shapes.pyx'], 
            include_dirs=[np.get_include()], 
        ), 

        Extension('pippi.sounddb', ['pippi/sounddb.pyx'],
            include_dirs=[np.get_include()], 
        ), 
        Extension('pippi.mir', ['pippi/mir.pyx'],
            include_dirs=[np.get_include()], 
        ),

        # Oscs
        Extension('pippi.oscs', ['pippi/oscs/oscs.pyx']), 

        Extension('pippi.alias', ['pippi/oscs/alias.pyx']), 
        Extension('pippi.bar', ['pippi/oscs/bar.pyx'],
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=[np.get_include(), '/usr/local/include']
        ),
        Extension('pippi.dss', ['pippi/oscs/dss.pyx']), 
        Extension('pippi.drunk', ['pippi/oscs/drunk.pyx']), 
        Extension('pippi.fold', ['pippi/oscs/fold.pyx']), 
        Extension('pippi.fm', ['pippi/oscs/fm.pyx']), 
        Extension('pippi.osc', ['pippi/oscs/osc.pyx']), 
        Extension('pippi.osc2d', ['pippi/oscs/osc2d.pyx']), 
        Extension('pippi.pulsar', ['pippi/oscs/pulsar.pyx']), 
        Extension('pippi.pulsar2d', ['pippi/oscs/pulsar2d.pyx']), 
        Extension('pippi.pluck', ['pippi/oscs/pluck.pyx']), 
        Extension('pippi.sineosc', ['pippi/oscs/sineosc.pyx']), 
        Extension('pippi.tukey', ['pippi/oscs/tukey.pyx']), 

        Extension('pippi.midi', ['pippi/midi.pyx']), 
        Extension('pippi.rhythm', ['pippi/rhythm.pyx']), 
        Extension('pippi.rand', ['pippi/rand.pyx']), 

        Extension('pippi.soundbuffer', ['pippi/soundbuffer.pyx'], 
            include_dirs=['modules/fft', np.get_include()], 
        ), 
        Extension('pippi.soundfont', ['pippi/soundfont.pyx'], 
            include_dirs=['modules/TinySoundFont', np.get_include()], 
        ), 
        Extension('pippi.soundpipe', ['pippi/soundpipe.pyx'], 
            libraries=['soundpipe'], 
            library_dirs=['/usr/local/lib'],
            include_dirs=['/usr/local/include']
        ), 
        Extension('pippi.wavesets', ['pippi/wavesets.pyx'], 
            include_dirs=[np.get_include()], 
        ), 
        Extension('pippi.wavetables', ['pippi/wavetables.pyx'],
            include_dirs=[np.get_include()], 
        ),

        # Tuning / scales / harmony / melody
        Extension('pippi.scales', ['pippi/tune/scales.pyx']), 
        Extension('pippi.intervals', ['pippi/tune/intervals.pyx']), 
        Extension('pippi.frequtils', ['pippi/tune/frequtils.pyx']), 
        Extension('pippi.chords', ['pippi/tune/chords.pyx']), 
        Extension('pippi.old', ['pippi/tune/old.pyx']), 
        Extension('pippi.slonimsky', ['pippi/tune/slonimsky.pyx'], 
            include_dirs=[np.get_include()], 
        ),
        Extension('pippi.tune', ['pippi/tune/tune.pyx']), 
    ], 
    annotate=True, 
    compiler_directives={'profile': False},
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
        'aubio', 
        'librosa',
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
