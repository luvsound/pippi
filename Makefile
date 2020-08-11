.PHONY: test test-multiband test-breakpoints test-fft test-soundfont test-grains test-wavesets test-fx test-noise test-shapes test-oscs test-soundbuffer test-lists test-pitches test-graph test-slonimsky test-rhythm build docs deploy

test:
	python -m unittest discover -s tests -p 'test_*.py' -v

test-multiband:
	python -m unittest tests/test_multiband.py -v

test-breakpoints:
	python -m unittest tests/test_breakpoints.py -v

test-fft:
	python -m unittest tests/test_fft.py -v

test-soundfont:
	python -m unittest tests/test_soundfont.py -v

test-grains:
	python -m unittest tests/test_graincloud.py -v

test-wavesets:
	python -m unittest tests/test_wavesets.py -v

test-wavetables:
	python -m unittest tests/test_wavetables.py -v

test-fx:
	python -m unittest tests/test_fx.py -v

test-noise:
	python -m unittest tests/test_noise.py -v

test-shapes:
	python -m unittest tests/test_shapes.py -v

test-oscs:
	python -m unittest tests/test_oscs.py -v

test-soundbuffer:
	python -m unittest tests/test_soundbuffer.py -v

test-soundpipe:
	python -m unittest tests/test_soundpipe.py -v

test-lists:
	python -m unittest tests/test_lists.py -v

test-pitches:
	python -m unittest tests/test_pitches.py -v

test-graph:
	python -m unittest tests/test_graph.py -v

test-rhythm:
	python -m unittest tests/test_rhythm.py -v

test-slonimsky:
	python -m unittest tests/test_slonimsky.py -v

docs:
	bash scripts/docs.sh

deploy:
	rsync -avz pippi.world/ deploy@radio.af:/srv/www/pippi.world --delete

clean:
	rm -rf build/
	rm -rf pippi/*.c
	rm -rf pippi/**/*.c
	rm -rf pippi/*.so
	rm -rf pippi/**/*.so

install:
	pip install -r requirements.txt
	git submodule update --init
	cd modules/Soundpipe && make && sudo make install
	python setup.py develop

build:
	python setup.py develop
